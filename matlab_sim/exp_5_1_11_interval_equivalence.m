function exp_5_1_11_interval_equivalence()
%EXP_5_1_11_INTERVAL_EQUIVALENCE R3-1: matched interval and mechanism audit.
% Reuses the canonical W-FBRI, soft response, KM/EKM, and Scenario B tools.
% The independent interval reference preserves the same endpoint functions;
% it is an equivalence control, not a competing model with less information.
% No annealing, focusing, online calibration, or manuscript export is used.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'utils'));
base = config_params();
base.eps_tol = 1e-10;
caseNames = ["UniformConcave", "BellConcave", "ExposedConcave", "UniformLinear"];
sizes = [20, 50, 200];
deltas = [0.10, 0.20];
alphas = [0, 0.5, 1];
seeds = 42:44;
auditRows = cell(72, 9);
policyRows = cell(216, 12);
ia = 0; ip = 0;

for c = 1:numel(caseNames)
    for n = sizes
        for d = deltas
            for seed = seeds
                p = case_params(base, c);
                p.N = n; p.rng_seed = seed;
                [endpointError, kmError, ekmError, clipped] = audit_endpoints(p, d);
                ia = ia + 1;
                auditRows(ia, :) = {caseNames(c), n, d, seed, 7, ...
                    endpointError, kmError, ekmError, clipped};
                for a = alphas
                    [piIT2, h] = sec4_3_1_wfbri_solve(p, d, p.theta, a);
                    [piInterval, hr] = interval_solve(p, d, a, false);
                    assert(h.converged && hr.converged, 'A solver did not converge.');
                    assert(h.iterations == hr.iterations, 'Stopping iterations differ.');
                    [~, ~, center, radius] = sec4_1_2_pure_interval_payoff_matrix( ...
                        piIT2, d, p.theta, p);
                    [lo, hi] = interval_endpoints(piIT2, d, p);
                    scoreError = max(abs(center - (1-a)*radius ...
                        - ((1-a/2)*lo + (a/2)*hi)), [], 'all');
                    policyError = max(sum(abs(piIT2-piInterval), 2));
                    residualError = max(abs(h.residual-hr.residual));
                    traceError = max(abs(h.strategy_dist-hr.strategy_dist), [], 'all');
                    assert(max([scoreError, policyError, residualError, traceError]) < 1e-9, ...
                        'Matched interval equivalence failed.');
                    assert(all(piInterval >= 0, 'all') && ...
                        max(abs(sum(piInterval, 2)-1)) < 1e-12, 'Invalid strategy.');
                    ip = ip + 1;
                    policyRows(ip, :) = {caseNames(c), n, d, a, seed, ...
                        scoreError, policyError, residualError, traceError, ...
                        h.iterations, hr.iterations, h.fixed_point_residual};
                end
            end
        end
    end
    fprintf('[PASS] Matched interval control: %s\n', caseNames(c));
end
endpointTable = cell2table(auditRows, 'VariableNames', ...
    {'Case','N','Delta','Seed','Profiles','EndpointError','KMError','EKMError','ClippedGrades'});
policyTable = cell2table(policyRows, 'VariableNames', ...
    {'Case','N','Delta','Alpha','Seed','ScoreError','PolicyMaxAgentL1', ...
    'ResidualTraceError','MeanPolicyTraceError','IterationsIT2','IterationsInterval', ...
    'FixedPointResidual'});

% Common-profile centers separate a numerical payoff shift from policy effects.
mechanismRows = cell(20, 12);
im = 0;
for c = 1:numel(caseNames)
    p = case_params(base, c);
    [piT1, hT1] = sec4_3_1_wfbri_solve(p, 0, p.theta, 1);
    [nominal, ~] = interval_endpoints(piT1, 0, p);
    for d = [0, 0.05, 0.10, 0.15, 0.20]
        [lo, hi, clipped] = interval_endpoints(piT1, d, p);
        gap = (lo+hi)/2 - nominal;
        [piMid, hMid] = sec4_3_1_wfbri_solve(p, d, p.theta, 1);
        [piRobust, hRobust] = sec4_3_1_wfbri_solve(p, d, p.theta, 0.5);
        [piFlatRadius, hf] = interval_solve(p, d, 0.5, true);
        flatError = max(sum(abs(piFlatRadius-piMid), 2));
        assert(hT1.converged && hMid.converged && hRobust.converged && ...
            hf.converged && flatError < 1e-9, ...
            'Action-independent radius should cancel in the soft response.');
        formulaError = NaN;
        if clipped == 0 && (c == 1 || c == 4)
            expectedGap = -sum(p.theta)*d^2*(c == 1);
            formulaError = max(abs(gap-expectedGap), [], 'all');
            assert(formulaError < 1e-12, 'Uniform-FOU center identity failed.');
        end
        im = im + 1;
        mechanismRows(im, :) = {caseNames(c), d, mean(gap, 'all'), ...
            max(max(gap, [], 2)-min(gap, [], 2)), clipped, formulaError, ...
            max(sum(abs(piMid-piT1), 2)), max(sum(abs(piRobust-piMid), 2)), ...
            flatError, mean(piT1(:, 1)), mean(piMid(:, 1)), mean(piRobust(:, 1))};
    end
end
mechanismTable = cell2table(mechanismRows, 'VariableNames', ...
    {'Case','Delta','MeanCenterShift','MaxActionCenterShiftSpread','ClippedGrades', ...
    'UniformFormulaError','MidpointVsT1MaxAgentL1','RobustVsMidpointMaxAgentL1', ...
    'FlatRadiusVsMidpointMaxAgentL1','T1_SC','Midpoint_SC','Robust_SC'});
fprintf('[PASS] Center and action-radius mechanisms\n');

% Existing synthetic stress environments; common random numbers across methods.
performanceRows = cell(40, 7);
im = 0;
methods = ["Type1", "Midpoint", "IT2Alpha05", "MatchedIntervalAlpha05"];
for mode = ["concentrated", "dispersed"]
    cfg = scenario_b_config(char(mode));
    for seed = 42:46
        p = scenario_b_env(base, cfg.fou_scale);
        p.shock_mode = char(mode); p.rng_seed = seed;
        [piT1, hT1] = sec4_3_1_wfbri_solve(p, 0, p.theta, 1);
        [piMid, hMid] = sec4_3_1_wfbri_solve(p, cfg.delta, p.theta, 1);
        [piIT2, hIT2] = sec4_3_1_wfbri_solve(p, cfg.delta, p.theta, 0.5);
        [piInterval, hInterval] = interval_solve(p, cfg.delta, 0.5, false);
        assert(hT1.converged && hMid.converged && hIT2.converged && hInterval.converged, ...
            'A performance policy did not converge.');
        policies = {piT1, piMid, piIT2, piInterval};
        for m = 1:numel(methods)
            [avg, q5, realized] = scenario_b_payoff_stats(policies{m}, cfg.delta, ...
                p.theta, p, 2000, cfg.p_shock, cfg.sigma_small, cfg.shock_strength);
            im = im + 1;
            performanceRows(im, :) = {mode, seed, methods(m), 2000, avg, q5, ...
                mean(policies{m}(:, 1))};
            if m == 3
                matchedReference = realized;
            elseif m == 4
                assert(max(abs(realized-matchedReference)) < 1e-12, ...
                    'Matched policies give different realized payoffs.');
            end
        end
    end
    fprintf('[PASS] Common-noise realized-payoff control: %s\n', mode);
end
performanceTable = cell2table(performanceRows, 'VariableNames', ...
    {'Scenario','Seed','Method','Samples','MeanPayoff','Q5Payoff','SCProbability'});

out = fullfile(root, 'table');
writetable(endpointTable, fullfile(out, 'table5_11_interval_endpoints.csv'));
writetable(policyTable, fullfile(out, 'table5_11_interval_equivalence.csv'));
writetable(mechanismTable, fullfile(out, 'table5_11_interval_mechanisms.csv'));
writetable(performanceTable, fullfile(out, 'table5_11_interval_performance.csv'));
fprintf('Completed: %d endpoint audits, %d paired solves, %d mechanism cases.\n', ...
    height(endpointTable), height(policyTable), height(mechanismTable));
fprintf('Max endpoint / policy / KM / EKM errors: %.3g / %.3g / %.3g / %.3g\n', ...
    max(endpointTable.EndpointError), max(policyTable.PolicyMaxAgentL1), ...
    max(endpointTable.KMError), max(endpointTable.EKMError));
end

function p = case_params(base, c)
p = base;
p.fou_modulation = c == 2;
p.fou_strategy_scale = ones(1, p.num_strategies);
if c == 3
    cfg = scenario_b_config('concentrated');
    p = scenario_b_env(p, cfg.fou_scale);
elseif c == 4
    p.payoff_aggregation = 'linear';
end
end

function [lo, hi, clipped] = interval_endpoints(pi, delta, p)
% Plain monotone interval arithmetic; independent of the IT2 payoff helpers.
opponents = (sum(pi, 1)-pi)/(p.N-1);
kernels = {p.trust_matrix, p.delay_matrix, p.res_matrix};
lo = zeros(size(pi)); hi = lo; clipped = 0;
for k = 1:3
    mu = min(1, max(0, opponents*kernels{k}'));
    band = delta*ones(size(mu));
    if isfield(p, 'fou_modulation') && p.fou_modulation
        band = delta*4*mu.*(1-mu);
    end
    if isfield(p, 'fou_strategy_scale')
        band = band.*reshape(p.fou_strategy_scale, 1, []);
    end
    clipped = clipped + nnz(mu-band < 0 | mu+band > 1);
    lower = max(0, mu-band); upper = min(1, mu+band);
    if strcmp(p.payoff_aggregation, 'concave_quadratic')
        lower = 2*lower-lower.^2; upper = 2*upper-upper.^2;
    end
    lo = lo+p.theta(k)*lower;
    hi = hi+p.theta(k)*upper;
end
assert(all(lo <= hi+1e-14, 'all'), 'Invalid interval.');
end

function [pi, h] = interval_solve(p, delta, alpha, flatRadius)
% Same initialization/damping, direct endpoint scoring; no type reduction.
rng(p.rng_seed);
pi = ones(p.N, p.num_strategies)/p.num_strategies + 0.01*rand(p.N, p.num_strategies);
pi = pi./sum(pi, 2);
h.residual = zeros(p.R_max, 1);
h.strategy_dist = zeros(p.R_max, p.num_strategies);
for r = 1:p.R_max
    [lo, hi] = interval_endpoints(pi, delta, p);
    score = (1-alpha/2)*lo+(alpha/2)*hi;
    if flatRadius
        score = (lo+hi)/2-(1-alpha)*mean((hi-lo)/2, 2);
    end
    next = zeros(size(pi));
    for i = 1:p.N
        br = sec4_3_1_softmax_br(score(i, :)', p.lambda);
        next(i, :) = (1-p.beta)*pi(i, :)+p.beta*br';
    end
    h.residual(r) = max(sum(abs(next-pi), 2));
    h.strategy_dist(r, :) = mean(next, 1);
    pi = next;
    if h.residual(r) <= p.eps_tol, break; end
end
h.iterations = r;
h.residual = h.residual(1:r);
h.strategy_dist = h.strategy_dist(1:r, :);
h.converged = h.residual(end) <= p.eps_tol;
end

function [err, kmErr, ekmErr, clipped] = audit_endpoints(p, delta)
rng(p.rng_seed+11000);
vertices = eye(p.num_strategies);
profiles = cell(7, 1);
profiles{1} = ones(p.N, p.num_strategies)/p.num_strategies;
for j = 1:p.num_strategies
    profiles{j+1} = repmat(vertices(j, :), p.N, 1);
end
profiles{6} = rand(p.N, p.num_strategies);
profiles{6} = profiles{6}./sum(profiles{6}, 2);
profiles{7} = vertices(mod((1:p.N)-1, p.num_strategies)+1, :);
err = 0; kmErr = 0; ekmErr = 0; clipped = 0;
for b = 1:numel(profiles)
    [lo, hi, nclip] = interval_endpoints(profiles{b}, delta, p);
    [refLo, refHi] = sec4_1_2_pure_interval_payoff_matrix(profiles{b}, delta, p.theta, p);
    err = max([err, max(abs(lo-refLo), [], 'all'), max(abs(hi-refHi), [], 'all')]);
    clipped = clipped+nclip;
    for j = 1:p.num_strategies
        [kl, ku] = sec5_1_km_type_reduction(lo(1, j), hi(1, j), 101, false);
        [el, eu] = sec5_1_km_type_reduction(lo(1, j), hi(1, j), 101, true);
        kmErr = max([kmErr, abs(kl-lo(1, j)), abs(ku-hi(1, j))]);
        ekmErr = max([ekmErr, abs(el-lo(1, j)), abs(eu-hi(1, j))]);
    end
end
assert(max([err, kmErr, ekmErr]) < 1e-12, 'Endpoint audit failed.');
end
