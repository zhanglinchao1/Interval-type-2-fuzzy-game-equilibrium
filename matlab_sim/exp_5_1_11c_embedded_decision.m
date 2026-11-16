function exp_5_1_11c_embedded_decision(mode)
%EXP_5_1_11C_EMBEDDED_DECISION R3-1 candidate, not a manuscript method change.
% Retain the embedded-family compatibility during the decision calculation.
% Pilot fixes all parameters before inspecting payoff results.

if nargin == 0, mode = 'pilot'; end
root = fileparts(mfilename('fullpath')); addpath(fullfile(root, 'utils'));
p = config_params(); p.lambda = 0.20; p.eps_tol = 1e-8; p.R_max = 500;
verify_oracle(p);
if strcmp(mode, 'check'), return; end
if strcmp(mode, 'full')
    full_experiment(root, p, true); return;
end
if strcmp(mode, 'performance')
    full_experiment(root, p, false); return;
end
assert(strcmp(mode, 'pilot'), 'Only the predeclared pilot is implemented.');
rows = {}; row = 0;
for scenario = ["A", "B"]
    for delta = [0, 0.10, 0.20]
        for alpha = [0, 0.5, 1]
            cfg = p; cfg.N = 20; cfg.rng_seed = 42; cfg.fou_modulation = true;
            if scenario == "B"
                env = scenario_b_config('concentrated');
                cfg = scenario_b_env(cfg, env.fou_scale);
            end
            policies = cell(3, 1);
            for method = 1:3
                timer = tic;
                if method == 1
                    [pi, hist] = sec4_3_1_wfbri_solve(cfg, delta, cfg.theta, alpha);
                    innerGap = 0; innerRounds = 0;
                else
                    [pi, hist, innerGap, innerRounds] = solve_regret(cfg, delta, alpha, double(method == 2));
                end
                seconds = toc(timer); policies{method} = pi;
                [~, ~, center, ~, lo, hi] = sec4_1_2_pure_interval_payoff_matrix(pi, delta, cfg.theta, cfg);
                m = nominal(pi, cfg);
                shared = max(sec5_1_embedded_regret(pi, m, lo, hi, cfg.theta, 0));
                box = max(sec5_1_embedded_regret(pi, m, lo, hi, cfg.theta, 1));
                nominalPayoff = mean(sum(pi.*sum((2*m-m.^2).*reshape(cfg.theta, 1, 1, []), 3), 2));
                [~, responseGap] = sec5_1_embedded_regret_br(center, m, lo, hi, cfg.theta, 0, alpha, cfg.lambda);
                row = row+1;
                rows(row, :) = {scenario, delta, alpha, method, hist.converged, hist.iterations, ...
                    hist.residual(end), innerGap, innerRounds, seconds, nominalPayoff, shared, box, ...
                    mean(pi(:, 1)), max(responseGap)}; %#ok<AGROW>
                fprintf('%s delta=%.2f alpha=%.1f method=%d: shared=%.5f, R=%d, inner=%.2g, %.2fs\n', ...
                    scenario, delta, alpha, method, shared, hist.iterations, innerGap, seconds);
            end
            if delta == 0 || alpha == 1
                assert(max(abs(policies{1}-policies{2}), [], 'all') < 2e-7 ...
                    && max(abs(policies{1}-policies{3}), [], 'all') < 2e-7, ...
                    'Zero FOU / alpha=1 recovery failed.');
            end
        end
    end
end
T = cell2table(rows, 'VariableNames', {'Scenario','Delta','Alpha','Method','Converged', ...
    'Iterations','Residual','InnerGap','MaxInnerIterations','Seconds','NominalPayoff', ...
    'SharedRegret','BoxRegret','SCShare','CheckResponseGap'});
writetable(T, fullfile(root, 'table', 'table5_11c_embedded_pilot.csv'));
fprintf('[PASS] Pilot: %d rows; no manuscript files changed.\n', height(T));
end

function [pi, history, largestGap, largestInner] = solve_regret(p, delta, alpha, eta)
rng(p.rng_seed); pi = ones(p.N, p.num_strategies)/p.num_strategies+0.01*rand(p.N, p.num_strategies);
pi = pi./sum(pi, 2); largestGap = 0; largestInner = 0;
history.converged = false;
for iteration = 1:p.R_max
    [~, ~, center, ~, lo, hi] = sec4_1_2_pure_interval_payoff_matrix(pi, delta, p.theta, p);
    m = nominal(pi, p);
    [br, gap, inner] = sec5_1_embedded_regret_br(center, m, lo, hi, p.theta, eta, alpha, p.lambda);
    largestGap = max(largestGap, max(gap)); largestInner = max(largestInner, inner);
    if max(gap) > 1e-8
        residual = NaN; break;
    end
    next = (1-p.beta)*pi+p.beta*br;
    residual = max(sum(abs(next-pi), 2)); pi = next;
    if residual <= p.eps_tol
        history.converged = true; break;
    end
end
history.residual = residual; history.iterations = iteration;
end

function m = nominal(pi, p)
opponents = (sum(pi, 1)-pi)/(p.N-1);
kernels = {p.trust_matrix, p.delay_matrix, p.res_matrix};
m = zeros(p.N, p.num_strategies, 3);
for k = 1:3, m(:, :, k) = opponents*kernels{k}'; end
end

function verify_oracle(p)
rng(112031); n = 8; s = 4;
q = rand(n, s); q = q./sum(q, 2); m = 0.1+0.8*rand(n, s, 3);
lo = max(0, m-0.4*rand(n, s, 3)); hi = min(1, m+0.4*rand(n, s, 3));
for eta = [0, 0.1, 0.5, 1]
    [exact, witness] = sec5_1_embedded_regret(q, m, lo, hi, p.theta, eta);
    assert(max(abs(exact-sum(q.*witness, 2))) < 1e-12, 'Witness mismatch.');
    gridBest = zeros(n, s); grid = linspace(-1, 1, 10001)';
    if eta < 1
        corner = min(1, eta/(1-eta));
        grid = unique([grid; -corner; corner]);
    end
    for i = 1:n
        for j = 1:s
            signs = -ones(1, s); signs(j) = 1; coefficients = -q(i, :); coefficients(j) = coefficients(j)+1;
            x = (1-eta)*grid+eta*signs;
            for k = 1:3
                mu = m(i, :, k)+max(x, 0).*(hi(i, :, k)-m(i, :, k)) ...
                    +min(x, 0).*(m(i, :, k)-lo(i, :, k));
                gridBest(i, j) = gridBest(i, j)+p.theta(k)*max((2*mu-mu.^2)*coefficients');
            end
        end
    end
    sampled = max(gridBest, [], 2);
    assert(all(exact >= sampled-1e-12) && max(exact-sampled) < 1e-7, ...
        'Quadratic oracle failed: eta=%g, min difference=%g, max difference=%g.', ...
        eta, min(exact-sampled), max(exact-sampled));
    if eta == 1
        l = sum((2*lo-lo.^2).*reshape(p.theta, 1, 1, []), 3);
        h = sum((2*hi-hi.^2).*reshape(p.theta, 1, 1, []), 3);
        box = max(h-sum(q.*l, 2)-q.*(h-l), [], 2);
        assert(max(abs(box-exact)) < 1e-12, 'Box limit failed.');
    end
end
fprintf('[PASS] Analytic oracle vs 10001-point grid, witness, and box limit.\n');
end

function full_experiment(root, base, runSensitivity)
if runSensitivity
rows = {}; row = 0;
for scenario = ["A", "B"]
    for n = [20, 50, 200]
        for delta = [0.05, 0.10, 0.20]
            for alpha = [0, 0.5, 1]
                for lambda = [0.10, 0.20, 0.40]
                    p = base; p.N = n; p.lambda = lambda; p.rng_seed = 42; p.fou_modulation = true;
                    if scenario == "B"
                        env = scenario_b_config('concentrated'); p = scenario_b_env(p, env.fou_scale);
                    end
                    for method = 1:3
                        timer = tic;
                        if method == 1
                            [pi, hist] = sec4_3_1_wfbri_solve(p, delta, p.theta, alpha);
                            gap = 0; inner = 0;
                        else
                            [pi, hist, gap, inner] = solve_regret(p, delta, alpha, double(method == 2));
                        end
                        seconds = toc(timer);
                        [loPay, ~, ~, ~, lo, hi] = sec4_1_2_pure_interval_payoff_matrix(pi, delta, p.theta, p);
                        m = nominal(pi, p);
                        nominalPayoff = mean(sum(pi.*sum((2*m-m.^2).*reshape(p.theta, 1, 1, []), 3), 2));
                        shared = max(sec5_1_embedded_regret(pi, m, lo, hi, p.theta, 0));
                        partial = max(sec5_1_embedded_regret(pi, m, lo, hi, p.theta, 0.25));
                        box = max(sec5_1_embedded_regret(pi, m, lo, hi, p.theta, 1));
                        row = row+1;
                        rows(row, :) = {scenario,n,delta,alpha,lambda,method,hist.converged, ...
                            hist.iterations,hist.residual(end),gap,inner,seconds,nominalPayoff, ...
                            mean(sum(pi.*loPay,2)),shared,partial,box,mean(pi(:,1))}; %#ok<AGROW>
                    end
                end
            end
        end
        fprintf('[DONE] Sensitivity: %s N=%d (%d rows)\n', scenario, n, row);
    end
end
T = cell2table(rows, 'VariableNames', {'Scenario','N','Delta','Alpha','Lambda','Method', ...
    'Converged','Iterations','Residual','InnerGap','MaxInnerIterations','Seconds', ...
    'NominalPayoff','WorstPayoff','SharedRegret','PartialRegret','BoxRegret','SCShare'});
writetable(T, fullfile(root,'table','table5_11c_embedded_sensitivity.csv'));
fprintf('Sensitivity complete: %d rows, %d converged, max inner gap %.3g.\n', ...
    height(T), sum(T.Converged), max(T.InnerGap));
end

% Fixed primary alpha=.5; extremes are sensitivity checks, not selected winners.
% Policy initialization seed=42; independent outcome seeds 52:61 are held out.
cfg = scenario_b_config('concentrated'); p = scenario_b_env(base,cfg.fou_scale);
p.N = 50; p.rng_seed = 42; delta = 0.20;
rows = {}; row = 0;
sharedRows = {}; sharedRow = 0;
solveRows = {}; solveRow = 0;
for alpha = [0, 0.5, 1]
    for method = 1:4
        timer = tic; gap = 0;
        if method == 1
            [pi, hist] = sec4_3_1_wfbri_solve(p,delta,p.theta,alpha);
        else
            etas = [NaN,1,0,0.25];
            [pi, hist, gap] = solve_regret(p,delta,alpha,etas(method));
        end
        solveRow = solveRow+1;
        solveRows(solveRow,:) = {alpha,method,hist.converged,hist.iterations,gap,toc(timer)}; %#ok<AGROW>
        S = cell2table(solveRows,'VariableNames',{'Alpha','Method','Converged','Iterations','InnerGap','Seconds'});
        writetable(S,fullfile(root,'table','table5_11c_embedded_solve_status.csv'));
        if ~hist.converged
            fprintf('[NOT CONVERGED] alpha=%.1f method=%d inner gap=%.3g\n',alpha,method,gap);
            continue;
        end
        for seed = 52:61
            for scene = ["concentrated","dispersed"]
                env = scenario_b_config(char(scene)); evaluation = p;
                evaluation.rng_seed = seed; evaluation.shock_mode = char(scene);
                [average,q5] = scenario_b_payoff_stats(pi,delta,p.theta,evaluation,2000, ...
                    env.p_shock,env.sigma_small,env.shock_strength);
                row = row+1;
                rows(row,:) = {scene,alpha,method,seed,average,q5,average-.55*(average-q5)}; %#ok<AGROW>
            end
            for eta = [0,0.25,1]
                [average,q5,regret95] = embedded_samples(pi,p,delta,eta,seed);
                sharedRow = sharedRow+1;
                sharedRows(sharedRow,:) = {alpha,method,eta,seed,average,q5,regret95}; %#ok<AGROW>
            end
        end
        P = cell2table(rows,'VariableNames',{'Scenario','Alpha','Method','Seed','MeanPayoff','Q5','CE055'});
        writetable(P,fullfile(root,'table','table5_11c_embedded_performance.csv'));
        E = cell2table(sharedRows,'VariableNames',{'Alpha','Method','TrueIndependentFraction','Seed', ...
            'MeanPayoff','Q5','RegretQ95'});
        writetable(E,fullfile(root,'table','table5_11c_embedded_realizations.csv'));
        fprintf('[DONE] Held-out outcomes: alpha=%.1f method=%d\n', alpha,method);
    end
end
fprintf('[PASS] Held-out performance: %d old-scenario and %d embedded-family rows.\n',height(P),height(E));
end

function [average,q5,regret95] = embedded_samples(pi,p,delta,eta,seed)
[~,~,~,~,lo,hi] = sec4_1_2_pure_interval_payoff_matrix(pi,delta,p.theta,p);
m = nominal(pi,p); rng(seed+811); count = 2000;
% Evaluation distributions only; the solver receives no sample probabilities.
common = 2*rand(count,3)-1; local = 2*rand(count,4,3)-1;
payoffs = zeros(count,1); regrets = zeros(count,1);
for sample = 1:count
    x = (1-eta)*reshape(common(sample,:),1,1,3)+eta*local(sample,:,:);
    mu = m+max(x,0).*(hi-m)+min(x,0).*(m-lo);
    values = sum((2*mu-mu.^2).*reshape(p.theta,1,1,3),3);
    incumbent = sum(pi.*values,2);
    payoffs(sample) = mean(incumbent);
    regrets(sample) = max(values-incumbent,[],'all');
end
average = mean(payoffs); q5 = quantile(payoffs,.05); regret95 = quantile(regrets,.95);
end
