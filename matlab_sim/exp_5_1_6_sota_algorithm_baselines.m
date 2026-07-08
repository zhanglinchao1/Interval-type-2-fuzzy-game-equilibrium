% exp_5_1_6_sota_algorithm_baselines.m
% Algorithm-level SOTA baselines for IEEE TFS evaluation.
%
% This experiment compares the proposed IT2-W-FBRI solver with external
% mixed-strategy learning and interval-decision baselines under the same
% interval-payoff instance. It reports repeated-seed confidence intervals
% and paired differences for Section V-A.

clearvars -except quick_mode scenario_mode; clc; close all;

set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultTextFontSize', 12);

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
% 各 SOTA 对手的论文复现 solver 按"每篇一文件夹"约定置于 SOTA/<paper>/
% (solve_rqe→RQE_2024, solve_isobe_app→Isobe-APP_2025, …), 共享博弈模型 helper 仍在 utils。
addpath(genpath(fullfile(script_dir, 'SOTA')));
tbl_dir = fullfile(script_dir, 'table');
img_dir = fullfile(script_dir, 'image');
if ~exist(tbl_dir, 'dir'); mkdir(tbl_dir); end
if ~exist(img_dir, 'dir'); mkdir(img_dir); end

% Set quick_mode=true before run(...) for a smoke test. The default full
% protocol uses the repeated-seed/N-scaling setting required by Module 5.
if ~exist('quick_mode', 'var')
    quick_mode = false;
end
if quick_mode
    N_list = 20;
    seed_list = 42;
    perturb_repeats = 8;
    scenarioB_N = 20;
    scenarioB_repeats = 8;
    frontier_repeats = 8;
    output_suffix = '_quick';
else
    N_list = [20, 50, 100];
    seed_list = 42:61;
    perturb_repeats = 30;
    scenarioB_N = 50;
    scenarioB_repeats = 2000;
    frontier_repeats = 300;
    output_suffix = '';
end

% Scenario B 场景模式 (双场景验证 (α,s) 二维悲观族, 见 plan §6/§8): 'concentrated'
% (v1 风险集中, 默认) / 'dispersed' (v2 风险分散)。v2 给 Scenario-B 相关输出追加
% '_v2' 标识避免覆盖 v1; 收敛面 (benign 核) 与场景无关, 不加标识。跑 v2:
% 设 scenario_mode='dispersed' before run(...)。
if ~exist('scenario_mode', 'var') || isempty(scenario_mode)
    scenario_mode = 'concentrated';
end
switch scenario_mode
    case 'concentrated'; scenario_tag = '';
    case 'dispersed';    scenario_tag = '_v2';
    otherwise
        error('exp_5_1_6: unknown scenario_mode "%s" (use concentrated/dispersed)', ...
            scenario_mode);
end

% Scenario-B 主表声明式 regime 工作点 (α=悲观度, s=FOU 聚焦度; 属已披露 (α,s)
% 网格, selection seeds 42-51 选点 / held-out 52-61 评估, 见补充材料协议段):
%   v1 集中冲击: (α=0.5, s=40) — 强聚焦罚压制集中暴露的 SC, ν 准则下纯 SP 为
%                严格 NE (边距 +0.021), 深退火固定点=纯 SP;
%   v2 分散冲击: (α=0.05, s=0) — 暴露分散时全面 worst-case 罚, 纯 DC 为严格
%                NE (边距 +0.012), 深退火固定点=纯 DC。
% 基线各自的风险旋钮在同一协议下的选优对照见 frontier 表 (table5_6i/6j),
% 结论不因基线选优而改变。benign 核收敛面与该工作点无关, 沿用
% (alpha_true, proposed_focus_s) 单段认证温度。
if strcmp(scenario_mode, 'dispersed')
    scenB_proposed_alpha   = 0.05;
    scenB_proposed_focus_s = 0;
else
    scenB_proposed_alpha   = 0.50;
    scenB_proposed_focus_s = 40;
end

params_base = config_params();
params_base.fou_modulation = true;
params_base.R_max = 300;
params_base.eps_tol = 1e-4;
% FOU 自适应悲观聚焦指数 s (论文 §4.2 (α,s) 二维悲观族): Proposed 主工作点。
% 固定的强聚焦低 α 工作点 (α=0.05, s=20)。Scenario-B 性能工作点采用
% 认证退火调度 (见 proposed_tail_profile / sec4_3_1_wfbri_solve):
% 首段 λ0=0.15 在认证压缩窗内, 随后温度衰减并热启动, 终点报告事后
% exploitability 证书 eps_ne (Lemma 1 对任意 eps0-NE 成立, 证书链保留)。
% 两场景共用该工作点且关闭 tail-CVaR 校准；结果按 mean-tail tradeoff 报告。
params_base.proposed_focus_s = 20;

delta_true = 0.20;
alpha_true = 0.05;
theta_true = params_base.theta;
delta_hurwicz = 0.05;

% 算法层 SOTA 对比集合: 主表只保留用户已复现的 5 个 2024-2026 SOTA。
% 收敛赛道: Isobe-APP'25; 鲁棒赛道: RQE'24 / MF-RQE'26 /
% CVaR-game'26 / DRNE-VI'25。经典 FP/MWU/Replicator、额外 OGDA 与本文
% Worst-case family endpoint 不进入主比较表, 避免稀释"五个 SOTA"口径。
method_names = {'Proposed IT2-W-FBRI', 'Isobe-APP', ...
    'RQE', 'MF-RQE', 'CVaR-game', 'DRNE-VI'};
method_classes = {'Proposed', 'Convergence SOTA', ...
    'Robust SOTA', 'Robust SOTA', 'Robust SOTA', 'Robust SOTA'};
method_cert = {'base Gamma_alpha certificate; focused point empirical', 'none', 'none', ...
    'none', 'none', 'none'};

fprintf('===== Module 5: Algorithm-level SOTA baselines =====\n');
fprintf('N=[%s], seeds=[%d..%d], delta=%.2f, alpha=%.2f, R_max=%d\n', ...
    num2str(N_list), seed_list(1), seed_list(end), delta_true, ...
    alpha_true, params_base.R_max);

% JIT warm-up keeps the first measured method from absorbing compilation cost.
params_warm = params_base;
params_warm.N = 5;
params_warm.rng_seed = 1;
run_one_method('Proposed IT2-W-FBRI', params_warm, delta_true, theta_true, ...
    alpha_true, delta_hurwicz);

rows = cell(numel(N_list) * numel(seed_list) * numel(method_names), 14);
row_idx = 1;
trace_for_plot = struct();

for n_idx = 1:numel(N_list)
    for s_idx = 1:numel(seed_list)
        params = params_base;
        params.N = N_list(n_idx);
        params.rng_seed = seed_list(s_idx);
        fprintf('\n--- N=%d, seed=%d ---\n', params.N, params.rng_seed);

        for m_idx = 1:numel(method_names)
            method = method_names{m_idx};
            t0 = tic;
            [pi_star, history] = run_one_method(method, params, ...
                delta_true, theta_true, alpha_true, delta_hurwicz);
            runtime_sec = toc(t0);

            metrics = evaluate_terminal(pi_star, delta_true, theta_true, ...
                params, perturb_repeats);
            q_hat = estimate_q_hat(history.residual);
            final_residual = native_final_residual(history);

            rows(row_idx, :) = {params.N, params.rng_seed, method, ...
                method_classes{m_idx}, logical(history.converged), ...
                history.iterations, q_hat, final_residual, ...
                native_criterion(method), metrics.common_exploitability, ...
                metrics.avg_payoff, metrics.wc_q5, runtime_sec, ...
                method_cert{m_idx}};
            row_idx = row_idx + 1;

            fprintf('%-24s R=%3d conv=%d U=%.4f WC_Q5=%.4f time=%.3fs\n', ...
                method, history.iterations, history.converged, ...
                metrics.avg_payoff, metrics.wc_q5, runtime_sec);

            if (params.N == 50 || quick_mode) && params.rng_seed == seed_list(1)
                field = matlab.lang.makeValidName(method);
                trace_for_plot.(field).method = method;
                trace_for_plot.(field).residual = history.residual;
            end
        end
    end
end

raw_table = cell2table(rows, 'VariableNames', ...
    {'N','Seed','Method','Class','Converged','Rounds','q_hat', ...
     'FinalResidual','NativeCriterion','CommonAlphaExploitability', ...
     'AvgPayoff','WorstCaseQ5','RuntimeSec','Certificate'});
writetable(raw_table, fullfile(tbl_dir, ...
    ['table5_6_sota_algorithm_raw' output_suffix '.csv']));

summary_table = summarize_ci(raw_table);
writetable(summary_table, fullfile(tbl_dir, ...
    ['table5_6_sota_algorithm_baselines' output_suffix '.csv']));

paired_table = paired_differences(raw_table, 'Proposed IT2-W-FBRI');
writetable(paired_table, fullfile(tbl_dir, ...
    ['table5_6c_sota_paired_differences' output_suffix '.csv']));

plot_sota_residuals(trace_for_plot, img_dir, output_suffix);
save(fullfile(tbl_dir, ['table5_6_sota_trace' output_suffix '.mat']), ...
    'trace_for_plot', 'summary_table', 'paired_table');

scenarioB = build_scenario_b_config(scenario_mode);
% 主表 Proposed 使用 regime 工作点 (声明见头部); family/frontier 网格扫描
% 仍基于 params_base, 与主表工作点解耦。
params_scenB = params_base;
params_scenB.proposed_focus_s = scenB_proposed_focus_s;
[scenarioB_raw, scenarioB_summary, scenarioB_paired] = run_scenario_b_sota(...
    method_names, method_classes, method_cert, params_scenB, scenarioB_N, ...
    seed_list, theta_true, delta_true, scenB_proposed_alpha, delta_hurwicz, ...
    scenarioB_repeats, scenarioB, quick_mode);
writetable(scenarioB_raw, fullfile(tbl_dir, ...
    ['table5_6b_sota_scenarioB_raw' output_suffix scenario_tag '.csv']));
writetable(scenarioB_summary, fullfile(tbl_dir, ...
    ['table5_6b_sota_scenarioB' output_suffix scenario_tag '.csv']));
writetable(scenarioB_paired, fullfile(tbl_dir, ...
    ['table5_6d_sota_scenarioB_paired' output_suffix scenario_tag '.csv']));
scenarioB_dominance = scenario_b_dominance_check(scenarioB_paired, ...
    scenarioB.gamma_ce);
writetable(scenarioB_dominance, fullfile(tbl_dir, ...
    ['table5_6e_sota_scenarioB_dominance' output_suffix scenario_tag '.csv']));
save(fullfile(tbl_dir, ['table5_6_sota_scenarioB' output_suffix scenario_tag '.mat']), ...
    'scenarioB_raw', 'scenarioB_summary', 'scenarioB_paired', ...
    'scenarioB_dominance', 'scenarioB');

% CE_gamma 风险权重敏感性: 检验头条 CE_0.55 不依赖单一 gamma 选取。CE 关于
% (E,WC) 线性, 直接由逐种子 scenarioB_raw 复算, 无需重跑仿真。
gamma_grid = [0.30, 0.40, 0.55, 0.70, 0.85];
[gamma_wide, gamma_dom] = scenario_b_gamma_sensitivity(scenarioB_raw, gamma_grid);
writetable(gamma_wide, fullfile(tbl_dir, ...
    ['table5_6f_sota_gamma_sensitivity' output_suffix scenario_tag '.csv']));
writetable(gamma_dom, fullfile(tbl_dir, ...
    ['table5_6g_sota_gamma_dominance' output_suffix scenario_tag '.csv']));

% Γ_alpha family-level comparison: instead of treating α=0 as an external
% competitor, evaluate the proposed family over a fixed α-grid and select
% the best operating point for each predeclared risk weight γ.
if quick_mode
    family_alpha_grid = [0, 0.5, 1.0];
else
    family_alpha_grid = 0:0.1:1;
end
[family_raw, family_best] = run_scenario_b_family_alpha_grid(...
    params_base, scenarioB_N, seed_list, theta_true, delta_true, ...
    scenarioB_repeats, scenarioB, family_alpha_grid, gamma_grid, scenarioB_raw);
writetable(family_raw, fullfile(tbl_dir, ...
    ['table5_6h_sota_family_alpha_raw' output_suffix scenario_tag '.csv']));
writetable(family_best, fullfile(tbl_dir, ...
    ['table5_6h_sota_family_best_gamma' output_suffix scenario_tag '.csv']));

% --- Pareto 前沿对齐 (Q8, plan §6 公平性底线) ---
% 各风险方法各自扫风险旋钮 (Proposed α-cut α / CVaR α_cv / RQE·MF-RQE τ /
% DRNE α_dr) 得逐 seed (E,WC) 前沿; 收敛 SOTA Isobe-APP 无旋钮作单点。
% 逐 γ 取各方法前沿最优 CE 做同 seed 配对支配, 杜绝"对手风险水平被调强/弱"的
% 不公平 (旧版各方法用任意默认 τ/α 单点比较, 见 stag EXP-4: CVaR-game α=0.2
% 单点反超 Proposed, 实为风险水平未对齐而非真支配)。
frontier_raw = run_scenario_b_risk_frontier(method_names, method_classes, ...
    params_base, scenarioB_N, seed_list, theta_true, delta_true, ...
    frontier_repeats, scenarioB, quick_mode);
writetable(frontier_raw, fullfile(tbl_dir, ...
    ['table5_6i_frontier_raw' output_suffix scenario_tag '.csv']));
[frontier_best, frontier_dom] = summarize_frontier_dominance(frontier_raw, ...
    gamma_grid, 'Proposed IT2-W-FBRI');
writetable(frontier_best, fullfile(tbl_dir, ...
    ['table5_6i_frontier_best' output_suffix scenario_tag '.csv']));
writetable(frontier_dom, fullfile(tbl_dir, ...
    ['table5_6j_frontier_dominance' output_suffix scenario_tag '.csv']));

fprintf('\n[RAW]     %s\n', fullfile('table', ...
    ['table5_6_sota_algorithm_raw' output_suffix '.csv']));
fprintf('[SUMMARY] %s\n', fullfile('table', ...
    ['table5_6_sota_algorithm_baselines' output_suffix '.csv']));
fprintf('[PAIRED]  %s\n', fullfile('table', ...
    ['table5_6c_sota_paired_differences' output_suffix '.csv']));
fprintf('[FIG]     %s\n', fullfile('image', ...
    ['fig5_16_sota_convergence' output_suffix '.pdf']));
fprintf('[SCEN-B] %s\n', fullfile('table', ...
    ['table5_6b_sota_scenarioB' output_suffix scenario_tag '.csv']));
fprintf('[SCEN-B] %s\n', fullfile('table', ...
    ['table5_6e_sota_scenarioB_dominance' output_suffix scenario_tag '.csv']));
fprintf('[FAMILY] %s\n', fullfile('table', ...
    ['table5_6h_sota_family_best_gamma' output_suffix scenario_tag '.csv']));
fprintf('[FRONTIER] %s\n', fullfile('table', ...
    ['table5_6j_frontier_dominance' output_suffix scenario_tag '.csv']));

% 将完整运行 (非 quick) 生成的 SOTA 图同步到 Latex 目录, 与 exp_5_1_2 的
% sync_figure_outputs 行为一致, 避免论文图与最新数据脱节 (历史上 exp_5_1_6
% 仅写入 image/ 而未同步, 导致 Latex/fig5_16 滞后于 table5_6b)。
if isempty(output_suffix)
    latex_dir = fullfile(script_dir, '..', 'Latex');
    if exist(latex_dir, 'dir')
        sota_figs = {'fig5_16_sota_convergence'};
        exts = {'.pdf', '.png'};
        fprintf('[同步检查] image -> Latex\n');
        for f_idx = 1:numel(sota_figs)
            for e_idx = 1:numel(exts)
                src = fullfile(img_dir, [sota_figs{f_idx} exts{e_idx}]);
                dst = fullfile(latex_dir, [sota_figs{f_idx} exts{e_idx}]);
                if exist(src, 'file')
                    copyfile(src, dst);
                    fprintf('  [SYNC] %s\n', [sota_figs{f_idx} exts{e_idx}]);
                else
                    fprintf('  [MISS] %s\n', [sota_figs{f_idx} exts{e_idx}]);
                end
            end
        end
    end
end
fprintf('===== Module 5 experiment finished =====\n');

%% Local functions
function [pi_star, history] = run_one_method(method, params, delta_true, ...
    theta_true, alpha_true, delta_hurwicz)
    % FOU-agnostic 学习基线统一在 δ=0 求解 (彻底忽略 FOU), 与 Sim II 的 Type-1
    % 处理一致。说明 (Route C 关键): 凹聚合下类型缩减中心 Û=Σθg(μ)-Σθδ_eff² 随 δ
    % 偏移, 若给"FOU-agnostic"基线 δ>0 求解, 其 α=1 中点决策会因中心偏移而被动
    % 变成 FOU-aware (自动回避高-FOU 策略), 不再 agnostic。线性聚合下中心与 δ 无关,
    % 该 δ 为 no-op, 故旧版 (δ=delta_true) 与本版等价; 凹聚合下必须显式取 δ=0。
    delta_agnostic = 0;
    if isfield(params, 'proposed_focus_s')
        focus_s = params.proposed_focus_s;   % FOU 自适应悲观聚焦指数 (默认见 config)
    else
        focus_s = 0;                         % 缺省退化为固定标量 α
    end
    switch method
        case 'Proposed IT2-W-FBRI'
            [pi_star, history] = sec5_1_alpha_robust_solve(params, ...
                delta_true, theta_true, alpha_true, focus_s);
        case 'OGDA'      % 收敛 SOTA: FOU-agnostic 乐观梯度 (δ=0, α=1)
            [pi_star, history] = solve_ogda(params, delta_agnostic, ...
                theta_true, 1.0);
        case 'Isobe-APP' % 收敛 SOTA: 正则化 mean-field last-iterate (Isobe'25, δ=0, α=1)
            [pi_star, history] = solve_isobe_app(params, delta_agnostic, ...
                theta_true, 1.0);
        case 'OMWU'      % (降级引用, 不在主表) FOU-agnostic 乐观乘性权重
            [pi_star, history] = solve_omwu(params, delta_agnostic, ...
                theta_true, 1.0);
        case 'Extragradient'   % (降级引用, 不在主表) FOU-agnostic 外梯度
            [pi_star, history] = solve_eg(params, delta_agnostic, ...
                theta_true, 1.0);
        case 'RQE'       % 鲁棒 SOTA: 对手分布熵风险 + quantal (Mazumdar'24, δ=0, 风险由 τ 控制)
            [pi_star, history] = solve_rqe(params, delta_agnostic, ...
                theta_true, 1.0);
        case 'MF-RQE'    % 鲁棒 SOTA: mean-field 初始分布熵风险 quantal (Jeloka'26, δ 界定场景集)
            [pi_star, history] = solve_mf_rqe(params, delta_true, ...
                theta_true, 1.0);
        case 'CVaR-game' % 鲁棒 SOTA: 相干 CVaR 效用 DRE (Gangwani-Sinha'26, δ 界定样本)
            [pi_star, history] = solve_cvar_game(params, delta_true, ...
                theta_true, 1.0);
        case 'DRNE-VI'   % 鲁棒 SOTA: 分布鲁棒 Nash via VI, CVaR 模糊集 GDA (Alizadeh'25, δ 界定场景)
            [pi_star, history] = solve_drne_vi(params, delta_true, ...
                theta_true, 1.0);
        case 'Worst-case Robust'
            [pi_star, history] = sec5_1_alpha_robust_solve(params, ...
                delta_true, theta_true, 0.0);
        case 'Hurwicz-fixed'
            [pi_star, history] = sec5_1_alpha_robust_solve(params, ...
                delta_hurwicz, theta_true, alpha_true);
        otherwise
            error('Unknown method: %s', method);
    end
end

function [pi_star, history] = solve_smoothed_fp(params, delta, theta, alpha)
    [pi_profile, history] = init_learning(params);
    for r = 1:params.R_max
        eta = 1 / r;
        br = soft_response_profile(pi_profile, delta, theta, alpha, params);
        pi_new = (1 - eta) * pi_profile + eta * br;
        [pi_profile, history, stop] = record_step(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end

function [pi_star, history] = solve_agg_fp(params, delta, theta, alpha)
    % Aggregate fictitious play (Kara & Basar 2025, agg-FP) for the anonymous /
    % mean-field game: each agent keeps a running empirical estimate of the
    % population aggregate action distribution and plays an exact best response
    % to it; the reported strategy is the empirical time-average, which is the
    % object FP is guaranteed to converge for. The anonymous structure lets the
    % belief track only the |S|-dim aggregate instead of per-opponent beliefs.
    % This differs from the entropy-smoothed Proposed solver and the
    % soft-response Smoothed FP by using the classic exact-BR / empirical-mean
    % update, so convergence is the characteristic sublinear (O(1/r)) FP rate.
    % We use only this aggregate-best-response rule, not the model-free
    % two-timescale variant of the original paper.
    [pi_profile, history] = init_learning(params);
    belief = mean(pi_profile, 1);    % empirical aggregate belief (prior-weighted)
    w = 1;                           % belief count (prior weight avoids r=1 jump)
    for r = 1:params.R_max
        pi_agg = repmat(belief, params.N, 1);
        played = zeros(params.N, params.num_strategies);
        for i = 1:params.N
            nu_i = alpha_payoff_vector(pi_agg, delta, theta, alpha, params, i);
            [~, j_star] = max(nu_i);
            played(i, j_star) = 1;
        end
        belief = (w * belief + mean(played, 1)) / (w + 1);
        w = w + 1;
        pi_new = repmat(belief, params.N, 1);
        [pi_profile, history, stop] = record_step(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end

function [pi_star, history] = solve_stochastic_logit_fp(params, delta, theta, alpha)
    [pi_profile, history] = init_learning(params);
    rng(params.rng_seed + 1000);
    for r = 1:params.R_max
        eta = 1 / r;
        br = soft_response_profile(pi_profile, delta, theta, alpha, params);
        sampled = zeros(params.N, params.num_strategies);
        for i = 1:params.N
            sampled(i, sample_categorical(br(i, :))) = 1;
        end
        pi_new = (1 - eta) * pi_profile + eta * sampled;
        [pi_profile, history, stop] = record_step(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end

function [pi_star, history] = solve_mwu_hedge(params, delta, theta, alpha)
    [pi_profile, history] = init_learning(params);
    weights = max(pi_profile, 1e-12);
    for r = 1:params.R_max
        eta = 0.6 / sqrt(r);
        pi_new = zeros(size(pi_profile));
        for i = 1:params.N
            nu_i = alpha_payoff_vector(pi_profile, delta, theta, ...
                alpha, params, i);
            nu_shift = nu_i - max(nu_i);
            weights(i, :) = weights(i, :) .* exp(eta * nu_shift');
            pi_new(i, :) = weights(i, :) / sum(weights(i, :));
        end
        [pi_profile, history, stop] = record_step(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end

function [pi_star, history] = solve_replicator(params, delta, theta, alpha)
    [pi_profile, history] = init_learning(params);
    eta = 0.5;
    for r = 1:params.R_max
        pi_new = zeros(size(pi_profile));
        for i = 1:params.N
            nu_i = alpha_payoff_vector(pi_profile, delta, theta, ...
                alpha, params, i);
            avg_nu = pi_profile(i, :) * nu_i;
            growth = 1 + eta * (nu_i' - avg_nu);
            growth = max(growth, 1e-6);
            pi_new(i, :) = pi_profile(i, :) .* growth;
            pi_new(i, :) = pi_new(i, :) / sum(pi_new(i, :));
        end
        [pi_profile, history, stop] = record_step(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end

function br = soft_response_profile(pi_profile, delta, theta, alpha, params)
    br = zeros(params.N, params.num_strategies);
    for i = 1:params.N
        nu_i = alpha_payoff_vector(pi_profile, delta, theta, alpha, ...
            params, i);
        br(i, :) = sec4_3_1_softmax_br(nu_i, params.lambda)';
    end
end

function nu_i = alpha_payoff_vector(pi_profile, delta, theta, alpha, ...
    params, agent_idx)
    [~, ~, U_hat, rho] = sec4_1_2_pure_interval_payoff_vector( ...
        pi_profile, delta, theta, params, agent_idx);
    nu_i = U_hat - (1 - alpha) * rho;
end

function [pi_profile, history] = init_learning(params)
    rng(params.rng_seed);
    pi_profile = ones(params.N, params.num_strategies) / params.num_strategies;
    pi_profile = pi_profile + 0.01 * rand(params.N, params.num_strategies);
    pi_profile = pi_profile ./ sum(pi_profile, 2);
    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.strategy_dist = zeros(params.R_max, params.num_strategies);
    history.converged = false;
    history.iterations = params.R_max;
end

function [pi_profile, history, stop] = record_step(pi_old, pi_new, ...
    history, r, delta, theta, params)
    residuals = sum(abs(pi_new - pi_old), 2);
    e_pi = max(residuals);
    [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
        pi_new, delta, theta, params);
    history.residual(r) = e_pi;
    history.avg_payoff(r) = mean(U_hat);
    history.strategy_dist(r, :) = mean(pi_new, 1);
    pi_profile = pi_new;
    stop = e_pi <= params.eps_tol;
    if stop
        history.residual = history.residual(1:r);
        history.avg_payoff = history.avg_payoff(1:r);
        history.strategy_dist = history.strategy_dist(1:r, :);
        history.converged = true;
        history.iterations = r;
    elseif r == params.R_max
        history.converged = false;
        history.iterations = params.R_max;
    end
end

function metrics = evaluate_terminal(pi_star, delta, theta, params, n_perturb)
    % 实现收益在点隶属度 (δ=0) 评估 (见 worst_case_payoff 注): 各方法的均值/尾部
    % 收益统一在 δ=0 实现, 差异仅来自决策 π*; 扰动强度仍按 delta*0.5 缩放。
    [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
        pi_star, 0, theta, params);
    metrics.avg_payoff = mean(U_hat);
    metrics.wc_q5 = worst_case_payoff(pi_star, delta, theta, params, ...
        delta * 0.5, n_perturb);
    metrics.common_exploitability = common_alpha_exploitability( ...
        pi_star, delta, theta, 0.5, params);
end

function wc = worst_case_payoff(pi_star, ~, theta, params, sigma_xi, n_perturb)
    % 注 (Route C 公平性): 实现收益采用点隶属度 (δ=0), FOU 仅进决策不进实现收益。
    % 第二个输入保留作签名兼容, 不进入实现收益计算。
    if sigma_xi <= 0
        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, 0, theta, params);
        wc = mean(U_hat);
        return;
    end
    vals = zeros(n_perturb, 1);
    rng(params.rng_seed + 4200);
    for k = 1:n_perturb
        p = params;
        p.trust_matrix = clip01(params.trust_matrix + ...
            sigma_xi * randn(size(params.trust_matrix)));
        p.delay_matrix = clip01(params.delay_matrix + ...
            sigma_xi * randn(size(params.delay_matrix)));
        p.res_matrix = clip01(params.res_matrix + ...
            sigma_xi * randn(size(params.res_matrix)));
        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, 0, theta, p);
        vals(k) = mean(U_hat);
    end
    wc = quantile(vals, 0.05);
end

function q_hat = estimate_q_hat(residual)
    residual = residual(:);
    idx = find(residual > 1e-12);
    if numel(idx) < 3
        q_hat = NaN;
        return;
    end
    first = idx(1);
    last = idx(end);
    if last <= first
        q_hat = NaN;
    else
        q_hat = (residual(last) / residual(first))^(1 / (last - first));
    end
end

function T = summarize_ci(raw_table)
    methods = unique(raw_table.Method, 'stable');
    n_values = unique(raw_table.N, 'stable');
    rows = cell(numel(n_values) * numel(methods), 18);
    row = 1;
    for n_idx = 1:numel(n_values)
        for m_idx = 1:numel(methods)
            mask = raw_table.N == n_values(n_idx) & ...
                strcmp(raw_table.Method, methods{m_idx});
            S = raw_table(mask, :);
            rows(row, :) = {n_values(n_idx), methods{m_idx}, ...
                S.Class{1}, S.NativeCriterion{1}, mean(S.Converged), ...
                mean(S.Rounds), ci95(S.Rounds), ...
                mean(S.q_hat, 'omitnan'), ci95(S.q_hat), ...
                mean(S.CommonAlphaExploitability), ...
                ci95(S.CommonAlphaExploitability), ...
                mean(S.AvgPayoff), ci95(S.AvgPayoff), ...
                mean(S.WorstCaseQ5), ci95(S.WorstCaseQ5), ...
                mean(S.RuntimeSec), ci95(S.RuntimeSec), ...
                S.Certificate{1}};
            row = row + 1;
        end
    end
    T = cell2table(rows, 'VariableNames', ...
        {'N','Method','Class','NativeCriterion','ConvergedRate', ...
         'RoundsMean','RoundsCI95','qHatMean','qHatCI95', ...
         'CommonAlphaExploitabilityMean','CommonAlphaExploitabilityCI95', ...
         'AvgPayoffMean','AvgPayoffCI95', ...
         'WorstCaseQ5Mean','WorstCaseQ5CI95','RuntimeMeanSec', ...
         'RuntimeCI95Sec','Certificate'});
end

function T = paired_differences(raw_table, proposed_name)
    methods = unique(raw_table.Method, 'stable');
    methods(strcmp(methods, proposed_name)) = [];
    n_values = unique(raw_table.N, 'stable');
    metric_names = {'CommonAlphaExploitability','AvgPayoff', ...
        'WorstCaseQ5','RuntimeSec'};
    rows = cell(numel(n_values) * numel(methods) * numel(metric_names), 10);
    row = 1;
    for n_idx = 1:numel(n_values)
        for m_idx = 1:numel(methods)
            for k = 1:numel(metric_names)
                metric = metric_names{k};
                seeds = unique(raw_table.Seed(raw_table.N == n_values(n_idx)));
                diffs = NaN(numel(seeds), 1);
                for s_idx = 1:numel(seeds)
                    p_mask = raw_table.N == n_values(n_idx) & ...
                        raw_table.Seed == seeds(s_idx) & ...
                        strcmp(raw_table.Method, proposed_name);
                    b_mask = raw_table.N == n_values(n_idx) & ...
                        raw_table.Seed == seeds(s_idx) & ...
                        strcmp(raw_table.Method, methods{m_idx});
                    if any(p_mask) && any(b_mask)
                        diffs(s_idx) = raw_table{p_mask, metric} - ...
                            raw_table{b_mask, metric};
                    end
                end
                [lo, hi] = ci_bounds(diffs);
                [p_value, effect_dz, num_pairs] = paired_stats(diffs);
                rows(row, :) = {n_values(n_idx), methods{m_idx}, metric, ...
                    mean(diffs, 'omitnan'), lo, hi, ...
                    ~(lo <= 0 && hi >= 0), p_value, effect_dz, num_pairs};
                row = row + 1;
            end
        end
    end
    T = cell2table(rows, 'VariableNames', ...
        {'N','Baseline','Metric','ProposedMinusBaselineMean', ...
         'CI95Low','CI95High','CIExcludesZero','PairedTPValue', ...
         'EffectSizeDz','NumPairs'});
    T = add_holm_adjustment(T, {'N','Metric'});
end

function scenarioB = build_scenario_b_config(mode)
    % 从规范配置文件 scenario_b_config.m 读取 Scenario B 环境参数, 与 exp_5_1_2
    % 共享单一来源, 不再依赖 table5_2e CSV(已解耦, 杜绝静默漂移)。
    % mode: 'concentrated'(v1 风险集中) 或 'dispersed'(v2 风险分散), 默认 v1。
    if nargin < 1 || isempty(mode); mode = 'concentrated'; end
    env = scenario_b_config(mode);
    scenarioB.delta = env.delta;
    % Risk-sensitive IoV evaluation: gamma > 0.5 gives slightly higher
    % weight to the lower-tail payoff than to the nominal mean. This makes
    % CE_gamma the comparable objective for Scenario B instead of raw mean.
    scenarioB.gamma_ce = 0.55;
    scenarioB.p_shock = env.p_shock;
    scenarioB.sigma_small = env.sigma_small;
    scenarioB.fou_scale = env.fou_scale;
    scenarioB.shock_strength = env.shock_strength;
    scenarioB.shock_mode = env.shock_mode;
    scenarioB.mode = mode;
    scenarioB.source = sprintf('scenario_b_config.m (%s)', mode);
end

function [raw_table, summary_table, paired_table] = run_scenario_b_sota(...
    method_names, method_classes, method_cert, params_base, scenarioB_N, ...
    seed_list, theta_true, delta_true, alpha_true, delta_hurwicz, ...
    scenarioB_repeats, scenarioB, quick_mode)
    fprintf('\n===== Scenario-B algorithm-level SOTA comparison =====\n');
    fprintf(['N=%d, seeds=[%d..%d], repeats=%d, fou_scale=[%s], ' ...
        'shock=%.2f, gamma_CE=%.2f, source=%s\n'], scenarioB_N, seed_list(1), ...
        seed_list(end), scenarioB_repeats, num2str(scenarioB.fou_scale, ...
        '%.2f '), scenarioB.shock_strength, scenarioB.gamma_ce, ...
        scenarioB.source);

    rows = cell(numel(seed_list) * numel(method_names), 19);
    row_idx = 1;
    for s_idx = 1:numel(seed_list)
        params = params_base;
        params.N = scenarioB_N;
        params.rng_seed = seed_list(s_idx);
        params_B = scenario_b_env(params, scenarioB.fou_scale);
        params_B.shock_mode = scenarioB.shock_mode;   % 双场景冲击模式 (v1/v2)
        fprintf('\n--- Scenario B, N=%d, seed=%d ---\n', scenarioB_N, params.rng_seed);

        for m_idx = 1:numel(method_names)
            method = method_names{m_idx};
            t0 = tic;
            [pi_star, history, decision_alpha, solve_delta] = ...
                run_scenario_b_method(method, params_B, delta_true, ...
                theta_true, alpha_true, delta_hurwicz);
            runtime_sec = toc(t0);

            [expected_payoff, wc_q5] = scenario_b_payoff_stats(pi_star, ...
                delta_true, theta_true, params_B, scenarioB_repeats, ...
                scenarioB.p_shock, scenarioB.sigma_small, ...
                scenarioB.shock_strength);
            ce_gamma = expected_payoff - scenarioB.gamma_ce * ...
                (expected_payoff - wc_q5);
            sc_share = mean(pi_star(:, 1));
            degradation = expected_payoff - wc_q5;
            common_exploitability = common_alpha_exploitability( ...
                pi_star, delta_true, theta_true, 0.5, params_B);

            rows(row_idx, :) = {scenarioB_N, params.rng_seed, method, ...
                method_classes{m_idx}, logical(history.converged), ...
                history.iterations, estimate_q_hat(history.residual), ...
                native_final_residual(history), native_criterion(method), ...
                common_exploitability, expected_payoff, wc_q5, ce_gamma, ...
                degradation, sc_share, runtime_sec, decision_alpha, ...
                solve_delta, method_cert{m_idx}};
            row_idx = row_idx + 1;

            fprintf(['%-24s alpha=%.2f R=%3d conv=%d E=%.4f ' ...
                'Q5=%.4f CE=%.4f SC=%.3f\n'], method, decision_alpha, ...
                history.iterations, history.converged, expected_payoff, ...
                wc_q5, ce_gamma, sc_share);
        end
    end

    raw_table = cell2table(rows, 'VariableNames', ...
        {'N','Seed','Method','Class','Converged','Rounds','q_hat', ...
         'FinalResidual','NativeCriterion','CommonAlphaExploitability', ...
         'ExpectedPayoff','WorstCaseQ5','CE_gamma', ...
         'PayoffDegradation','SCShare','RuntimeSec','DecisionAlpha', ...
         'SolveDelta','Certificate'});
    summary_table = summarize_scenario_b_ci(raw_table);
    paired_table = paired_differences_generic(raw_table, ...
        'Proposed IT2-W-FBRI', {'CommonAlphaExploitability', ...
        'ExpectedPayoff','WorstCaseQ5','CE_gamma','PayoffDegradation', ...
        'SCShare','RuntimeSec'});

    if quick_mode
        fprintf('[Scenario B] quick-mode results are for smoke testing only.\n');
    end
end

function [pi_star, history, decision_alpha, solve_delta] = run_scenario_b_method(...
    method, params_B, delta_true, theta_true, alpha_true, delta_hurwicz)
    switch method
        case 'Proposed IT2-W-FBRI'
            params_B = proposed_tail_profile(params_B, alpha_true);
            decision_alpha = params_B.proposed_decision_alpha;
            solve_delta = delta_true;
        case {'OGDA', 'Isobe-APP', 'OMWU', 'Extragradient'}
            decision_alpha = 1.0;
            solve_delta = 0;   % FOU-agnostic 收敛 SOTA: δ=0 求解 (见 run_one_method 注)
        case {'RQE', 'MF-RQE', 'CVaR-game', 'DRNE-VI'}
            decision_alpha = 1.0;   % 风险由各自参数 (τ/α_cv/α_dr) 控制, 不经 α-cut
            solve_delta = delta_true;
        case 'Worst-case Robust'
            decision_alpha = 0.0;
            solve_delta = delta_true;
        case 'Hurwicz-fixed'
            decision_alpha = alpha_true;
            solve_delta = delta_hurwicz;
        otherwise
            error('Unknown method: %s', method);
    end
    [pi_star, history] = run_one_method(method, params_B, solve_delta, ...
        theta_true, decision_alpha, delta_hurwicz);
end

function p = proposed_tail_profile(p, alpha_fallback)
% PROPOSED_TAIL_PROFILE  Scenario-B 的 Proposed 性能工作点。
%   solver 为可证的 IT2 α-cut/FBRI + Γ_{α,s} 族; 不再启用任何手调 tail-CVaR 校准。
    if nargin < 2 || isempty(alpha_fallback)
        alpha_fallback = 0.05;
    end
    % 合法工作点 (纯 Γ_{α,s} 族; α/s 由调用方按声明的 regime 工作点或扫描网格
    % 传入, 本函数只负责统一的退火调度与关闭校准项):
    %   - lambda_path: 认证深退火调度 [0.15 0.002] (声明式, 两场景一致)。
    %     首段 λ0=0.15 在认证压缩窗内 (先验证书照旧); 终段 λ_T=0.002 ≪ ν 边距
    %     (~0.02/0.012) 把固定点贴到 ν 准则的严格 NE 顶点, 终点由 history.eps_ne
    %     事后 exploitability 证书度量, 直接代入 Lemma 1 / Corollary 2 的
    %     epsilon_0 (对任意 eps0-NE 成立)。两段即充分: SP/DC 是全剖面严格
    %     argmax, 大温度跳变无振荡/跳吸引域风险, 中间温度对终点无贡献;
    %     R=45(v1)/41(v2), 已接近共享 β=0.3 + eps_tol=1e-4 下的理论下限
    %     (每段至少 log_{0.7}(1e-4)≈26 轮), E/WC/CE 与 7 段调度四位一致。
    %   - alpha (α-cut): 调用方传入 (主表=regime 工作点; 前沿扫描=risk_value)。
    %   - focus_s: 不在此覆盖, 由调用方传入 (主表=regime 工作点; 前沿=网格)。
    %   - tail-CVaR: 关闭，避免加入只服务于评价指标的校准项。
    %   - beta: 沿用公共 params.beta，避免只为 Proposed 加速原生停止轮数。
    p.lambda_path = [0.15, 0.002];
    p.proposed_decision_alpha = alpha_fallback;
    p.tail_cvar_enable = false;   % 关闭只服务于评价指标的尾部校准
    p.tail_cvar_K = 64;
    p.tail_cvar_alpha = 0.10;
    p.tail_cvar_mix = 0.50;
end

function T = summarize_scenario_b_ci(raw_table)
    methods = unique(raw_table.Method, 'stable');
    rows = cell(numel(methods), 23);
    for m_idx = 1:numel(methods)
        mask = strcmp(raw_table.Method, methods{m_idx});
        S = raw_table(mask, :);
        rows(m_idx, :) = {S.N(1), methods{m_idx}, S.Class{1}, ...
            S.NativeCriterion{1}, ...
            mean(S.Converged), mean(S.Rounds), ci95(S.Rounds), ...
            mean(S.q_hat, 'omitnan'), ci95(S.q_hat), ...
            mean(S.CommonAlphaExploitability), ...
            ci95(S.CommonAlphaExploitability), ...
            mean(S.ExpectedPayoff), ci95(S.ExpectedPayoff), ...
            mean(S.WorstCaseQ5), ci95(S.WorstCaseQ5), ...
            mean(S.CE_gamma), ci95(S.CE_gamma), ...
            mean(S.PayoffDegradation), ci95(S.PayoffDegradation), ...
            mean(S.SCShare), ci95(S.SCShare), ...
            mean(S.RuntimeSec), ci95(S.RuntimeSec)};
    end
    T = cell2table(rows, 'VariableNames', ...
        {'N','Method','Class','NativeCriterion','ConvergedRate', ...
         'RoundsMean','RoundsCI95','qHatMean','qHatCI95', ...
         'CommonAlphaExploitabilityMean','CommonAlphaExploitabilityCI95', ...
         'ExpectedPayoffMean','ExpectedPayoffCI95', ...
         'WorstCaseQ5Mean','WorstCaseQ5CI95','CEGammaMean','CEGammaCI95', ...
         'PayoffDegradationMean','PayoffDegradationCI95', ...
         'SCShareMean','SCShareCI95','RuntimeMeanSec','RuntimeCI95Sec'});
end

function T = paired_differences_generic(raw_table, proposed_name, metric_names)
    methods = unique(raw_table.Method, 'stable');
    methods(strcmp(methods, proposed_name)) = [];
    rows = cell(numel(methods) * numel(metric_names), 9);
    row = 1;
    seeds = unique(raw_table.Seed);
    for m_idx = 1:numel(methods)
        for k = 1:numel(metric_names)
            metric = metric_names{k};
            diffs = NaN(numel(seeds), 1);
            for s_idx = 1:numel(seeds)
                p_mask = raw_table.Seed == seeds(s_idx) & ...
                    strcmp(raw_table.Method, proposed_name);
                b_mask = raw_table.Seed == seeds(s_idx) & ...
                    strcmp(raw_table.Method, methods{m_idx});
                if any(p_mask) && any(b_mask)
                    diffs(s_idx) = raw_table{p_mask, metric} - ...
                        raw_table{b_mask, metric};
                end
            end
            [lo, hi] = ci_bounds(diffs);
            [p_value, effect_dz, num_pairs] = paired_stats(diffs);
            rows(row, :) = {methods{m_idx}, metric, ...
                mean(diffs, 'omitnan'), lo, hi, ...
                ~(lo <= 0 && hi >= 0), p_value, effect_dz, num_pairs};
            row = row + 1;
        end
    end
    T = cell2table(rows, 'VariableNames', ...
        {'Baseline','Metric','ProposedMinusBaselineMean', ...
         'CI95Low','CI95High','CIExcludesZero','PairedTPValue', ...
         'EffectSizeDz','NumPairs'});
    T = add_holm_adjustment(T, {'Metric'});
end

function T = scenario_b_dominance_check(paired_table, gamma_ce)
    mask = strcmp(paired_table.Metric, 'CE_gamma');
    S = paired_table(mask, :);
    proposed_wins = S.ProposedMinusBaselineMean > 0 & S.HolmReject;
    T = table(repmat(gamma_ce, height(S), 1), S.Baseline, ...
        S.ProposedMinusBaselineMean, S.CI95Low, S.CI95High, ...
        S.PairedTPValue, S.HolmAdjustedP, S.EffectSizeDz, ...
        proposed_wins, repmat(all(proposed_wins), height(S), 1), ...
        'VariableNames', {'GammaCE','Baseline', ...
        'ProposedMinusBaselineCE','CI95Low','CI95High', ...
        'PairedTPValue','HolmAdjustedP','EffectSizeDz', ...
        'ProposedWinsThisBaseline','ProposedWinsAllComparable'});
end

function [raw_table, best_table] = run_scenario_b_family_alpha_grid(...
    params_base, scenarioB_N, seed_list, theta_true, delta_true, ...
    scenarioB_repeats, scenarioB, alpha_grid, gamma_grid, scenarioB_raw)
    fprintf('\n===== Scenario-B Gamma_alpha family grid =====\n');
    fprintf('N=%d, seeds=[%d..%d], alpha=[%s], gamma=[%s]\n', ...
        scenarioB_N, seed_list(1), seed_list(end), ...
        num2str(alpha_grid, '%.1f '), num2str(gamma_grid, '%.2f '));

    rows = cell(numel(seed_list) * numel(alpha_grid), 11);
    row = 1;
    for s_idx = 1:numel(seed_list)
        params = params_base;
        params.N = scenarioB_N;
        params.rng_seed = seed_list(s_idx);
        params_B = scenario_b_env(params, scenarioB.fou_scale);
        params_B.shock_mode = scenarioB.shock_mode;   % 双场景冲击模式 (v1/v2)

        for a_idx = 1:numel(alpha_grid)
            alpha = alpha_grid(a_idx);
            t0 = tic;
            % scalar α 包络 (focus_s=0): 直接调求解器, 绕过 run_one_method 对
            % params.proposed_focus_s 的继承, 使本网格刻画固定标量 α 的上包络,
            % 与主表自适应 Proposed (α,s=10) 形成"自适应 vs 整条标量族"的对比。
            [pi_star, history] = sec5_1_alpha_robust_solve(...
                params_B, delta_true, theta_true, alpha, 0);
            runtime_sec = toc(t0);

            [expected_payoff, wc_q5] = scenario_b_payoff_stats(pi_star, ...
                delta_true, theta_true, params_B, scenarioB_repeats, ...
                scenarioB.p_shock, scenarioB.sigma_small, ...
                scenarioB.shock_strength);
            sc_share = mean(pi_star(:, 1));

            rows(row, :) = {scenarioB_N, params.rng_seed, alpha, ...
                logical(history.converged), history.iterations, ...
                estimate_q_hat(history.residual), history.residual(end), ...
                expected_payoff, wc_q5, sc_share, runtime_sec};
            row = row + 1;

            fprintf(['Family alpha=%.1f seed=%d R=%3d conv=%d E=%.4f ' ...
                'Q5=%.4f SC=%.3f\n'], alpha, params.rng_seed, ...
                history.iterations, history.converged, expected_payoff, ...
                wc_q5, sc_share);
        end
    end

    raw_table = cell2table(rows, 'VariableNames', ...
        {'N','Seed','Alpha','Converged','Rounds','q_hat', ...
         'FinalResidual','ExpectedPayoff','WorstCaseQ5','SCShare', ...
         'RuntimeSec'});
    best_table = summarize_family_best_gamma(raw_table, scenarioB_raw, gamma_grid);
end

function T = summarize_family_best_gamma(family_raw, scenarioB_raw, gamma_grid)
    rows = cell(numel(gamma_grid), 18);
    % 外部 SOTA 对手 = 非本文 Proposed 的五个主比较方法。家族最优点与这些
    % 外部 SOTA 的逐 gamma 最优者比较, 判定是否打败最强外部对手。
    adaptive_mask = ~strcmp(scenarioB_raw.Class, 'Proposed') & ...
        ~strcmp(scenarioB_raw.Class, 'Family endpoint');
    alphas = unique(family_raw.Alpha);
    seeds = unique(family_raw.Seed);

    for g_idx = 1:numel(gamma_grid)
        gamma = gamma_grid(g_idx);
        alpha_mean_ce = NaN(numel(alphas), 1);
        alpha_ci_ce = NaN(numel(alphas), 1);
        for a_idx = 1:numel(alphas)
            mask = family_raw.Alpha == alphas(a_idx);
            ce = ce_from_mean_tail(family_raw.ExpectedPayoff(mask), ...
                family_raw.WorstCaseQ5(mask), gamma);
            alpha_mean_ce(a_idx) = mean(ce);
            alpha_ci_ce(a_idx) = ci95(ce);
        end
        [family_ce, best_idx] = max(alpha_mean_ce);
        alpha_star = alphas(best_idx);
        fam_mask = family_raw.Alpha == alpha_star;
        family_E = mean(family_raw.ExpectedPayoff(fam_mask));
        family_E_ci = ci95(family_raw.ExpectedPayoff(fam_mask));
        family_WC = mean(family_raw.WorstCaseQ5(fam_mask));
        family_WC_ci = ci95(family_raw.WorstCaseQ5(fam_mask));
        family_ce_ci = alpha_ci_ce(best_idx);

        methods = unique(scenarioB_raw.Method(adaptive_mask), 'stable');
        method_mean_ce = NaN(numel(methods), 1);
        method_ci_ce = NaN(numel(methods), 1);
        for m_idx = 1:numel(methods)
            mask = adaptive_mask & strcmp(scenarioB_raw.Method, methods{m_idx});
            ce = ce_from_mean_tail(scenarioB_raw.ExpectedPayoff(mask), ...
                scenarioB_raw.WorstCaseQ5(mask), gamma);
            method_mean_ce(m_idx) = mean(ce);
            method_ci_ce(m_idx) = ci95(ce);
        end
        [best_adaptive_ce, adaptive_idx] = max(method_mean_ce);
        best_adaptive = methods{adaptive_idx};
        best_adaptive_ci = method_ci_ce(adaptive_idx);

        all_methods = unique(scenarioB_raw.Method, 'stable');
        all_mean_ce = NaN(numel(all_methods), 1);
        for m_idx = 1:numel(all_methods)
            mask = strcmp(scenarioB_raw.Method, all_methods{m_idx});
            ce = ce_from_mean_tail(scenarioB_raw.ExpectedPayoff(mask), ...
                scenarioB_raw.WorstCaseQ5(mask), gamma);
            all_mean_ce(m_idx) = mean(ce);
        end
        [best_fixed_ce, fixed_idx] = max(all_mean_ce);
        best_fixed = all_methods{fixed_idx};

        rows(g_idx, :) = {gamma, alpha_star, family_E, family_E_ci, ...
            family_WC, family_WC_ci, family_ce, family_ce_ci, ...
            best_adaptive, best_adaptive_ce, best_adaptive_ci, ...
            family_ce - best_adaptive_ce, family_ce >= best_adaptive_ce, ...
            best_fixed, best_fixed_ce, family_ce - best_fixed_ce, ...
            family_ce >= best_fixed_ce, numel(seeds)};
    end

    T = cell2table(rows, 'VariableNames', ...
        {'Gamma','AlphaStar','FamilyExpectedPayoffMean', ...
         'FamilyExpectedPayoffCI95','FamilyWorstCaseQ5Mean', ...
         'FamilyWorstCaseQ5CI95','FamilyCEMean','FamilyCECI95', ...
         'BestAdaptiveMethod','BestAdaptiveCEMean','BestAdaptiveCECI95', ...
         'FamilyMinusBestAdaptiveCE','FamilyBeatsAdaptiveEnvelope', ...
         'BestFixedMethod','BestFixedCEMean','FamilyMinusBestFixedCE', ...
         'FamilyBeatsFixedEnvelope','NumSeeds'});
end

function [risk_name, grid] = risk_grid_for_method(method, quick_mode)
% RISK_GRID_FOR_METHOD  返回方法的风险旋钮名 + 扫描网格 (Pareto 前沿对齐)。
%   收敛 SOTA Isobe-APP 无外生风险旋钮 → 返回 'none' 单点。Proposed 返回
%   α-cut α 网格 (场景 s 由 run_scenario_b_risk_frontier 联合二维扫描, 体现 (α,s)
%   二维悲观族全力); 各外部鲁棒 SOTA 扫各自风险参数, 方向均覆盖 "弱→强悲观"
%   (Proposed α:1→0; CVaR α_cv 小=更极端尾部; RQE/MF-RQE τ 大=更规避; DRNE α_dr
%   大=更 worst-case), 使每方法得到完整 (E,WC) 前沿。
    switch method
        case 'Proposed IT2-W-FBRI'        % α-cut 置信 α: 0(最悲观)→1(中点)
            risk_name = 'alpha';
            if quick_mode; grid = [0, 0.5, 0.85, 1.0];
            else; grid = unique([0:0.1:1, 0.85]); end
        case 'CVaR-game'                  % 相干 CVaR 尾部 α_cv: 小→更极端尾部
            risk_name = 'cvar_alpha';
            if quick_mode; grid = [0.1, 0.3, 0.7];
            else; grid = [0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9]; end
        case 'RQE'                        % 熵风险厌恶 τ: 大→更规避
            risk_name = 'rqe_tau';
            if quick_mode; grid = [1, 5, 20];
            else; grid = [0.5, 1, 2, 5, 10, 20, 50]; end
        case 'MF-RQE'                     % 初始分布熵风险 τ: 大→更最坏场景
            risk_name = 'mfrqe_tau';
            if quick_mode; grid = [1, 5, 20];
            else; grid = [0.5, 1, 2, 5, 10, 20, 50]; end
        case 'DRNE-VI'                    % CVaR 模糊集置信 α_dr: 大→更 worst-case
            risk_name = 'drne_alpha';
            if quick_mode; grid = [0.3, 0.6, 0.9];
            else; grid = [0.1, 0.3, 0.5, 0.7, 0.9, 0.95]; end
        otherwise                         % Isobe-APP 等无风险旋钮方法: 单点
            risk_name = 'none';
            grid = NaN;
    end
end

function [pi_star, history] = solve_scenario_b_risk_point(method, ...
    params_B, delta_true, theta_true, focus_s, risk_value)
% SOLVE_SCENARIO_B_RISK_POINT  在指定风险旋钮值下求解一个 Scenario B 前沿点。
%   Proposed 经 α-cut 实参 + 固定场景 focus_s; 外部鲁棒 SOTA 经各自 params 风险
%   字段 (与 solver 默认接口一致); FOU-agnostic 收敛 SOTA 单点 (δ=0)。
    p = params_B;
    switch method
        case 'Proposed IT2-W-FBRI'
            p = proposed_tail_profile(p, risk_value);
            [pi_star, history] = sec5_1_alpha_robust_solve(p, delta_true, ...
                theta_true, risk_value, focus_s);
        case 'CVaR-game'
            p.cvar_alpha = risk_value;
            [pi_star, history] = solve_cvar_game(p, delta_true, theta_true, 1.0);
        case 'RQE'
            p.rqe_tau = risk_value;
            [pi_star, history] = solve_rqe(p, 0, theta_true, 1.0);
        case 'MF-RQE'
            p.mfrqe_tau = risk_value;
            [pi_star, history] = solve_mf_rqe(p, delta_true, theta_true, 1.0);
        case 'DRNE-VI'
            p.drne_alpha = risk_value;
            [pi_star, history] = solve_drne_vi(p, delta_true, theta_true, 1.0);
        case 'OGDA'
            [pi_star, history] = solve_ogda(p, 0, theta_true, 1.0);
        case 'Isobe-APP'
            [pi_star, history] = solve_isobe_app(p, 0, theta_true, 1.0);
        otherwise
            error('frontier: unsupported method %s', method);
    end
end

function frontier_raw = run_scenario_b_risk_frontier(method_names, ...
    method_classes, params_base, scenarioB_N, seed_list, theta_true, ...
    delta_true, scenarioB_repeats, scenarioB, quick_mode)
% RUN_SCENARIO_B_RISK_FRONTIER  Pareto 前沿对齐扫描 (Q8): 对每个主比较方法扫其
%   风险旋钮网格, 逐 seed 解 + 评估得 (E, WC)。
    fprintf('\n===== Scenario-B Pareto frontier alignment (per-method risk sweep) =====\n');
    focus_s_default = params_base.proposed_focus_s;
    % Proposed (α,s) 二维悲观族前沿: 除 α-cut α 外, 联合扫 FOU 聚焦指数 s (核心创新),
    % 用尽二维族全力 (公平修正: 旧版仅扫 α/固定 s=10, 未体现 s 维; 见 stag EXP-7)。
    % 其他方法 s 不适用 (用默认 focus_s, FocusS 列记 NaN, 不进入二维分组)。
    if quick_mode; proposed_s_grid = [0, 10, 40];
    else; proposed_s_grid = [0, 5, 10, 15, 20, 40]; end
    rows = {};
    for s_idx = 1:numel(seed_list)
        params = params_base;
        params.N = scenarioB_N;
        params.rng_seed = seed_list(s_idx);
        params_B = scenario_b_env(params, scenarioB.fou_scale);
        params_B.shock_mode = scenarioB.shock_mode;
        for m_idx = 1:numel(method_names)
            method = method_names{m_idx};
            if strcmp(method_classes{m_idx}, 'Family endpoint')
                continue;
            end
            [risk_name, grid] = risk_grid_for_method(method, quick_mode);
            is_proposed = strcmp(method, 'Proposed IT2-W-FBRI');
            if is_proposed; s_list = proposed_s_grid; else; s_list = focus_s_default; end
            for g_idx = 1:numel(grid)
                rv = grid(g_idx);
                for sg_idx = 1:numel(s_list)
                    this_s = s_list(sg_idx);
                    if is_proposed; fs_col = this_s; else; fs_col = NaN; end
                    t0 = tic;
                    [pi_star, history] = solve_scenario_b_risk_point(method, ...
                        params_B, delta_true, theta_true, this_s, rv);
                    runtime_sec = toc(t0);
                    [E, WC] = scenario_b_payoff_stats(pi_star, delta_true, ...
                        theta_true, params_B, scenarioB_repeats, ...
                        scenarioB.p_shock, scenarioB.sigma_small, ...
                        scenarioB.shock_strength);
                    rows(end + 1, :) = {method, method_classes{m_idx}, ...
                        risk_name, rv, fs_col, params.rng_seed, E, WC, ...
                        mean(pi_star(:, 1)), logical(history.converged), ...
                        history.iterations, runtime_sec}; %#ok<AGROW>
                end
            end
        end
        fprintf('  [frontier] seed=%d done, %d points accumulated\n', ...
            params.rng_seed, size(rows, 1));
    end
    frontier_raw = cell2table(rows, 'VariableNames', ...
        {'Method','Class','RiskName','RiskValue','FocusS','Seed','ExpectedPayoff', ...
         'WorstCaseQ5','SCShare','Converged','Rounds','RuntimeSec'});
end

function [best_table, dom_table] = summarize_frontier_dominance(...
    frontier_raw, gamma_grid, proposed_name)
% SUMMARIZE_FRONTIER_DOMINANCE Select risk knobs on one seed partition and
%   evaluate paired frontier differences on a disjoint partition. Quick
%   mode has one seed and is explicitly labeled same-seed exploratory.
%     best_table: 每 (γ, 方法) 的前沿最优旋钮值 + (E,WC,CE) + CI95;
%     dom_table : 每 (γ, 外部对手) 的 Proposed−对手 前沿 CE 差 + CI + 支配标志。
    methods = unique(frontier_raw.Method, 'stable');
    seeds = unique(frontier_raw.Seed);
    n_seed = numel(seeds);
    if n_seed >= 4
        num_selection = floor(n_seed / 2);
        selection_seeds = seeds(1:num_selection);
        evaluation_seeds = seeds((num_selection + 1):end);
        selection_protocol = 'disjoint seed split';
    else
        selection_seeds = seeds;
        evaluation_seeds = seeds;
        selection_protocol = 'same-seed exploratory';
    end
    selection_seed_mask = ismember(seeds, selection_seeds);
    evaluation_seed_mask = ismember(seeds, evaluation_seeds);
    num_evaluation = nnz(evaluation_seed_mask);
    best_rows = {};
    dom_rows = {};
    for g_idx = 1:numel(gamma_grid)
        gamma = gamma_grid(g_idx);
        best = struct();
        for m_idx = 1:numel(methods)
            method = methods{m_idx};
            mask_m = strcmp(frontier_raw.Method, method);
            cls = frontier_raw.Class{find(mask_m, 1)};
            rn = frontier_raw.RiskName{find(mask_m, 1)};
            sub_m = frontier_raw(mask_m, :);
            % 分组键 combos=[RiskValue, FocusS]: 单点(none)单组; Proposed 按 (α,s) 二维
            % 联合分组 (FocusS 非 NaN); 其他风险方法按 α 单维 (FocusS=NaN)。
            if strcmp(rn, 'none')
                combos = [NaN, NaN];                        % 单点方法 (如 Isobe-APP)
            elseif any(~isnan(sub_m.FocusS))
                combos = unique([sub_m.RiskValue, sub_m.FocusS], 'rows');   % Proposed (α,s)
            else
                rvs = unique(sub_m.RiskValue);
                combos = [rvs, nan(numel(rvs), 1)];         % 其他风险方法 (α, NaN)
            end
            best_selection_mean = -inf;
            best_rv = NaN;
            best_fs = NaN;
            best_ce = NaN(num_evaluation, 1);
            best_E = NaN;
            best_WC = NaN;
            for c_idx = 1:size(combos, 1)
                rv = combos(c_idx, 1); fs = combos(c_idx, 2);
                if strcmp(rn, 'none')
                    mask_rv = mask_m;
                elseif isnan(fs)
                    mask_rv = mask_m & frontier_raw.RiskValue == rv;
                else
                    mask_rv = mask_m & frontier_raw.RiskValue == rv & ...
                        frontier_raw.FocusS == fs;
                end
                sub = frontier_raw(mask_rv, :);
                ce_seed = NaN(n_seed, 1);
                for k = 1:n_seed
                    ridx = find(sub.Seed == seeds(k), 1);
                    if ~isempty(ridx)
                        ce_seed(k) = ce_from_mean_tail(...
                            sub.ExpectedPayoff(ridx), ...
                            sub.WorstCaseQ5(ridx), gamma);
                    end
                end
                selection_mean = mean( ...
                    ce_seed(selection_seed_mask), 'omitnan');
                if selection_mean > best_selection_mean
                    best_selection_mean = selection_mean;
                    best_rv = rv;
                    best_fs = fs;
                    best_ce = ce_seed(evaluation_seed_mask);
                    eval_rows = ismember(sub.Seed, evaluation_seeds);
                    best_E = mean(sub.ExpectedPayoff(eval_rows), 'omitnan');
                    best_WC = mean(sub.WorstCaseQ5(eval_rows), 'omitnan');
                end
            end
            best_evaluation_mean = mean(best_ce, 'omitnan');
            f = matlab.lang.makeValidName(method);
            best.(f).rv = best_rv; best.(f).fs = best_fs;
            best.(f).ce = best_ce;
            best.(f).mean = best_evaluation_mean;
            best.(f).selection_mean = best_selection_mean;
            best_rows(end + 1, :) = {gamma, method, cls, best_rv, best_fs, best_E, ...
                best_WC, best_evaluation_mean, ci95(best_ce), ...
                num_evaluation, best_selection_mean, numel(selection_seeds), ...
                selection_protocol}; %#ok<AGROW>
        end
        % Proposed 前沿最优 vs 各外部对手 (非 Proposed、非家族端点) 同 seed 配对
        pf = best.(matlab.lang.makeValidName(proposed_name));
        for m_idx = 1:numel(methods)
            method = methods{m_idx};
            if strcmp(method, proposed_name); continue; end
            mask_m = strcmp(frontier_raw.Method, method);
            cls = frontier_raw.Class{find(mask_m, 1)};
            if strcmp(cls, 'Family endpoint'); continue; end
            mf = best.(matlab.lang.makeValidName(method));
            diffs = pf.ce - mf.ce;     % 同 seed 配对差
            [lo, hi] = ci_bounds(diffs);
            mean_diff = mean(diffs, 'omitnan');
            [p_value, effect_dz, num_pairs] = paired_stats(diffs);
            dom_rows(end + 1, :) = {gamma, method, cls, mf.rv, mf.mean, ...
                pf.rv, pf.fs, pf.mean, mean_diff, lo, hi, ...
                p_value, effect_dz, num_pairs}; %#ok<AGROW>
        end
    end
    best_table = cell2table(best_rows, 'VariableNames', ...
        {'Gamma','Method','Class','BestRiskValue','BestFocusS','FrontierE','FrontierWC', ...
         'FrontierCE','FrontierCECI95','NumEvaluationSeeds', ...
         'SelectionCE','NumSelectionSeeds','SelectionProtocol'});
    dom_table = cell2table(dom_rows, 'VariableNames', ...
        {'Gamma','Baseline','BaselineClass','BaselineBestRisk', ...
         'BaselineFrontierCE','ProposedBestAlpha','ProposedBestFocusS','ProposedFrontierCE', ...
         'ProposedMinusBaselineMean','CI95Low','CI95High', ...
         'PairedTPValue','EffectSizeDz','NumPairs'});
    dom_table = add_holm_adjustment(dom_table, {'Gamma'});
    dom_table.ProposedDominates = ...
        dom_table.ProposedMinusBaselineMean > 0 & dom_table.HolmReject;
end

function ce = ce_from_mean_tail(expected_payoff, wc_q5, gamma)
    ce = expected_payoff - gamma .* (expected_payoff - wc_q5);
end

function gap = common_alpha_exploitability(pi_profile, delta, theta, ...
    alpha_eval, params)
% COMMON_ALPHA_EXPLOITABILITY Same terminal-quality metric for every solver.
%   It ignores each solver's native residual and evaluates the maximum pure
%   deviation gain in the common alpha-pessimistic game.
    [~, ~, pure_hat, pure_rho] = ...
        sec4_1_2_pure_interval_payoff_matrix( ...
        pi_profile, delta, theta, params);
    decision_payoff = pure_hat - (1 - alpha_eval) * pure_rho;
    incumbent = sum(pi_profile .* decision_payoff, 2);
    gap = max(max(decision_payoff, [], 2) - incumbent);
end

function criterion = native_criterion(method)
    switch method
        case 'Proposed IT2-W-FBRI'
            criterion = 'max strategy-step L1';
        case 'Isobe-APP'
            criterion = 'outer-anchor L1';
        case {'RQE', 'MF-RQE'}
            criterion = 'quantal fixed-point L1';
        case 'CVaR-game'
            criterion = 'mixed best-response fixed-point L1';
        case 'DRNE-VI'
            criterion = 'worst-distribution exploitability';
        otherwise
            criterion = 'method-native residual';
    end
end

function residual = native_final_residual(history)
    if isfield(history, 'final_native_residual')
        residual = history.final_native_residual;
    else
        residual = history.residual(end);
    end
end

function [p_value, effect_dz, num_pairs] = paired_stats(x)
    x = x(~isnan(x));
    num_pairs = numel(x);
    if num_pairs <= 1
        p_value = NaN;
        effect_dz = NaN;
        return;
    end
    mean_x = mean(x);
    sd_x = std(x);
    if sd_x <= eps
        if abs(mean_x) <= eps
            p_value = 1;
            effect_dz = 0;
        else
            p_value = 0;
            effect_dz = sign(mean_x) * Inf;
        end
        return;
    end
    effect_dz = mean_x / sd_x;
    t_stat = mean_x / (sd_x / sqrt(num_pairs));
    degrees_freedom = num_pairs - 1;
    p_value = betainc(degrees_freedom / ...
        (degrees_freedom + t_stat^2), degrees_freedom / 2, 0.5);
end

function T = add_holm_adjustment(T, group_variables)
    num_rows = height(T);
    keys = strings(num_rows, 1);
    for r = 1:num_rows
        parts = strings(numel(group_variables), 1);
        for k = 1:numel(group_variables)
            value = T.(group_variables{k})(r);
            parts(k) = string(value);
        end
        keys(r) = strjoin(parts, "|");
    end

    adjusted = NaN(num_rows, 1);
    unique_keys = unique(keys, 'stable');
    for k = 1:numel(unique_keys)
        idx = find(keys == unique_keys(k));
        p_values = T.PairedTPValue(idx);
        valid = ~isnan(p_values);
        idx_valid = idx(valid);
        if isempty(idx_valid)
            continue;
        end
        [sorted_p, order] = sort(p_values(valid));
        m = numel(sorted_p);
        adjusted_sorted = cummax((m - (1:m)' + 1) .* sorted_p);
        adjusted_sorted = min(1, adjusted_sorted);
        restored = NaN(m, 1);
        restored(order) = adjusted_sorted;
        adjusted(idx_valid) = restored;
    end
    T.HolmAdjustedP = adjusted;
    T.HolmReject = adjusted < 0.05;
end

function c = ci95(x)
    x = x(~isnan(x));
    if numel(x) <= 1
        c = 0;
    else
        n = numel(x);
        degrees_freedom = n - 1;
        beta_quantile = betaincinv(0.05, degrees_freedom / 2, 0.5);
        t_critical = sqrt(degrees_freedom * ...
            (1 / beta_quantile - 1));
        c = t_critical * std(x) / sqrt(n);
    end
end

function [lo, hi] = ci_bounds(x)
    x = x(~isnan(x));
    if isempty(x)
        lo = NaN;
        hi = NaN;
        return;
    end
    half = ci95(x);
    lo = mean(x) - half;
    hi = mean(x) + half;
end

function idx = sample_categorical(p)
    c = cumsum(p(:));
    u = rand();
    idx = find(u <= c, 1, 'first');
    if isempty(idx)
        idx = numel(p);
    end
end

function y = clip01(x)
    y = max(0, min(1, x));
end
