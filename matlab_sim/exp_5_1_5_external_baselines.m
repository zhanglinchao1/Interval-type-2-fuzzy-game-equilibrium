% exp_5_1_5_external_baselines.m - 论文 §5.1 实验五: 外部基线对照 (E1)
%
% 验证目标:
%   针对审稿意见"基线全是自身退化版"(que.md E1), 引入两类外部求解链对照:
%   (a) KM/EKM 迭代式 type-reduction 求解链 (Karnik–Mendel 2001 / Wu–Mendel EKM):
%       与 Proposed 唯一差别是 type-reduction 环节用已发表的数值迭代算法
%       代替 Lemma 1 闭式。预言 (Lemma 1): 均衡逐位一致, 但每轮多一笔
%       切换点迭代开销 —— 同时充当 Lemma 1 的实证验证。
%   (b) Type-1 独立求解链: 完全去 FOU (δ=0) 的名义收益 + 同一软响应框架,
%       即文献中标准的 Type-1 模糊博弈求解路径。预言: 均衡偏离 Proposed,
%       决策安全垫为 0, 最差扰动收益劣于 Proposed (与实验二结论交叉印证)。
%   说明: D.-F. Li 区间双矩阵规划法仅适用双人零和矩阵博弈, 与本文 N 人
%   混合策略 + 治理耦合场景不可比, 正文中以一句话说明不纳入数值对照。
%
% 实验配置 (对齐实验二): bell FOU (fou_modulation=true), δ=0.20, α=0.5, N=50
%
% 输出:
%   table/table5_5_external_baselines.csv - 四条求解链对照表
%
% 运行: 在 matlab_sim 目录下执行 exp_5_1_5_external_baselines

clear; clc; close all;
addpath('utils');

img_dir = 'image';  tab_dir = 'table';
if ~exist(tab_dir, 'dir'); mkdir(tab_dir); end

%% 1) 实验配置
params = config_params();
params.fou_modulation = true;      % bell FOU (对齐实验二, 保证 ρ 跨策略异质)
delta = 0.20;                      % 不确定性半带宽 (实验二最大档)
alpha = params.alpha;              % 0.5
theta = params.theta;              % P_pay × uniform ω = [0.40; 0.35; 0.25]
sigma_xi = delta * 0.5;            % 扰动强度 (同实验二 σ_δ = δ/2)
n_perturb = 30;                    % 扰动重采样次数 (同实验二)
km_grid = 101;                     % KM 论域离散点数

fprintf('===== 论文 §5.1 实验五: 外部基线对照 (E1) =====\n');
fprintf('配置: N=%d, δ=%.2f, α=%.1f, λ=%.2f, β=%.1f, bell FOU\n\n', ...
    params.N, delta, alpha, params.lambda, params.beta);

%% 2) 求解链 1: Proposed (Lemma 1 闭式 type-reduction)
fprintf('--- [1/4] Proposed (closed-form, Lemma 1) ---\n');
t0 = tic;
[pi_prop, hist_prop] = sec5_1_alpha_robust_solve(params, delta, theta, alpha);
t_prop = toc(t0);
fprintf('  收敛轮数 R=%d, 用时 %.3f s\n', hist_prop.iterations, t_prop);

%% 3) 求解链 2/3: KM / EKM 迭代式 type-reduction
fprintf('--- [2/4] KM-iterative type-reduction (Karnik–Mendel 2001) ---\n');
t0 = tic;
[pi_km, hist_km, km_stats] = solve_with_km(params, delta, theta, alpha, km_grid, false);
t_km = toc(t0);
fprintf('  收敛轮数 R=%d, 用时 %.3f s, KM 平均切换点迭代 %.1f 轮/次\n', ...
    hist_km.iterations, t_km, km_stats.mean_inner_iter);

fprintf('--- [3/4] EKM-iterative type-reduction (Wu–Mendel) ---\n');
t0 = tic;
[pi_ekm, hist_ekm, ekm_stats] = solve_with_km(params, delta, theta, alpha, km_grid, true);
t_ekm = toc(t0);
fprintf('  收敛轮数 R=%d, 用时 %.3f s, EKM 平均切换点迭代 %.1f 轮/次\n', ...
    hist_ekm.iterations, t_ekm, ekm_stats.mean_inner_iter);

%% 4) 求解链 4: Type-1 独立求解链 (δ=0 名义收益)
fprintf('--- [4/4] Type-1 chain (no FOU, nominal payoff) ---\n');
t0 = tic;
[pi_t1, hist_t1] = sec4_3_1_wfbri_solve(params, 0, theta);
t_t1 = toc(t0);
fprintf('  收敛轮数 R=%d, 用时 %.3f s\n', hist_t1.iterations, t_t1);

%% 5) 统一指标评估
methods  = {'Proposed (closed-form)', 'KM-iterative', 'EKM-iterative', 'Type-1 chain'};
pis      = {pi_prop, pi_km, pi_ekm, pi_t1};
iters    = [hist_prop.iterations, hist_km.iterations, ...
            hist_ekm.iterations, hist_t1.iterations];
runtimes = [t_prop, t_km, t_ekm, t_t1];
deltas_solve = [delta, delta, delta, 0];   % Type-1 链按 δ=0 评估 (同实验二口径)

n_m = numel(methods);
U_mean  = zeros(1, n_m);  margin = zeros(1, n_m);
WC_q5   = zeros(1, n_m);  dist_to_prop = zeros(1, n_m);

for k = 1:n_m
    d_k = deltas_solve(k);
    [~, ~, U_hat, rho_k] = sec4_1_2_mixed_payoff( ...
        pis{k}, d_k, theta, params);
    U_mean(k) = mean(U_hat);
    margin(k) = (1 - alpha) * max(rho_k);
    if k == 4
        margin(k) = 0;   % Type-1 决策无 FOU, 安全垫恒 0
    end
    WC_q5(k) = worst_case_payoff(pis{k}, d_k, theta, params, sigma_xi, n_perturb);
    dist_to_prop(k) = sum(sum(abs(pis{k} - pi_prop)));
end

%% 6) Lemma 1 数值精确性抽查: KM 区间 vs 闭式区间
[U_l, U_u] = sec4_1_2_mixed_payoff( ...
    pi_prop, delta, theta, params);
km_err = 0;
for i = 1:params.N
    [c_l, c_r, ~] = sec5_1_km_type_reduction(U_l(i), U_u(i), km_grid, false);
    km_err = max(km_err, max(abs(c_l - U_l(i)), abs(c_r - U_u(i))));
end
fprintf('\nKM type-reduced 区间 vs 闭式端点最大偏差: %.2e\n', km_err);

%% 7) 结果汇总与导出
fprintf('\n===== 实验五结果汇总 =====\n');
fprintf('%-24s | %4s | %10s | %8s | %8s | %8s | %10s\n', ...
    'Method', 'R', '||π-π_P||₁', 'Ū', 'Margin', 'WC_Q5', 'Time (s)');
for k = 1:n_m
    fprintf('%-24s | %4d | %10.2e | %8.4f | %8.4f | %8.4f | %10.3f\n', ...
        methods{k}, iters(k), dist_to_prop(k), U_mean(k), ...
        margin(k), WC_q5(k), runtimes(k));
end

T = table(methods', iters', dist_to_prop', U_mean', margin', WC_q5', runtimes', ...
    'VariableNames', {'Method', 'Iterations', 'DistToProposedL1', ...
    'AvgPayoff', 'DecisionMargin', 'WorstCaseQ5', 'RuntimeSec'});
writetable(T, fullfile(tab_dir, 'table5_5_external_baselines.csv'));
fprintf('\n[表] %s\n', fullfile(tab_dir, 'table5_5_external_baselines.csv'));

%% 8) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');
chk1 = dist_to_prop(2) < 1e-9 && dist_to_prop(3) < 1e-9;
fprintf('%s (i) KM/EKM 均衡与闭式 Proposed 逐位一致: %.2e / %.2e (<1e-9)\n', ...
    pass_label(chk1), dist_to_prop(2), dist_to_prop(3));
chk2 = km_err < 1e-9;
fprintf('%s (ii) KM type-reduced 区间 = 闭式端点 (Lemma 1): 偏差 %.2e\n', ...
    pass_label(chk2), km_err);
chk3 = t_km > t_prop && t_ekm > t_prop;
fprintf('%s (iii) 迭代式 KM/EKM 开销高于闭式: ×%.1f / ×%.1f\n', ...
    pass_label(chk3), t_km / t_prop, t_ekm / t_prop);
chk4 = margin(4) == 0 && WC_q5(4) < WC_q5(1);
fprintf('%s (iv) Type-1 链零安全垫且最差扰动收益劣于 Proposed: WC %.4f < %.4f\n', ...
    pass_label(chk4), WC_q5(4), WC_q5(1));

%% ====================== 局部函数 ======================

function [pi_star, history, stats] = solve_with_km(params, delta, theta, ...
    alpha, km_grid, use_ekm)
%SOLVE_WITH_KM 与 sec5_1_alpha_robust_solve 同框架的 W-FBRI 求解器,
%   但 type-reduction 环节用迭代式 KM/EKM (sec5_1_km_type_reduction) 代替
%   Lemma 1 闭式: 对每个 (i,j) 的收益区间 [U_l, U_u] 数值计算质心区间
%   [c_l, c_r], 再取 ν = (c_l+c_r)/2 - (1-α)(c_r-c_l)/2。
%   其余 (初始化/softmax/阻尼/终止) 与 Proposed 完全一致, 保证对照公平。
    N = params.N;
    num_s = params.num_strategies;
    lambda = params.lambda;
    beta = params.beta;
    R_max = params.R_max;
    eps_tol = params.eps_tol;

    rng(params.rng_seed);
    pi_profile = ones(N, num_s) / num_s;
    pi_profile = pi_profile + 0.01 * rand(N, num_s);
    pi_profile = pi_profile ./ sum(pi_profile, 2);

    total_inner = 0;  total_calls = 0;

    for r = 1:R_max
        pi_new = zeros(N, num_s);
        [pure_lower, pure_upper] = ...
            sec4_1_2_pure_interval_payoff_matrix( ...
            pi_profile, delta, theta, params);
        for i = 1:N
            nu_i = zeros(num_s, 1);
            for j = 1:num_s
                % --- 迭代式 KM/EKM type-reduction (替代 Lemma 1 闭式) ---
                [c_l, c_r, n_it] = sec5_1_km_type_reduction(...
                    pure_lower(i, j), pure_upper(i, j), km_grid, use_ekm);
                total_inner = total_inner + n_it;
                total_calls = total_calls + 1;
                nu_i(j) = (c_l + c_r) / 2 - (1 - alpha) * (c_r - c_l) / 2;
            end
            br_i = sec4_3_1_softmax_br(nu_i, lambda);
            pi_new(i, :) = (1 - beta) * pi_profile(i, :) + beta * br_i';
        end

        e_pi = max(sum(abs(pi_new - pi_profile), 2));
        pi_profile = pi_new;

        if e_pi <= eps_tol
            history.converged = true;
            history.iterations = r;
            break;
        end
        if r == R_max
            history.converged = false;
            history.iterations = R_max;
        end
    end

    pi_star = pi_profile;
    stats.mean_inner_iter = total_inner / max(total_calls, 1);
end

function wc = worst_case_payoff(pi_star, delta_solve, theta, params, ...
    sigma_xi, n_perturb)
%WORST_CASE_PAYOFF 扰动下 mean(U_hat) 的 5% 分位数 (Worst-case 实现收益)
%
%   注 (Route C 公平性, 与 exp_5_1_2 worst_case_payoff 完全一致): "实现收益"
%   评估在点隶属度 (δ=0) 下进行 —— 扰动 σ_ξ 已代表不确定性的一次实现, FOU
%   半带宽 δ 是决策时的先验不确定带, 不应再叠加到实现收益上 (否则凹聚合的
%   中心偏移 -Σθδ² 会被不公平地计入实现收益, 使 IT2/Proposed 相对 Type-1
%   系统性偏低)。各方法仅在求解 π* 时按各自 δ 决策, 实现收益统一在 δ=0 下
%   评估, 差异完全来自决策 π* 的鲁棒性。delta_solve 保留仅作签名兼容。
    delta_realized = 0;   % 实现收益采用点隶属度 (见上)
    if sigma_xi <= 0
        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, delta_realized, theta, params);
        wc = mean(U_hat); return;
    end
    U_hat_means = zeros(n_perturb, 1);
    rng(params.rng_seed + 42);
    for k = 1:n_perturb
        p = params;
        p.trust_matrix = clip01(params.trust_matrix + ...
            sigma_xi * randn(size(params.trust_matrix)));
        p.delay_matrix = clip01(params.delay_matrix + ...
            sigma_xi * randn(size(params.delay_matrix)));
        p.res_matrix = clip01(params.res_matrix + ...
            sigma_xi * randn(size(params.res_matrix)));
        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, delta_realized, theta, p);
        U_hat_means(k) = mean(U_hat);
    end
    wc = quantile(U_hat_means, 0.05);
end

function y = clip01(x)
% 数值裁剪到 [0, 1]
    y = max(0, min(1, x));
end

function s = pass_label(ok)
    if ok; s = '[PASS]'; else; s = '[WARN]'; end
end
