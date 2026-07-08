function result = dong_wan_2024_t2ivif_solver(payoff, opts)
%DONG_WAN_2024_T2IVIF_SOLVER Reproduce Dong and Wan's T2IVIF matrix game.
%   RESULT = DONG_WAN_2024_T2IVIF_SOLVER(PAYOFF, OPTS) solves the
%   two-person zero-sum T2IVIF matrix game in Dong and Wan (ESWA 2024).
%   PAYOFF is m-by-n-by-8 with components
%   [muL, muU, fL, fU, vL, vU, gL, gU].
%
%   The implementation follows the paper's Section 6: T2IVIFHAWA with
%   gamma=3, interval-order constraints, and sequential goal programming.

    if nargin < 1 || isempty(payoff) || (ischar(payoff) && strcmpi(payoff, 'paper'))
        payoff = paper_payoff_matrix();
    end
    if nargin < 2
        opts = struct();
    end
    opts = default_opts(opts);

    result.paper = 'Dong and Wan 2024, Expert Systems with Applications 249:123398';
    result.delta = opts.delta;
    result.tau = opts.tau;
    result.gamma = opts.gamma;
    result.payoff = payoff;

    result.maximin = solve_side(payoff, 'maximin', opts);
    result.minimax = solve_side(payoff, 'minimax', opts);

    weights = result.maximin.strategy(:) * result.minimax.strategy(:)';
    result.expected_payoff = t2ivif_hawa(payoff, weights, opts.gamma);

    % 博弈值按原文 Eq.(27) 计算：ϛ* = min(V*, W*)。
    % T2IVIFS 的 "min" 对隶属分量(IVPMF/IVSMF, 第1-4位)取较小, 对非隶属分量
    % (IVPNMF/IVSNMF, 第5-8位)取较大, 不能对 8 个分量统一取 min。
    V = result.maximin.value;
    W = result.minimax.value;
    gv = zeros(1, 8);
    gv(1:4) = min(V(1:4), W(1:4));
    gv(5:8) = max(V(5:8), W(5:8));
    result.game_value = gv;
end

function opts = default_opts(opts)
    if ~isfield(opts, 'delta'); opts.delta = 0.5; end
    if ~isfield(opts, 'tau'); opts.tau = 0.9; end
    if ~isfield(opts, 'gamma'); opts.gamma = 3; end
    if ~isfield(opts, 'tol'); opts.tol = 1e-8; end
    if ~isfield(opts, 'lock_tol'); opts.lock_tol = 1e-7; end
    if ~isfield(opts, 'display'); opts.display = 'off'; end
    if ~isfield(opts, 'max_iter'); opts.max_iter = 3000; end
    if ~isfield(opts, 'max_evals'); opts.max_evals = 200000; end
    if ~isfield(opts, 'random_starts'); opts.random_starts = 12; end
end

function out = solve_side(payoff, side, opts)
    [m, n, ~] = size(payoff);
    if strcmp(side, 'maximin')
        num_strategy = m;
    else
        num_strategy = n;
    end

    starts = initial_points(num_strategy, side, opts.random_starts);
    ideal = zeros(1, 8);
    ideal_x = zeros(numel(starts{1}), 8);
    for i = 1:8
        obj = @(x) objective_component(x, side, i);
        [ideal_x(:, i), ideal(i)] = best_fmincon(obj, starts, payoff, side, opts, []);
    end

    targets = opts.tau * ideal;
    locks = [];
    x_best = starts{1};
    devs = zeros(1, 8);
    for i = 1:8
        obj = @(x) positive_deviation(x, side, i, targets);
        step_starts = [{x_best}, starts, num2cell(ideal_x, 1)];
        [x_best, devs(i)] = best_fmincon(obj, step_starts, payoff, side, opts, locks);
        locks = [locks; i, devs(i), targets(i)]; %#ok<AGROW>
    end

    out.strategy = x_best(1:num_strategy)';
    out.value = x_best(num_strategy + (1:8))';
    out.ideal = ideal;
    out.targets = targets;
    out.positive_deviation = devs;
    out.exit_check = max_constraint_violation(x_best, payoff, side, opts, []);
end

function starts = initial_points(k, side, random_starts)
    if strcmp(side, 'maximin')
        value0 = [0 0 0 0 1 1 1 1];
    else
        value0 = [1 1 1 1 0 0 0 0];
    end

    starts = cell(1, k + random_starts + 1);
    starts{1} = [ones(1, k) / k, value0]';
    for i = 1:k
        p = zeros(1, k);
        p(i) = 1;
        starts{1 + i} = [p, value0]';
    end

    rng(240263, 'twister');
    for i = 1:random_starts
        p = rand(1, k);
        p = p / sum(p);
        starts{1 + k + i} = [p, value0]';
    end
end

function [x_best, f_best] = best_fmincon(obj, starts, payoff, side, opts, locks)
    k = numel(starts{1}) - 8;
    lb = zeros(k + 8, 1);
    ub = ones(k + 8, 1);
    Aeq = [ones(1, k), zeros(1, 8)];
    beq = 1;

    options = optimoptions('fmincon', ...
        'Algorithm', 'sqp', ...
        'Display', opts.display, ...
        'MaxIterations', opts.max_iter, ...
        'MaxFunctionEvaluations', opts.max_evals, ...
        'OptimalityTolerance', opts.tol, ...
        'ConstraintTolerance', opts.tol, ...
        'StepTolerance', opts.tol);

    f_best = inf;
    x_best = starts{1};
    nonlcon = @(x) nonlinear_constraints(x, payoff, side, opts, locks);
    for s = 1:numel(starts)
        x0 = starts{s};
        try
            [x, f, exitflag] = fmincon(obj, x0, [], [], Aeq, beq, lb, ub, nonlcon, options);
            violation = max_constraint_violation(x, payoff, side, opts, locks);
            if exitflag > 0 && violation <= 1e-5 && f < f_best
                f_best = f;
                x_best = x;
            elseif violation <= 1e-5 && f < f_best
                f_best = f;
                x_best = x;
            end
        catch
            % Keep trying the remaining starts. The caller validates output.
        end
    end
end

function f = objective_component(x, side, idx)
    phi = objective_vector(x, side);
    f = phi(idx);
end

function f = positive_deviation(x, side, idx, targets)
    phi = objective_vector(x, side);
    f = max(0, phi(idx) - targets(idx));
end

function phi = objective_vector(x, side)
    v = x(end-7:end)';
    if strcmp(side, 'maximin')
        phi = [-v(1), -0.5 * (v(1) + v(2)), ...
               -v(3), -0.5 * (v(3) + v(4)), ...
               -(1 - v(6)), -0.5 * ((1 - v(5)) + (1 - v(6))), ...
               -(1 - v(8)), -0.5 * ((1 - v(7)) + (1 - v(8)))];
    else
        phi = [-(1 - v(2)), -0.5 * ((1 - v(1)) + (1 - v(2))), ...
               -(1 - v(4)), -0.5 * ((1 - v(3)) + (1 - v(4))), ...
               -v(5), -0.5 * (v(5) + v(6)), ...
               -v(7), -0.5 * (v(7) + v(8))];
    end
end

function [c, ceq] = nonlinear_constraints(x, payoff, side, opts, locks)
    k = numel(x) - 8;
    p = x(1:k);
    value = x(k + (1:8));
    delta = opts.delta;
    gamma = opts.gamma;
    c = common_t2ivif_constraints(value);

    [m, n, ~] = size(payoff);
    if strcmp(side, 'maximin')
        for s = 1:n
            a = t2ivif_hawa(payoff(:, s, :), p, gamma);
            c = [c; maximin_component_constraints(a, value, delta)]; %#ok<AGROW>
        end
    else
        for r = 1:m
            a = t2ivif_hawa(payoff(r, :, :), p, gamma);
            c = [c; minimax_component_constraints(a, value, delta)]; %#ok<AGROW>
        end
    end

    if ~isempty(locks)
        phi = objective_vector(x, side);
        for j = 1:size(locks, 1)
            c = [c; positive_deviation_locked(phi, locks(j, 1), locks(j, 2), locks(j, 3), opts.lock_tol)]; %#ok<AGROW>
        end
    end

    ceq = [];
end

function c = positive_deviation_locked(phi, idx, best_dev, target, lock_tol)
    % The caller locks the achieved positive deviation for higher-priority
    % goals. The target itself is embedded in best_dev by the stage objective.
    c = max(0, phi(idx) - target) - best_dev - lock_tol;
end

function c = common_t2ivif_constraints(v)
    c = [v(1) - v(2);
         v(3) - v(4);
         v(5) - v(6);
         v(7) - v(8);
         v(2) + v(6) - 1;
         v(4) + v(8) - 1];
end

function c = maximin_component_constraints(a, v, delta)
    c = [v(1) - a(1);
         (1 - delta) * v(1) + delta * v(2) - ((1 - delta) * a(1) + delta * a(2));
         v(3) - a(3);
         (1 - delta) * v(3) + delta * v(4) - ((1 - delta) * a(3) + delta * a(4));
         a(5) - v(5);
         (1 - delta) * a(5) + delta * a(6) - ((1 - delta) * v(5) + delta * v(6));
         a(7) - v(7);
         (1 - delta) * a(7) + delta * a(8) - ((1 - delta) * v(7) + delta * v(8))];
end

function c = minimax_component_constraints(a, v, delta)
    c = [a(1) - v(1);
         (1 - delta) * a(1) + delta * a(2) - ((1 - delta) * v(1) + delta * v(2));
         a(3) - v(3);
         (1 - delta) * a(3) + delta * a(4) - ((1 - delta) * v(3) + delta * v(4));
         v(5) - a(5);
         (1 - delta) * v(5) + delta * v(6) - ((1 - delta) * a(5) + delta * a(6));
         v(7) - a(7);
         (1 - delta) * v(7) + delta * v(8) - ((1 - delta) * a(7) + delta * a(8))];
end

function violation = max_constraint_violation(x, payoff, side, opts, locks)
    c = nonlinear_constraints(x, payoff, side, opts, locks);
    violation = max([0; c(:)]);
end

function payoff = paper_payoff_matrix()
    terms.VH = [0.70 0.95 0.50 0.85 0.01 0.04 0.06 0.10];
    terms.H  = [0.75 0.80 0.65 0.80 0.10 0.15 0.12 0.18];
    terms.MH = [0.60 0.72 0.45 0.60 0.10 0.25 0.15 0.40];
    terms.F  = [0.45 0.64 0.30 0.55 0.25 0.30 0.36 0.40];
    terms.ML = [0.50 0.58 0.40 0.45 0.20 0.35 0.30 0.50];
    terms.L  = [0.35 0.40 0.25 0.40 0.40 0.50 0.50 0.55];
    terms.VL = [0.10 0.25 0.08 0.15 0.35 0.60 0.70 0.80];

    names = {'VH', 'MH', 'L'; ...
             'ML', 'H',  'F'; ...
             'VL', 'F',  'H'};
    payoff = zeros(3, 3, 8);
    for r = 1:3
        for s = 1:3
            payoff(r, s, :) = terms.(names{r, s});
        end
    end
end
