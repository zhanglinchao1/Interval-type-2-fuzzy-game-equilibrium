function [pi_star, history] = sec4_3_1_wfbri_solve( ...
    params, delta, theta, alpha, focus_s)
%SEC4_3_1_WFBRI_SOLVE Canonical W-FBRI solver for Gamma_{alpha,s}.
%   Pure-action interval payoffs are evaluated first. The decision payoff is
%
%     nu_ij = Uhat_ij - (1-alpha)*rho_ij*(rho_ij/rho_i_star)^focus_s.
%
%   alpha=1 and focus_s=0 recover the midpoint solver used by legacy
%   three-argument calls.
%
%   Certified annealing (optional):
%   若 params.lambda_path 存在 (温度调度向量, 递减, 首元素应位于认证窗内),
%   则按调度逐段求解并在段间热启动 (certified warm start -> temperature
%   decay)。第 1 段在 kappa(lambda_0)<1 的先验压缩证书内; 终段的解不再声称
%   先验压缩, 改由事后 exploitability 证书 history.eps_ne 度量:
%       eps_ne(pi) = max_i [ max_j nu_ij(pi) - <pi_i, nu_i(pi)> ],
%   该量可直接代入 Lemma 1 / Corollary 2 的 epsilon_0 (二者对任意
%   epsilon_0-NE 成立, 不要求 epsilon_0 来自压缩定理)。
%   缺省 (无 lambda_path 字段) 时迭代路径与历史版本逐位一致。
%
%   输入:
%       params - 参数结构体 (来自 config_params; 可选 params.lambda_path)
%       delta  - 不确定性半带宽
%       theta  - 3×1 收益层权重
%       alpha  - [0,1], default 1; alpha=0 is the numerical worst-case limit
%       focus_s- nonnegative focusing exponent, default 0
%   输出:
%       pi_star - N×4 矩阵，收敛后的均衡策略
%       history - 结构体，记录收敛过程 (含 eps_ne 事后证书与 lambda_path)

    if nargin < 4 || isempty(alpha)
        alpha = 1;
    end
    if nargin < 5 || isempty(focus_s)
        focus_s = 0;
    end
    if ~isscalar(alpha) || alpha < 0 || alpha > 1
        error('sec4_3_1_wfbri_solve:badAlpha', ...
            'alpha must be a scalar in [0,1].');
    end
    if ~isscalar(focus_s) || focus_s < 0
        error('sec4_3_1_wfbri_solve:badFocus', ...
            'focus_s must be a nonnegative scalar.');
    end

    if isfield(params, 'lambda_path') && ~isempty(params.lambda_path)
        lambda_path = params.lambda_path(:)';
        if any(lambda_path <= 0)
            error('sec4_3_1_wfbri_solve:badLambdaPath', ...
                'lambda_path entries must be positive.');
        end
    else
        lambda_path = params.lambda;   % 单段: 与历史版本逐位一致
    end

    % 可选受限策略集 (论文 §3.1 的 S_i ⊆ S): N×num_s 逻辑掩码。
    % 缺省 (无字段) 时所有分支跳过, 迭代路径与历史版本逐位一致。
    if isfield(params, 'feasible_mask') && ~isempty(params.feasible_mask)
        feasible_mask = logical(params.feasible_mask);
        if ~isequal(size(feasible_mask), ...
                [params.N, params.num_strategies])
            error('sec4_3_1_wfbri_solve:badFeasibleMask', ...
                'feasible_mask must be N-by-num_strategies.');
        end
        if any(~any(feasible_mask, 2))
            error('sec4_3_1_wfbri_solve:emptyFeasibleSet', ...
                'every agent needs at least one feasible strategy.');
        end
    else
        feasible_mask = [];
    end

    N = params.N;
    num_s = params.num_strategies;

    % 步骤1: 初始化混合策略 (RNG 用法与历史版本一致, 仅初始化消耗随机数)
    rng(params.rng_seed);
    pi_profile = ones(N, num_s) / num_s;
    pi_profile = pi_profile + 0.01 * rand(N, num_s);
    pi_profile = pi_profile ./ sum(pi_profile, 2);
    if ~isempty(feasible_mask) && any(~feasible_mask(:))
        pi_profile(~feasible_mask) = 0;
        pi_profile = pi_profile ./ sum(pi_profile, 2);
    end

    history.residual = [];
    history.avg_payoff = [];
    history.strategy_dist = [];
    history.stage_iterations = zeros(1, numel(lambda_path));
    history.converged = true;

    for stage = 1:numel(lambda_path)
        [pi_profile, stage_hist] = run_wfbri_stage( ...
            pi_profile, params, delta, theta, alpha, focus_s, ...
            lambda_path(stage), feasible_mask);
        history.residual = [history.residual; stage_hist.residual];
        history.avg_payoff = [history.avg_payoff; stage_hist.avg_payoff];
        history.strategy_dist = [history.strategy_dist; ...
            stage_hist.strategy_dist];
        history.stage_iterations(stage) = stage_hist.iterations;
        history.converged = history.converged && stage_hist.converged;
    end

    pi_star = pi_profile;
    history.iterations = sum(history.stage_iterations);
    history.alpha = alpha;
    history.focus_s = focus_s;
    history.lambda_path = lambda_path;

    % 事后 exploitability 证书 (对任意 (alpha, focus_s) 可计算,
    % 直接作为 Lemma 1 / Corollary 2 的 epsilon_0 输入)
    [~, ~, pure_hat, pure_rho] = sec4_1_2_pure_interval_payoff_matrix( ...
        pi_star, delta, theta, params);
    nu_final = focused_decision_payoff(pure_hat, pure_rho, alpha, focus_s);
    nu_final = apply_optional_tail_mix(nu_final, pi_star, delta, params);
    incumbent = sum(pi_star .* nu_final, 2);
    nu_deviation = nu_final;
    if ~isempty(feasible_mask)
        nu_deviation(~feasible_mask) = -inf;   % 偏离仅限可行策略
    end
    history.eps_ne = max(max(nu_deviation, [], 2) - incumbent);
end

function [pi_profile, hist_out] = run_wfbri_stage( ...
    pi_profile, params, delta, theta, alpha, focus_s, lambda, ...
    feasible_mask)
%RUN_WFBRI_STAGE Single fixed-temperature damped soft-response stage.
%   迭代体与历史版本逐位一致 (同一公式 4-20/4-21 与停止准则)。

    N = size(pi_profile, 1);
    num_s = params.num_strategies;
    beta = params.beta;
    R_max = params.R_max;
    eps_tol = params.eps_tol;

    hist_out.residual = zeros(R_max, 1);
    hist_out.avg_payoff = zeros(R_max, 1);
    hist_out.strategy_dist = zeros(R_max, num_s);

    for r = 1:R_max
        pi_new = zeros(N, num_s);
        [~, ~, pure_hat, pure_rho] = ...
            sec4_1_2_pure_interval_payoff_matrix( ...
            pi_profile, delta, theta, params);
        decision_payoff = focused_decision_payoff( ...
            pure_hat, pure_rho, alpha, focus_s);
        decision_payoff = apply_optional_tail_mix( ...
            decision_payoff, pi_profile, delta, params);

        for i = 1:N
            % 步骤2: Gamma_{alpha,s} 纯策略决策收益向量
            nu_i = decision_payoff(i, :)';
            if ~isempty(feasible_mask)
                nu_i(~feasible_mask(i, :)) = -inf;   % 受限单纯形软响应
            end

            % 步骤3: 软最好响应 (公式4-20)
            br_i = sec4_3_1_softmax_br(nu_i, lambda);

            % 步骤4: 阻尼更新 (公式4-21)
            pi_new(i, :) = (1 - beta) * pi_profile(i, :) + beta * br_i';
        end

        residuals = sum(abs(pi_new - pi_profile), 2);
        e_pi = max(residuals);

        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_new, delta, theta, params);

        hist_out.residual(r) = e_pi;
        hist_out.avg_payoff(r) = mean(U_hat);
        hist_out.strategy_dist(r, :) = mean(pi_new, 1);

        pi_profile = pi_new;

        if e_pi <= eps_tol
            hist_out.residual = hist_out.residual(1:r);
            hist_out.avg_payoff = hist_out.avg_payoff(1:r);
            hist_out.strategy_dist = hist_out.strategy_dist(1:r, :);
            hist_out.converged = true;
            hist_out.iterations = r;
            return;
        end
    end
    hist_out.converged = false;
    hist_out.iterations = R_max;
end

function decision_payoff = focused_decision_payoff( ...
    pure_hat, pure_rho, alpha, focus_s)
%FOCUSED_DECISION_PAYOFF Construct the pure-action Gamma_{alpha,s} payoff.

    radius_budget = (1 - alpha) * pure_rho;
    if focus_s == 0
        penalty = radius_budget;
    else
        rho_floor = 0.01;
        rho_peak = max(max(pure_rho, [], 2), rho_floor);
        penalty = radius_budget .* (pure_rho ./ rho_peak).^focus_s;
    end
    decision_payoff = pure_hat - penalty;
end

function decision_payoff = apply_optional_tail_mix( ...
    decision_payoff, pi_profile, delta, params)
%APPLY_OPTIONAL_TAIL_MIX Preserve the declared Scenario-B stress extension.

    if ~isfield(params, 'tail_cvar_enable') || ~params.tail_cvar_enable
        return;
    end
    if ~isfield(params, 'tail_cvar_mix') || params.tail_cvar_mix <= 0
        return;
    end

    tail_mix = params.tail_cvar_mix;
    if isfield(params, 'tail_cvar_alpha')
        tail_alpha = params.tail_cvar_alpha;
    else
        tail_alpha = 0.10;
    end
    if isfield(params, 'tail_cvar_K')
        num_samples = params.tail_cvar_K;
    else
        num_samples = 64;
    end

    game = build_reduced_interval_game(params, delta);
    population = mean(pi_profile, 1)';
    perturbation = linspace(-1, 1, num_samples)';
    tail_payoff = zeros(params.num_strategies, 1);
    for j = 1:params.num_strategies
        center = game.U_hat(j, :) * population;
        radius = game.rho(j, :) * population;
        samples = center + perturbation * radius;
        tail_payoff(j) = sota_cvar_lower( ...
            samples, ones(num_samples, 1), tail_alpha);
    end

    tail_matrix = repmat(tail_payoff', size(decision_payoff, 1), 1);
    decision_payoff = ...
        (1 - tail_mix) * decision_payoff + tail_mix * tail_matrix;
end
