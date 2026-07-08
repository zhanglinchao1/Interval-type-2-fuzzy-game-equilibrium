% diag_scenario_b_ce_global.m
% Reviewer-facing diagnostic: can a single Scenario-B strategy be globally
% best on mean payoff, lower-tail payoff, and CE_gamma?

clearvars -except grid_step repeats seed_list; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));

if ~exist('grid_step', 'var') || isempty(grid_step)
    grid_step = 0.02;
end
if ~exist('repeats', 'var') || isempty(repeats)
    repeats = 2000;
end
if ~exist('seed_list', 'var') || isempty(seed_list)
    seed_list = 42:51;
end

gamma_ce = 0.55;
scenarioB_N = 50;
theta_true = config_params().theta;
q_grid = simplex_grid4(grid_step);

fprintf('===== Scenario-B CE global diagnostic =====\n');
fprintf('grid_step=%.3f, nQ=%d, seeds=[%d..%d], repeats=%d, gamma=%.2f\n', ...
    grid_step, size(q_grid, 1), seed_list(1), seed_list(end), repeats, gamma_ce);

modes = {'concentrated', 'dispersed'};
summary_rows = {};
candidate_rows = {};

for mode_idx = 1:numel(modes)
    mode = modes{mode_idx};
    cfg = scenario_b_config(mode);
    [E_mean, WC_mean, CE_mean] = scan_mode(q_grid, seed_list, repeats, ...
        scenarioB_N, theta_true, cfg, gamma_ce);

    [best_E, idx_E] = max(E_mean);
    [best_WC, idx_WC] = max(WC_mean);
    [best_CE, idx_CE] = max(CE_mean);

    fprintf('\n[%s]\n', mode);
    print_best('maxE ', q_grid(idx_E, :), best_E, WC_mean(idx_E), CE_mean(idx_E));
    print_best('maxWC', q_grid(idx_WC, :), E_mean(idx_WC), best_WC, CE_mean(idx_WC));
    print_best('maxCE', q_grid(idx_CE, :), E_mean(idx_CE), WC_mean(idx_CE), best_CE);

    thresholds = read_table_iv_thresholds(script_dir, mode);
    if ~isempty(thresholds)
        all3 = E_mean >= thresholds.best_E & ...
            WC_mean >= thresholds.best_WC & ...
            CE_mean >= thresholds.best_CE;
        wc_ce = WC_mean >= thresholds.best_WC & ...
            CE_mean >= thresholds.best_CE;
        fprintf('points beating Table-IV best E/WC/CE simultaneously: %d\n', sum(all3));
        fprintf('points beating Table-IV best WC and CE simultaneously: %d\n', sum(wc_ce));
        fprintf('Table-IV best thresholds: E=%.6f, WC=%.6f, CE=%.6f\n', ...
            thresholds.best_E, thresholds.best_WC, thresholds.best_CE);
    else
        all3 = false(size(E_mean));
        wc_ce = false(size(E_mean));
    end

    summary_rows(end + 1, :) = {mode, grid_step, repeats, numel(seed_list), ...
        'maxE', q_grid(idx_E, 1), q_grid(idx_E, 2), q_grid(idx_E, 3), ...
        q_grid(idx_E, 4), best_E, WC_mean(idx_E), CE_mean(idx_E), ...
        sum(all3), sum(wc_ce)}; %#ok<AGROW>
    summary_rows(end + 1, :) = {mode, grid_step, repeats, numel(seed_list), ...
        'maxWC', q_grid(idx_WC, 1), q_grid(idx_WC, 2), q_grid(idx_WC, 3), ...
        q_grid(idx_WC, 4), E_mean(idx_WC), best_WC, CE_mean(idx_WC), ...
        sum(all3), sum(wc_ce)}; %#ok<AGROW>
    summary_rows(end + 1, :) = {mode, grid_step, repeats, numel(seed_list), ...
        'maxCE', q_grid(idx_CE, 1), q_grid(idx_CE, 2), q_grid(idx_CE, 3), ...
        q_grid(idx_CE, 4), E_mean(idx_CE), WC_mean(idx_CE), best_CE, ...
        sum(all3), sum(wc_ce)}; %#ok<AGROW>

    top_idx = topk_indices(CE_mean, 10);
    for k = 1:numel(top_idx)
        idx = top_idx(k);
        candidate_rows(end + 1, :) = {mode, k, q_grid(idx, 1), ...
            q_grid(idx, 2), q_grid(idx, 3), q_grid(idx, 4), ...
            E_mean(idx), WC_mean(idx), CE_mean(idx)}; %#ok<AGROW>
    end
end

summary_table = cell2table(summary_rows, 'VariableNames', ...
    {'Scenario','GridStep','Repeats','NumSeeds','Optimum','q_SC','q_SP', ...
     'q_DC','q_DP','ExpectedPayoff','WorstCaseQ5','CE_gamma', ...
     'NumBeatAll3','NumBeatWCAndCE'});
candidate_table = cell2table(candidate_rows, 'VariableNames', ...
    {'Scenario','Rank','q_SC','q_SP','q_DC','q_DP', ...
     'ExpectedPayoff','WorstCaseQ5','CE_gamma'});

tbl_dir = fullfile(script_dir, 'table');
if ~exist(tbl_dir, 'dir'); mkdir(tbl_dir); end
writetable(summary_table, fullfile(tbl_dir, 'diag_scenario_b_global_ce_summary.csv'));
writetable(candidate_table, fullfile(tbl_dir, 'diag_scenario_b_global_ce_top10.csv'));

disp(summary_table);

function [E_mean, WC_mean, CE_mean] = scan_mode(q_grid, seed_list, repeats, ...
    scenarioB_N, theta_true, cfg, gamma_ce)
    nQ = size(q_grid, 1);
    E_acc = zeros(nQ, 1);
    WC_acc = zeros(nQ, 1);
    CE_acc = zeros(nQ, 1);
    phi = kron_features(q_grid);

    for s_idx = 1:numel(seed_list)
        base = config_params();
        base.N = scenarioB_N;
        base.rng_seed = seed_list(s_idx);
        params_B = scenario_b_env(base, cfg.fou_scale);
        params_B.shock_mode = cfg.shock_mode;
        R = scenario_b_reduced_realizations(params_B, theta_true, repeats, ...
            cfg.p_shock, cfg.sigma_small, cfg.shock_strength);
        [E_seed, WC_seed] = evaluate_grid(phi, R);
        CE_seed = (1 - gamma_ce) * E_seed + gamma_ce * WC_seed;
        E_acc = E_acc + E_seed;
        WC_acc = WC_acc + WC_seed;
        CE_acc = CE_acc + CE_seed;
        fprintf('  [%s] seed=%d done\n', cfg.shock_mode, seed_list(s_idx));
    end

    E_mean = E_acc / numel(seed_list);
    WC_mean = WC_acc / numel(seed_list);
    CE_mean = CE_acc / numel(seed_list);
end

function R = scenario_b_reduced_realizations(params, theta_true, n_perturb, ...
    p_shock, sigma_small, shock_strength)
    num_s = params.num_strategies;
    R = zeros(num_s * num_s, n_perturb);
    dispersed = isfield(params, 'shock_mode') && strcmp(params.shock_mode, 'dispersed');
    if dispersed
        target_dist = params.fou_strategy_scale(:)' / sum(params.fou_strategy_scale);
    end

    rng(params.rng_seed + 520);
    for k = 1:n_perturb
        p = params;
        p.theta = theta_true;
        p.trust_matrix = clip01(params.trust_matrix + ...
            sigma_small * randn(size(params.trust_matrix)));
        p.delay_matrix = clip01(params.delay_matrix + ...
            sigma_small * randn(size(params.delay_matrix)));
        p.res_matrix = clip01(params.res_matrix + ...
            sigma_small * randn(size(params.res_matrix)));

        if rand() < p_shock
            if dispersed
                t = sample_target(target_dist);
            else
                t = 1;
            end
            p.trust_matrix = apply_strategy_shock(p.trust_matrix, t, shock_strength);
            p.delay_matrix = apply_strategy_shock(p.delay_matrix, t, shock_strength);
            p.res_matrix = apply_strategy_shock(p.res_matrix, t, shock_strength);
        end

        G = build_reduced_interval_game(p, 0);
        R(:, k) = reshape(G.U_hat, [], 1);
    end
end

function [E, WC] = evaluate_grid(phi, R)
    nQ = size(phi, 1);
    E = zeros(nQ, 1);
    WC = zeros(nQ, 1);
    chunk = 5000;
    for a = 1:chunk:nQ
        b = min(nQ, a + chunk - 1);
        V = phi(a:b, :) * R;
        E(a:b) = mean(V, 2);
        WC(a:b) = quantile(V, 0.05, 2);
    end
end

function phi = kron_features(q)
    nQ = size(q, 1);
    phi = zeros(nQ, 16);
    c = 1;
    for j = 1:4
        for l = 1:4
            phi(:, c) = q(:, j) .* q(:, l);
            c = c + 1;
        end
    end
end

function q = simplex_grid4(step)
    n = round(1 / step);
    rows = zeros((n + 1) * (n + 2) * (n + 3) / 6, 4);
    idx = 1;
    for a = 0:n
        for b = 0:(n - a)
            for c = 0:(n - a - b)
                d = n - a - b - c;
                rows(idx, :) = [a, b, c, d] / n;
                idx = idx + 1;
            end
        end
    end
    q = rows(1:idx - 1, :);
end

function thresholds = read_table_iv_thresholds(script_dir, mode)
    if strcmp(mode, 'dispersed')
        f = fullfile(script_dir, 'table', 'table5_6b_sota_scenarioB_v2.csv');
    else
        f = fullfile(script_dir, 'table', 'table5_6b_sota_scenarioB.csv');
    end
    if ~exist(f, 'file')
        thresholds = [];
        return;
    end
    T = readtable(f);
    if ismember('ExpectedPayoffMean', T.Properties.VariableNames)
        thresholds.best_E = max(T.ExpectedPayoffMean);
        thresholds.best_WC = max(T.WorstCaseQ5Mean);
        thresholds.best_CE = max(T.CEGammaMean);
    else
        thresholds.best_E = max(T.ExpectedPayoff);
        thresholds.best_WC = max(T.WorstCaseQ5);
        thresholds.best_CE = max(T.CE_gamma);
    end
end

function idx = topk_indices(x, k)
    [~, ord] = sort(x, 'descend');
    idx = ord(1:min(k, numel(ord)));
end

function print_best(label, q, E, WC, CE)
    fprintf('%s q=[%.2f %.2f %.2f %.2f] E=%.6f WC=%.6f CE=%.6f\n', ...
        label, q(1), q(2), q(3), q(4), E, WC, CE);
end

function M = apply_strategy_shock(M, t, shock_strength)
    M(t, :) = M(t, :) - shock_strength;
    M(:, t) = M(:, t) - 0.5 * shock_strength;
    M = clip01(M);
end

function t = sample_target(prob)
    c = cumsum(prob);
    u = rand();
    t = find(u <= c, 1, 'first');
    if isempty(t)
        t = numel(prob);
    end
end

function y = clip01(x)
    y = max(0, min(1, x));
end
