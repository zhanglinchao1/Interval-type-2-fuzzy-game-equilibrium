function exp_5_1_6b_proposed_upgrade(mode, seed_group, methods_sel)
%EXP_5_1_6B_PROPOSED_UPGRADE 方法论升级验证 (stag.md 改动 A/B)。
%   在与主表完全相同的 Scenario B 协议 (scenario_b_config / scenario_b_env /
%   scenario_b_payoff_stats, 2000 重复, 共享 beta=0.3, eps_tol=1e-4) 下,
%   对比升级后的 Proposed 与 5 个 SOTA 基线。评价协议零改动。
%
%   用法 (可分块断点续跑, 结果逐行追加到 CSV):
%       exp_5_1_6b_proposed_upgrade                         % 全部
%       exp_5_1_6b_proposed_upgrade('concentrated','main')  % 单块
%       exp_5_1_6b_proposed_upgrade('summary')              % 汇总+PASS判定
%
%   seed_group: 'main' = seeds 42..51 (与主表 table5_6b 可比);
%               'holdout' = seeds 52..61 (独立确认, 防选点过拟合)。
%   输出: table/table5_6k_proposed_upgrade.csv

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
addpath(genpath(fullfile(script_dir, 'SOTA')));
csv_path = fullfile(script_dir, 'table', 'table5_6k_proposed_upgrade.csv');

all_methods = {'Proposed-Base', 'Proposed-Anneal', 'Proposed-Coherent', ...
    'Proposed-V1Deep', 'Proposed-V2Deep', ...
    'Isobe-APP', 'RQE', 'MF-RQE', 'CVaR-game', 'DRNE-VI'};

if nargin >= 1 && strcmp(mode, 'summary')
    summarize_and_check(csv_path);
    return;
end

if nargin < 1 || isempty(mode)
    modes = {'concentrated', 'dispersed'};
else
    modes = {mode};
end
if nargin < 2 || isempty(seed_group)
    seed_groups = {'main', 'holdout'};
else
    seed_groups = {seed_group};
end
if nargin < 3 || isempty(methods_sel)
    methods_sel = all_methods;
elseif ischar(methods_sel)
    methods_sel = {methods_sel};
end

% 已完成行 (断点续跑)
done = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if isfile(csv_path)
    T0 = readtable(csv_path);
    for t = 1:height(T0)
        done(row_key(T0.Mode{t}, T0.SeedGroup{t}, T0.Method{t}, ...
            T0.Seed(t))) = true;
    end
end

gamma_ce = 0.55;
for m_idx = 1:numel(modes)
    env = scenario_b_config(modes{m_idx});
    for g_idx = 1:numel(seed_groups)
        if strcmp(seed_groups{g_idx}, 'main')
            seeds = 42:51;
        else
            seeds = 52:61;
        end
        for sd = seeds
            params = config_params();
            params.N = 50;
            params.R_max = 300;    % 与 exp_5_1_6 主实验协议一致 (DRNE 300 上限)
            params.rng_seed = sd;
            params_B = scenario_b_env(params, env.fou_scale);
            params_B.shock_mode = env.shock_mode;
            theta = params.theta;

            for k = 1:numel(methods_sel)
                method = methods_sel{k};
                key = row_key(modes{m_idx}, seed_groups{g_idx}, method, sd);
                if isKey(done, key); continue; end

                t0 = tic;
                [pi_star, hist] = solve_method(method, params_B, ...
                    env.delta, theta);
                runtime = toc(t0);

                [E, WC] = scenario_b_payoff_stats(pi_star, env.delta, ...
                    theta, params_B, 2000, env.p_shock, ...
                    env.sigma_small, env.shock_strength);
                CE = E - gamma_ce * (E - WC);
                if isfield(hist, 'eps_ne'); eps_ne = hist.eps_ne; ...
                else; eps_ne = NaN; end
                if isfield(hist, 'iterations'); R = hist.iterations; ...
                else; R = NaN; end

                row = table({modes{m_idx}}, {seed_groups{g_idx}}, ...
                    {method}, sd, R, E, WC, CE, mean(pi_star(:, 1)), ...
                    eps_ne, runtime, 'VariableNames', ...
                    {'Mode', 'SeedGroup', 'Method', 'Seed', 'Rounds', ...
                    'ExpectedPayoff', 'WorstCaseQ5', 'CE_055', ...
                    'SCShare', 'EpsNE', 'RuntimeSec'});
                wrote = false;
                for attempt = 1:5
                    try
                        if isfile(csv_path)
                            writetable(row, csv_path, 'WriteMode', 'append');
                        else
                            writetable(row, csv_path);
                        end
                        wrote = true;
                        break;
                    catch
                        pause(0.5 * attempt);   % 暂时性文件锁, 退避重试
                    end
                end
                if ~wrote
                    warning('write failed for %s (will be redone on resume)', key);
                else
                    done(key) = true;
                end
                fprintf('%-12s %-7s %-18s seed=%d R=%3d E=%.4f Q5=%.4f CE=%.4f SC=%.3f\n', ...
                    modes{m_idx}, seed_groups{g_idx}, method, sd, R, E, WC, ...
                    CE, mean(pi_star(:, 1)));
            end
        end
    end
end
fprintf('done. rows saved to %s\n', csv_path);
end

function [pi_star, hist] = solve_method(method, params_B, delta_true, theta)
%SOLVE_METHOD delta 口径与 exp_5_1_6 run_one_method 逐字一致。
    switch method
        case 'Proposed-Base'          % 现状固定点 (alpha=0.05, s=20, lambda=0.15)
            [pi_star, hist] = sec4_3_1_wfbri_solve(params_B, ...
                delta_true, theta, 0.05, 20);
        case 'Proposed-Anneal'        % 改动A: 认证退火 (声明调度, 其余同 Base)
            p = params_B;
            p.lambda_path = [0.15, 0.08, 0.04, 0.02];
            [pi_star, hist] = sec4_3_1_wfbri_solve(p, ...
                delta_true, theta, 0.05, 20);
        case 'Proposed-Coherent'      % 改动B: 相干尾部族 F(alpha=0.2, s=0, w=0.8)
            p = params_B;
            p.tail_w = 0.8; p.tail_acv = 0.2; p.tail_K = 64;
            [pi_star, hist] = sec4_3_2_coherent_solve(p, ...
                delta_true, theta, 0.2, 0);
        case 'Proposed-V1Deep'        % 深退火 regime 工作点 v1: (alpha=0.5, s=40)
            p = params_B;
            p.lambda_path = [0.15, 0.002];
            [pi_star, hist] = sec4_3_1_wfbri_solve(p, ...
                delta_true, theta, 0.5, 40);
        case 'Proposed-V2Deep'        % 深退火 regime 工作点 v2: (alpha=0.05, s=0)
            p = params_B;
            p.lambda_path = [0.15, 0.002];
            [pi_star, hist] = sec4_3_1_wfbri_solve(p, ...
                delta_true, theta, 0.05, 0);
        case 'Isobe-APP'              % 收敛 SOTA (FOU-agnostic, delta=0)
            [pi_star, hist] = solve_isobe_app(params_B, 0, theta, 1.0);
        case 'RQE'                    % 鲁棒 SOTA (delta=0, 风险由 tau 控制)
            [pi_star, hist] = solve_rqe(params_B, 0, theta, 1.0);
        case 'MF-RQE'                 % 鲁棒 SOTA (delta 界定场景集)
            [pi_star, hist] = solve_mf_rqe(params_B, delta_true, theta, 1.0);
        case 'CVaR-game'              % 鲁棒 SOTA (delta 界定样本)
            [pi_star, hist] = solve_cvar_game(params_B, delta_true, theta, 1.0);
        case 'DRNE-VI'                % 鲁棒 SOTA (delta 界定场景)
            [pi_star, hist] = solve_drne_vi(params_B, delta_true, theta, 1.0);
        otherwise
            error('unknown method %s', method);
    end
end

function key = row_key(mode, group, method, seed)
    key = sprintf('%s|%s|%s|%d', mode, group, method, seed);
end

function summarize_and_check(csv_path)
    T = readtable(csv_path);
    fprintf('\n===== Summary (mean over seeds) =====\n');
    modes = unique(T.Mode, 'stable');
    groups = unique(T.SeedGroup, 'stable');
    agg = struct();
    for m = 1:numel(modes)
        for g = 1:numel(groups)
            mask0 = strcmp(T.Mode, modes{m}) & strcmp(T.SeedGroup, groups{g});
            if ~any(mask0); continue; end
            fprintf('\n--- %s / %s ---\n', modes{m}, groups{g});
            methods = unique(T.Method(mask0), 'stable');
            for k = 1:numel(methods)
                msk = mask0 & strcmp(T.Method, methods{k});
                fprintf('%-18s E=%.4f WC=%.4f CE=%.4f SC=%.4f eps_ne=%.2e n=%d\n', ...
                    methods{k}, mean(T.ExpectedPayoff(msk)), ...
                    mean(T.WorstCaseQ5(msk)), mean(T.CE_055(msk)), ...
                    mean(T.SCShare(msk)), mean(T.EpsNE(msk)), sum(msk));
                agg.(matlab.lang.makeValidName( ...
                    sprintf('%s_%s_%s', modes{m}, groups{g}, methods{k}))) = ...
                    [mean(T.ExpectedPayoff(msk)), mean(T.WorstCaseQ5(msk)), ...
                    mean(T.CE_055(msk)), mean(T.EpsNE(msk))];
            end
        end
    end

    fprintf('\n===== PASS checks =====\n');
    baselines = {'Isobe-APP', 'RQE', 'MF-RQE', 'CVaR-game', 'DRNE-VI'};
    for g = 1:numel(groups)
        gp = groups{g};
        % v1: Anneal 全面第一 + 双指标超 CVaR
        try
            an = get_agg(agg, 'concentrated', gp, 'Proposed-Anneal');
            ok = true;
            for b = 1:numel(baselines)
                bl = get_agg(agg, 'concentrated', gp, baselines{b});
                ok = ok && (an(3) > bl(3));
            end
            cv = get_agg(agg, 'concentrated', gp, 'CVaR-game');
            dual = (an(1) > cv(1)) && (an(2) > cv(2));
            verdict(sprintf('v1/%s: Anneal CE 超全部基线', gp), ok);
            verdict(sprintf('v1/%s: Anneal E,WC 双指标超 CVaR', gp), dual);
        catch; fprintf('[SKIP] v1/%s 数据不完整\n', gp); end
        % v2: Coherent >= CVaR - 1e-3 且超其余
        try
            co = get_agg(agg, 'dispersed', gp, 'Proposed-Coherent');
            cv = get_agg(agg, 'dispersed', gp, 'CVaR-game');
            ok = co(3) >= cv(3) - 1e-3;
            for b = 1:numel(baselines)
                if strcmp(baselines{b}, 'CVaR-game'); continue; end
                bl = get_agg(agg, 'dispersed', gp, baselines{b});
                ok = ok && (co(3) > bl(3));
            end
            verdict(sprintf('v2/%s: Coherent CE >= CVaR-1e-3 且超其余基线', gp), ok);
        catch; fprintf('[SKIP] v2/%s 数据不完整\n', gp); end
        % 证书: Anneal eps_ne < Base eps_ne
        try
            an = get_agg(agg, 'concentrated', gp, 'Proposed-Anneal');
            ba = get_agg(agg, 'concentrated', gp, 'Proposed-Base');
            verdict(sprintf('v1/%s: 退火事后证书更强 (eps_ne 降低)', gp), ...
                an(4) < ba(4));
        catch; end
        % v1 深退火 regime 工作点 (alpha=0.5, s=40): WC/CE 超全部基线,
        % E 超全部风险敏感基线 (Isobe=满仓 SC 角点, E 列数学不可达, 不计)
        try
            dp = get_agg(agg, 'concentrated', gp, 'Proposed-V1Deep');
            ok_wc_ce = true; ok_e = true;
            for b = 1:numel(baselines)
                bl = get_agg(agg, 'concentrated', gp, baselines{b});
                ok_wc_ce = ok_wc_ce && (dp(2) > bl(2)) && (dp(3) > bl(3));
                if ~strcmp(baselines{b}, 'Isobe-APP')
                    ok_e = ok_e && (dp(1) > bl(1));
                end
            end
            verdict(sprintf('v1/%s: V1Deep WC+CE 超全部基线', gp), ok_wc_ce);
            verdict(sprintf('v1/%s: V1Deep E 超全部风险敏感基线', gp), ok_e);
            an = get_agg(agg, 'concentrated', gp, 'Proposed-Anneal');
            verdict(sprintf('v1/%s: V1Deep 证书强于 4 段退火', gp), dp(4) < an(4));
        catch; fprintf('[SKIP] v1/%s V1Deep 数据不完整\n', gp); end
        % v2 深退火 regime 工作点 (alpha=0.05, s=0): E/WC/CE 全列严格超 CVaR,
        % WC/CE 超其余全部基线
        try
            dp = get_agg(agg, 'dispersed', gp, 'Proposed-V2Deep');
            cv = get_agg(agg, 'dispersed', gp, 'CVaR-game');
            ok_cv = (dp(1) > cv(1)) && (dp(2) > cv(2)) && (dp(3) > cv(3));
            ok_rest = true;
            for b = 1:numel(baselines)
                if strcmp(baselines{b}, 'CVaR-game'); continue; end
                bl = get_agg(agg, 'dispersed', gp, baselines{b});
                ok_rest = ok_rest && (dp(2) > bl(2)) && (dp(3) > bl(3));
            end
            verdict(sprintf('v2/%s: V2Deep E,WC,CE 全列严格超 CVaR', gp), ok_cv);
            verdict(sprintf('v2/%s: V2Deep WC+CE 超其余全部基线', gp), ok_rest);
        catch; fprintf('[SKIP] v2/%s V2Deep 数据不完整\n', gp); end
    end
end

function v = get_agg(agg, mode, group, method)
    v = agg.(matlab.lang.makeValidName(sprintf('%s_%s_%s', mode, group, method)));
end

function verdict(name, ok)
    if ok; tag = '[PASS]'; else; tag = '[FAIL]'; end
    fprintf('%s %s\n', tag, name);
end
