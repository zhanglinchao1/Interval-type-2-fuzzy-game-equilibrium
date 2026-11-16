function exp_5_1_6c_m5_certificate_sota(mode)
%EXP_5_1_6C_M5_CERTIFICATE_SOTA Compare certified scalar and focused points.
%   Re-runs concentrated-shock Scenario B over the same 20 paired seeds.
%   The a-priori anchor uses (alpha,s,lambda)=(0.5,0,0.20). The reported
%   focused point uses (0.5,40,[0.15,0.002]); Appendix C-J certifies both
%   stages. Terminal exploitability supplies the robust-FNE budget.

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
addpath(genpath(fullfile(script_dir, 'SOTA')));

if nargin > 0 && strcmp(mode, 'r3')
    run_r3_ablation(script_dir);
    return;
end

table_dir = fullfile(script_dir, 'table');
raw_path = fullfile(table_dir, 'table5_6m_m5_certificate_sota_raw.csv');
summary_path = fullfile(table_dir, 'table5_6m_m5_certificate_sota.csv');
paired_path = fullfile(table_dir, 'table5_6n_m5_sota_paired.csv');

methods = {'Proposed-Prior', 'Proposed-Posterior', 'Isobe-APP', ...
    'RQE', 'MF-RQE', 'CVaR-game', 'DRNE-VI'};
seeds = 42:61;
gamma_ce = 0.55;
env = scenario_b_config('concentrated');
rows = cell(numel(methods) * numel(seeds), 20);
row_idx = 1;

for seed = seeds
    params = config_params();
    params.N = 50;
    params.R_max = 300;
    params.rng_seed = seed;
    params_B = scenario_b_env(params, env.fou_scale);
    params_B.shock_mode = env.shock_mode;
    theta = params.theta;

    for method_idx = 1:numel(methods)
        method = methods{method_idx};
        tic_id = tic;
        [pi_star, history, alpha, focus_s, lambda_start, lambda_end, ...
            cert_type, global_contraction] = solve_point( ...
            method, params_B, env.delta, theta);
        runtime_sec = toc(tic_id);

        [expected_payoff, wc_q5] = scenario_b_payoff_stats( ...
            pi_star, env.delta, theta, params_B, 2000, env.p_shock, ...
            env.sigma_small, env.shock_strength);
        ce_055 = expected_payoff - gamma_ce * (expected_payoff - wc_q5);

        [eps_ne, eps_alpha, stage_1, stage_2] = certificate_metrics( ...
            method, pi_star, history, env.delta, theta, alpha, focus_s, ...
            params_B);
        rounds = get_history_value(history, 'iterations', NaN);
        final_residual = get_final_residual(history);
        q_hat = estimate_q_hat(history);

        rows(row_idx, :) = {method, seed, alpha, focus_s, lambda_start, ...
            lambda_end, cert_type, global_contraction, stage_1, stage_2, ...
            rounds, q_hat, final_residual, eps_ne, eps_alpha, ...
            expected_payoff, wc_q5, ce_055, mean(pi_star(:, 1)), runtime_sec};
        row_idx = row_idx + 1;

        fprintf(['%-20s seed=%d R=%3d E=%.4f Q5=%.4f CE=%.4f ' ...
            'epsNE=%.3e epsA=%.3e\n'], method, seed, rounds, ...
            expected_payoff, wc_q5, ce_055, eps_ne, eps_alpha);
    end
end

raw = cell2table(rows, 'VariableNames', ...
    {'Method','Seed','Alpha','FocusS','LambdaStart','LambdaEnd', ...
     'CertificateType','GlobalContraction','Stage1Rounds','Stage2Rounds', ...
     'Rounds','qHat','FinalResidual','EpsNE','EpsAlpha','ExpectedPayoff', ...
     'WorstCaseQ5','CE_055','SCShare','RuntimeSec'});
writetable(raw, raw_path);

summary = summarize_results(raw, methods);
writetable(summary, summary_path);

paired = paired_results(raw, 'Proposed-Posterior', methods(3:end));
writetable(paired, paired_path);

fprintf('\n===== M5 certified scalar/focused SOTA summary =====\n');
disp(summary);
fprintf('[table] %s\n', summary_path);
fprintf('[table] %s\n', paired_path);
end

function [pi_star, history, alpha, focus_s, lambda_start, lambda_end, ...
    cert_type, global_contraction] = solve_point( ...
    method, params, delta, theta)

alpha = NaN;
focus_s = NaN;
lambda_start = NaN;
lambda_end = NaN;
cert_type = 'None';
global_contraction = false;

switch method
    case 'Proposed-Prior'
        alpha = 0.5;
        focus_s = 0;
        lambda_start = 0.20;
        lambda_end = 0.20;
        p = params;
        p.lambda = lambda_start;
        [pi_star, history] = sec4_3_1_wfbri_solve( ...
            p, delta, theta, alpha, focus_s);
        cert_type = 'A-priori contraction';
        global_contraction = true;
    case 'Proposed-Posterior'
        alpha = 0.5;
        focus_s = 40;
        lambda_start = 0.15;
        lambda_end = 0.002;
        p = params;
        p.lambda_path = [lambda_start, lambda_end];
        [pi_star, history] = sec4_3_1_wfbri_solve( ...
            p, delta, theta, alpha, focus_s);
        cert_type = 'Global contraction and terminal exploitability';
        global_contraction = true;
    case 'Isobe-APP'
        [pi_star, history] = solve_isobe_app(params, 0, theta, 1.0);
    case 'RQE'
        [pi_star, history] = solve_rqe(params, 0, theta, 1.0);
    case 'MF-RQE'
        [pi_star, history] = solve_mf_rqe(params, delta, theta, 1.0);
    case 'CVaR-game'
        [pi_star, history] = solve_cvar_game(params, delta, theta, 1.0);
    case 'DRNE-VI'
        [pi_star, history] = solve_drne_vi(params, delta, theta, 1.0);
    otherwise
        error('exp_5_1_6c:unknownMethod', 'Unknown method: %s', method);
end
end

function [eps_ne, eps_alpha, stage_1, stage_2] = certificate_metrics( ...
    method, pi_star, history, delta, theta, alpha, focus_s, params)

eps_ne = NaN;
eps_alpha = NaN;
stage_1 = NaN;
stage_2 = NaN;
if ~startsWith(method, 'Proposed-')
    return;
end

eps_ne = history.eps_ne;
report = sec4_2_2_robust_alpha_fne( ...
    pi_star, delta, theta, alpha, params, [], focus_s);
eps_alpha = report.profile_certificate;
stage_1 = history.stage_iterations(1);
if numel(history.stage_iterations) > 1
    stage_2 = history.stage_iterations(2);
end
end

function summary = summarize_results(raw, methods)
rows = cell(numel(methods), 22);
for idx = 1:numel(methods)
    subset = raw(strcmp(raw.Method, methods{idx}), :);
    rows(idx, :) = {methods{idx}, subset.CertificateType{1}, ...
        subset.GlobalContraction(1), subset.Alpha(1), subset.FocusS(1), ...
        subset.LambdaStart(1), subset.LambdaEnd(1), ...
        mean(subset.Stage1Rounds, 'omitnan'), ...
        mean(subset.Stage2Rounds, 'omitnan'), mean(subset.Rounds), ...
        mean(subset.EpsNE, 'omitnan'), mean(subset.EpsAlpha, 'omitnan'), ...
        mean(subset.ExpectedPayoff), ci95(subset.ExpectedPayoff), ...
        mean(subset.WorstCaseQ5), ci95(subset.WorstCaseQ5), ...
        mean(subset.CE_055), ci95(subset.CE_055), ...
        mean(subset.SCShare), ci95(subset.SCShare), ...
        mean(subset.RuntimeSec), ci95(subset.RuntimeSec)};
end
summary = cell2table(rows, 'VariableNames', ...
    {'Method','CertificateType','GlobalContraction','Alpha','FocusS', ...
     'LambdaStart','LambdaEnd','Stage1Rounds','Stage2Rounds','Rounds', ...
     'EpsNE','EpsAlpha','ExpectedPayoff','ExpectedPayoffCI95', ...
     'WorstCaseQ5','WorstCaseQ5CI95','CE_055','CE_055CI95', ...
     'SCShare','SCShareCI95','RuntimeSec','RuntimeSecCI95'});
end

function paired = paired_results(raw, proposed_name, baselines)
metrics = {'ExpectedPayoff','WorstCaseQ5','CE_055'};
rows = cell(numel(baselines) * numel(metrics), 7);
row_idx = 1;
proposed = raw(strcmp(raw.Method, proposed_name), :);
for baseline_idx = 1:numel(baselines)
    baseline_name = baselines{baseline_idx};
    baseline = raw(strcmp(raw.Method, baseline_name), :);
    [~, order] = ismember(proposed.Seed, baseline.Seed);
    baseline = baseline(order, :);
    for metric_idx = 1:numel(metrics)
        metric = metrics{metric_idx};
        difference = proposed.(metric) - baseline.(metric);
        half_width = ci95(difference);
        rows(row_idx, :) = {baseline_name, metric, mean(difference), ...
            mean(difference) - half_width, mean(difference) + half_width, ...
            all(difference > 0), numel(difference)};
        row_idx = row_idx + 1;
    end
end
paired = cell2table(rows, 'VariableNames', ...
    {'Baseline','Metric','MeanDifference','CI95Low','CI95High', ...
     'WinsAllSeeds','NumPairs'});
end

function value = get_history_value(history, field, fallback)
if isfield(history, field)
    value = history.(field);
else
    value = fallback;
end
end

function residual = get_final_residual(history)
if isfield(history, 'residual') && ~isempty(history.residual)
    residual = history.residual(end);
else
    residual = NaN;
end
end

function q_hat = estimate_q_hat(history)
if ~isfield(history, 'residual') || numel(history.residual) < 2
    q_hat = NaN;
    return;
end
positive = history.residual(history.residual > 0);
if numel(positive) < 2
    q_hat = NaN;
else
    q_hat = exp(mean(diff(log(positive))));
end
end

function half_width = ci95(values)
values = values(~isnan(values));
if numel(values) < 2
    half_width = 0;
else
    half_width = 1.96 * std(values, 0) / sqrt(numel(values));
end
end

function run_r3_ablation(script_dir)
% R3-3: same solver, kernels, noise draws and stopping tolerance in all cells.
env = scenario_b_config('concentrated');
p = config_params(); p.N = 50; p.R_max = 300;
p = scenario_b_env(p,env.fou_scale); p.shock_mode = env.shock_mode;
table_dir = fullfile(script_dir,'table');
c0 = sec4_3_1_scenario_b_certificate(p,env.delta,p.theta,0.5,0,[0.20,0.15,0.002]);
c40 = sec4_3_1_scenario_b_certificate(p,env.delta,p.theta,0.5,40,[0.15,0.002]);
cert_rows = [zeros(3,1),c0.lambda',c0.kappa',c0.q', ...
    repmat(c0.num_leaves,3,1);40*ones(2,1),c40.lambda',c40.kappa',c40.q', ...
    repmat(c40.num_leaves,2,1)];
cert_table = array2table(cert_rows,'VariableNames', ...
    {'FocusS','Lambda','KappaUpper','DampedQUpper','CoverLeaves'});
writetable(cert_table,fullfile(table_dir,'table5_6o_r3_certificate.csv'));
disp(cert_table);
check_report = check_r3_certificate(p,env,c0,c40);
save(fullfile(table_dir,'table5_6o_r3_certificate.mat'),'c0','c40','p','env','check_report');

methods = {'Scalar-0.20','Scalar-0.15','Scalar-annealed', ...
    'Focused-0.15','Focused-annealed','Focused-0.002','Pure-SP','SC02-SP98'};
focus = [0,0,0,40,40,40,40,40];
paths = {0.20,0.15,[0.15,0.002],0.15,[0.15,0.002],0.002,[],[]};
seeds = 42:61; rows = cell(numel(methods)*numel(seeds),18); count = 0;
profiles = zeros(p.N,4,numel(methods),numel(seeds));
for si = 1:numel(seeds)
    p.rng_seed = seeds(si);
    for mi = 1:numel(methods)
        if mi <= 6
            pm = p; pm.lambda_path = paths{mi};
            [pi_star,h] = sec4_3_1_wfbri_solve(pm,env.delta,p.theta,0.5,focus(mi));
            assert(h.converged,'R3 ablation did not reach the stopping tolerance.');
            rounds = h.iterations; residual = h.fixed_point_residual;
            stage1 = h.stage_iterations(1); stage2 = NaN;
            if numel(h.stage_iterations)>1; stage2 = h.stage_iterations(2); end
            if focus(mi)==0; cert = c0; else; cert = c40; end
            [found,idx] = ismember(paths{mi},cert.lambda); assert(all(found));
            kappa = max(cert.kappa(idx)); globally_certified = all(cert.certified(idx));
        else
            q = [0,1,0,0]; if mi==8; q = [0.02,0.98,0,0]; end
            pi_star = repmat(q,p.N,1); rounds = 0; residual = NaN;
            stage1 = 0; stage2 = NaN; kappa = NaN; globally_certified = false;
        end
        report = sec4_2_2_robust_alpha_fne(pi_star,env.delta,p.theta,0.5,p,[],focus(mi));
        assert(report.certificate_slack >= -1e-10);
        [avg,q5] = scenario_b_payoff_stats(pi_star,env.delta,p.theta,p,2000, ...
            env.p_shock,env.sigma_small,env.shock_strength);
        ce = 0.45*avg+0.55*q5; count = count+1;
        rows(count,:) = {methods{mi},seeds(si),focus(mi),rounds,stage1,stage2, ...
            kappa,globally_certified,residual,report.eps_ne,report.profile_certificate, ...
            avg,q5,ce,mean(pi_star(:,1)),mean(pi_star(:,2)), ...
            mean(pi_star(:,3)),mean(pi_star(:,4))};
        profiles(:,:,mi,si) = pi_star;
    end
    fprintf('R3 seed=%d: all eight matched configurations completed.\n',seeds(si));
end
raw = cell2table(rows,'VariableNames',{'Method','Seed','FocusS','Rounds', ...
    'Stage1Rounds','Stage2Rounds','KappaUpper','GlobalContraction','FinalResidual', ...
    'EpsNE','EpsAlpha','ExpectedPayoff','WorstCaseQ5','CE_055', ...
    'SCShare','SPShare','DCShare','DPShare'});
writetable(raw,fullfile(table_dir,'table5_6p_r3_ablation_raw.csv'));
save(fullfile(table_dir,'table5_6p_r3_ablation.mat'),'raw', ...
    'profiles','methods','paths','seeds','p','env');
metrics = {'Rounds','EpsNE','EpsAlpha','ExpectedPayoff','WorstCaseQ5','CE_055','SCShare'};
summary_rows = cell(numel(methods),2+2*numel(metrics));
for mi = 1:numel(methods)
    sub = raw(strcmp(raw.Method,methods{mi}),:);
    summary_rows(mi,1:2) = {methods{mi},sub.GlobalContraction(1)};
    for j = 1:numel(metrics)
        v = sub.(metrics{j}); summary_rows(mi,2*j+1:2*j+2) = {mean(v),t_ci(v)};
    end
end
names = {'Method','GlobalContraction'};
for j = 1:numel(metrics); names(end+1:end+2) = {metrics{j},[metrics{j},'CI95']}; end
summary = cell2table(summary_rows,'VariableNames',names);
writetable(summary,fullfile(table_dir,'table5_6p_r3_ablation.csv'));
contrasts = [4,2;5,3;3,2;5,4;6,5;8,5;7,5];
pair_rows = cell(size(contrasts,1)*3,7); count = 0;
for ci = 1:size(contrasts,1)
    A = raw(strcmp(raw.Method,methods{contrasts(ci,1)}),:);
    B = raw(strcmp(raw.Method,methods{contrasts(ci,2)}),:);
    assert(isequal(A.Seed,B.Seed));
    for name = {'ExpectedPayoff','WorstCaseQ5','CE_055'}
        v = A.(name{1})-B.(name{1}); m = mean(v); h = t_ci(v); count = count+1;
        pair_rows(count,:) = {A.Method{1},B.Method{1},name{1},m,m-h,m+h,numel(v)};
    end
end
paired = cell2table(pair_rows,'VariableNames', ...
    {'MethodA','MethodB','Metric','Difference','CI95Low','CI95High','NumPairs'});
writetable(paired,fullfile(table_dir,'table5_6q_r3_paired.csv'));
save(fullfile(table_dir,'table5_6p_r3_ablation.mat'),'summary','paired','-append');
disp(summary); disp(paired);
fprintf('[PASS] R3 matched ablation: %d rows; original payoff and solver reused.\n',height(raw));
end

function report = check_r3_certificate(p,env,c0,c40)
% Independent finite-difference check against the canonical payoff evaluator.
% This diagnoses implementation errors; the tetrahedron cover supplies proof.
rng(90303); X = -log(rand(100,4)); X = X./sum(X,2);
pairs = nchoosek(1:4,2); certs = {c0,c40}; measured = cell(1,2);
h = 1e-6;
for ci = 1:2
    c = certs{ci}; slopes = zeros(size(c.lambda));
    for xi = 1:size(X,1)
        x = X(xi,:);
        for di = 1:6
            d = zeros(1,4); d(pairs(di,:)) = [1,-1];
            xp = x+h*d; xm = x-h*d; assert(all(xp>=0) && all(xm>=0));
            np = r3_payoff(xp,c.focus_s); nm = r3_payoff(xm,c.focus_s);
            for ti = 1:numel(c.lambda)
                bp = sec4_3_1_softmax_br(np',c.lambda(ti));
                bm = sec4_3_1_softmax_br(nm',c.lambda(ti));
                slope = sum(abs(bp-bm))/(4*h);
                assert(slope<=c.kappa(ti)+1e-7,'Canonical derivative exceeds cover bound.');
                slopes(ti) = max(slopes(ti),slope);
            end
        end
    end
    measured{ci} = slopes;
end
report = struct('points',size(X,1),'directions',6,'h',h, ...
    'scalar_sampled_slopes',measured{1},'focused_sampled_slopes',measured{2});
fprintf('[PASS] Canonical finite differences under all global bounds.\n'); disp(report);
    function nu = r3_payoff(x,s)
        [~,~,C,R] = sec4_1_2_pure_interval_payoff_matrix(repmat(x,p.N,1),env.delta,p.theta,p);
        P = 0.5*R;
        if s>0; P = P.*(R./max(max(R,[],2),0.01)).^s; end
        nu = C(1,:)-P(1,:);
    end
end

function h = t_ci(v)
% Student-t quantile through the base-MATLAB inverse incomplete beta.
df = numel(v)-1;
critical = sqrt(df*(1/betaincinv(0.05,df/2,0.5)-1));
h = critical*std(v,0)/sqrt(numel(v));
end
