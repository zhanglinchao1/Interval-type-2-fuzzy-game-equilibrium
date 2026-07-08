% exp_5_1_4_alpha_path.m - 论文 §5.1 实验四: 均衡路径关于 α 的正则性与 FOU 规避验证
%
% 验证目标 (对齐定理 2 "Regularity and FOU-aversion of the equilibrium path"):
%   (a) 定理 2(i) Lipschitz 均衡路径:
%         ||π*(α) - π*(α')||_1 ≤ N·ρ̄_var / (2λ(1-κ)) · |α - α'|
%       其中 ρ̄_var = max_i range_j ρ_{i,j} 为不确定半径的跨策略变差,
%       κ = D_ν/(2λ) 为命题 1 结构化收缩模量 (bell-FOU: D_ν = D(θ)+4(1-α)E(θ))
%   (b) Route C 凹聚合下两条 FOU 路线均非退化: 凹聚合 g(μ)=2μ-μ² 使
%       ρ_{i,j}=Σθ·2(1-μ_{i,j})δ 随策略 j 异质 (μ 异质 ⟹ ρ 异质), 故即便
%       **均匀 FOU** 也有 ρ̄_var>0, 均衡路径关于 α 非恒定但严格 Lipschitz 正则。
%       (线性聚合下均匀 FOU 才退化为 ρ̄_var=0 的恒定路径; 凹聚合消除了该退化,
%        与中心分离卖点一致 —— IT2 永不塌缩为 Type-1, 见 exp_5_1_7。)
%   (c) 定理 2(ii) FOU 规避单调性: 软响应似然比
%         log([BR]_j/[BR]_{j'}) = (ν_j^α - ν_{j'}^α)/λ
%       关于 α 严格线性递增, 斜率恰为 (ρ_{i,j} - ρ_{i,j'})/λ
%   (d) 群体层面: α 下降时均衡质量从高 ρ 策略向低 ρ 策略转移
%
% 实验配置 (两条 FOU 路线分开认证, 均在凹聚合认证窗 λ>D_ν/2 内):
%   Part A - uniform FOU: δ=0.10, λ=0.20 (Sim I 默认认证工作点 κ=D_ν/2λ<1)
%   Part B - bell FOU:    δ=0.20, λ=0.50 (取 λ 使 κ(α_min)<1, 全网格在定理 2 认证区内;
%             δ=0.20 与 Sim II 最大不确定性档一致, bell-FOU 在 δ≤0.25 时无截断)
%
% 输出:
%   image/fig5_13_theorem2.png      - 定理 2 实证 (竖排 2x1): (a) ||π*(α)-π*(1)||_1 路径(两 FOU, 2(i));
%                                     (b) 均衡质量转移 (2(ii) FOU-aversion)
%     (被删子图: 逐步斜率 vs Lipschitz 界、log-似然比线性律; 其数值仍打印并在正文报告)
%   table/table5_4_alpha_path.csv   - α 网格 × {两 FOU 路径距离/斜率/ρ̄_var, 策略质量}

clear; clc; close all;

%% 全局字体设置
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultTextFontSize', 12);

%% 路径与输出目录
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
img_dir = fullfile(script_dir, 'image');
tbl_dir = fullfile(script_dir, 'table');
if ~exist(img_dir, 'dir'); mkdir(img_dir); end
if ~exist(tbl_dir, 'dir'); mkdir(tbl_dir); end

%% 参数设置
params_base = config_params();
params_base.N = 50;
theta = params_base.theta;

alpha_grid = 0.1:0.1:1.0;            % α 扫描网格 (细于 Sim II 的 4 档)
num_alpha = length(alpha_grid);

% Part A: uniform FOU 配置
delta_uni  = 0.10;                   % μ ∈ [0.175, 0.85] ⊂ [δ, 1-δ], 无截断
lambda_uni = params_base.lambda;     % 0.20 (凹聚合认证窗默认工作点, κ=D_ν/2λ<1)

% Part B: bell FOU 配置
delta_bell  = 0.20;
lambda_bell = 0.50;                  % 使 κ(α_min) < 1 (推导见下), 属 Sim I λ 扫描网格

fprintf('===== 论文 §5.1 实验四: 均衡路径 α 正则性与 FOU 规避 (定理 2) =====\n');
fprintf('α 网格 = [%s]\n', num2str(alpha_grid, '%.1f '));

%% 1) 结构化常数: D(θ), E(θ), κ(α) (命题 1 + 定理 2)
[D_theta, ~] = sec4_3_1_kernel_variation_modulus(params_base, theta);

% E(θ) = Σ_k θ_k δ_k max_j range_l M_k(j,l)   (公式 4-Dbell, bell-FOU 附加项)
kernels = {params_base.trust_matrix, params_base.delay_matrix, params_base.res_matrix};
E_theta_unit = 0;                    % 单位 δ 的 E(θ)/δ
for k = 1:3
    row_ranges = max(kernels{k}, [], 2) - min(kernels{k}, [], 2);
    E_theta_unit = E_theta_unit + theta(k) * max(row_ranges);
end
E_theta_bell = delta_bell * E_theta_unit;

% bell-FOU 在 α 网格最小值处的收缩模量 (整条路径的最保守认证点)
alpha_min = min(alpha_grid);
D_nu_bell_worst = D_theta + 4 * (1 - alpha_min) * E_theta_bell;
kappa_bell = D_nu_bell_worst / (2 * lambda_bell);
kappa_uni  = D_theta / (2 * lambda_uni);   % uniform FOU: D_ν = D(θ), 与 α 无关

fprintf('\n[结构化常数] D(θ)=%.4f, E(θ)|δ=%.2f = %.4f\n', ...
    D_theta, delta_bell, E_theta_bell);
fprintf('  uniform: κ = %.4f (λ=%.2f)  %s\n', kappa_uni, lambda_uni, ...
    pass_label(kappa_uni < 1));
fprintf('  bell:    κ(α=%.1f) = %.4f (λ=%.2f)  %s\n', alpha_min, kappa_bell, ...
    lambda_bell, pass_label(kappa_bell < 1));

%% 2) Part A: uniform FOU 均衡路径 (凹聚合下非恒定, 但 Lipschitz 正则)
fprintf(['\n--- Part A: uniform FOU (δ=%.2f, λ=%.2f), 凹聚合下 ρ̄_var>0, ' ...
    '路径非恒定但 Lipschitz 正则 ---\n'], delta_uni, lambda_uni);
params_uni = params_base;
params_uni.fou_modulation = false;
params_uni.lambda = lambda_uni;

pi_uni    = cell(num_alpha, 1);
rho_var_u = zeros(num_alpha, 1);     % 各 α 均衡处的 ρ̄_var (uniform FOU)
sat_ok_uni = true;
for a_idx = 1:num_alpha
    [pi_uni{a_idx}, ~] = sec5_1_alpha_robust_solve(params_uni, delta_uni, ...
        theta, alpha_grid(a_idx));
    % 凹聚合闭式 ρ=Σθ·2(1-μ)δ 要求 μ ∈ [δ, 1-δ] (无截断), 否则 clip 破坏闭式
    mu_nom = sec3_3_nominal_membership(pi_uni{a_idx}, params_uni);
    if min(mu_nom(:)) < delta_uni || max(mu_nom(:)) > 1 - delta_uni
        sat_ok_uni = false;
    end
    rho_mat_u = per_strategy_rho(pi_uni{a_idx}, delta_uni, theta, params_uni);
    rho_var_u(a_idx) = max(max(rho_mat_u, [], 2) - min(rho_mat_u, [], 2));
end
dist_to_one_uni = cellfun(@(p) sum(abs(p - pi_uni{end}), 'all'), pi_uni);

% uniform FOU: D_ν=D(θ) (与 α 无关), 逐步斜率与 Lipschitz 界 (定理 2(i))
% kappa_uni 与上方第 1) 节同值 (D_theta/(2λ_uni)), 此处用于 Lipschitz 界计算
rho_var_bar_uni = max(rho_var_u);
slope_bound_uni = params_base.N * rho_var_bar_uni / ...
    (2 * lambda_uni * (1 - kappa_uni));
step_slope_uni = zeros(num_alpha - 1, 1);
for a_idx = 1:num_alpha - 1
    step_slope_uni(a_idx) = sum(abs(pi_uni{a_idx + 1} - pi_uni{a_idx}), 'all') / ...
        (alpha_grid(a_idx + 1) - alpha_grid(a_idx));
end
fprintf('  ρ̄_var=%.4f (>0: 曲率诱导), max_α ||π*(α)-π*(1)||_1 = %.4f\n', ...
    rho_var_bar_uni, max(dist_to_one_uni));
fprintf('  Lipschitz 界 N·ρ̄_var/(2λ(1-κ))=%.4f, 实测 max 斜率=%.4f %s, 饱和检查 %s\n', ...
    slope_bound_uni, max(step_slope_uni), ...
    pass_label(all(step_slope_uni <= slope_bound_uni + 1e-9)), ...
    pass_label(sat_ok_uni));

%% 3) Part B: bell FOU 均衡路径 + 逐步 Lipschitz 比
fprintf('\n--- Part B: bell FOU (δ=%.2f, λ=%.2f), 定理 2(i) 路径界 ---\n', ...
    delta_bell, lambda_bell);
params_bell = params_base;
params_bell.fou_modulation = true;
params_bell.lambda = lambda_bell;

pi_bell   = cell(num_alpha, 1);
rho_var_g = zeros(num_alpha, 1);     % 各 α 均衡处的 ρ̄_var
mass_bell = zeros(num_alpha, params_base.num_strategies);
for a_idx = 1:num_alpha
    [pi_bell{a_idx}, ~] = sec5_1_alpha_robust_solve(params_bell, delta_bell, ...
        theta, alpha_grid(a_idx));
    rho_mat = per_strategy_rho(pi_bell{a_idx}, delta_bell, theta, params_bell);
    rho_var_g(a_idx) = max(max(rho_mat, [], 2) - min(rho_mat, [], 2));
    mass_bell(a_idx, :) = mean(pi_bell{a_idx}, 1);
end

% ρ̄_var 取整条路径上的最大值 (定理 3 常数的经验代理)
rho_var_bar = max(rho_var_g);
slope_bound = params_base.N * rho_var_bar / (2 * lambda_bell * (1 - kappa_bell));

% 逐步路径增量与斜率
step_dist  = zeros(num_alpha - 1, 1);
step_slope = zeros(num_alpha - 1, 1);
for a_idx = 1:num_alpha - 1
    step_dist(a_idx) = sum(abs(pi_bell{a_idx + 1} - pi_bell{a_idx}), 'all');
    step_slope(a_idx) = step_dist(a_idx) / ...
        (alpha_grid(a_idx + 1) - alpha_grid(a_idx));
end
dist_to_one_bell = cellfun(@(p) sum(abs(p - pi_bell{end}), 'all'), pi_bell);

fprintf('  ρ̄_var (路径最大) = %.4f, 理论斜率界 N·ρ̄_var/(2λ(1-κ)) = %.4f\n', ...
    rho_var_bar, slope_bound);
fprintf('  %-10s | %-14s | %-12s | %s\n', 'α 区间', '实测 ||Δπ||_1/Δα', '理论界', '满足');
for a_idx = 1:num_alpha - 1
    fprintf('  [%.1f,%.1f]  | %14.4f | %12.4f | %s\n', ...
        alpha_grid(a_idx), alpha_grid(a_idx + 1), step_slope(a_idx), ...
        slope_bound, pass_label(step_slope(a_idx) <= slope_bound + 1e-9));
end

%% 4) Part C: 定理 3(ii) FOU 规避单调性 (固定 π_{-i} 的似然比线性律)
fprintf('\n--- Part C: FOU 规避似然比 (固定 π_{-i} = bell α=1 均衡) ---\n');
pi_ref = pi_bell{end};               % α=1 均衡作为固定环境
agent_i = 1;
rho_ref = per_strategy_rho(pi_ref, delta_bell, theta, params_bell);
[~, j_hi] = max(rho_ref(agent_i, :));    % 最大 ρ 策略
[~, j_lo] = min(rho_ref(agent_i, :));    % 最小 ρ 策略
slope_theory = (rho_ref(agent_i, j_hi) - rho_ref(agent_i, j_lo)) / lambda_bell;

log_ratio = zeros(num_alpha, 1);
for a_idx = 1:num_alpha
    nu_i = alpha_lower_payoff_fixed(pi_ref, delta_bell, theta, params_bell, ...
        agent_i, alpha_grid(a_idx));
    br_i = sec4_3_1_softmax_br(nu_i, lambda_bell);
    log_ratio(a_idx) = log(br_i(j_hi) / br_i(j_lo));
end
% 线性回归斜率 (应与理论斜率机器精度吻合)
p_fit = polyfit(alpha_grid', log_ratio, 1);
slope_meas = p_fit(1);
rel_err = abs(slope_meas - slope_theory) / max(abs(slope_theory), eps);
fprintf('  策略对 (j_hi=%d, j_lo=%d): ρ 差 = %.4f\n', j_hi, j_lo, ...
    rho_ref(agent_i, j_hi) - rho_ref(agent_i, j_lo));
fprintf('  log-似然比斜率: 实测 %.6f vs 理论 (Δρ/λ) %.6f, 相对误差 %.2e\n', ...
    slope_meas, slope_theory, rel_err);

% 群体层面质量转移: 全体 agent 的高/低 ρ 策略均值质量
[~, j_hi_pop] = max(mean(rho_ref, 1));
[~, j_lo_pop] = min(mean(rho_ref, 1));
mass_hi = mass_bell(:, j_hi_pop);
mass_lo = mass_bell(:, j_lo_pop);
fprintf('  群体质量转移 (α: %.1f→%.1f): 高ρ策略 %d 质量 %.4f→%.4f, 低ρ策略 %d 质量 %.4f→%.4f\n', ...
    alpha_grid(end), alpha_grid(1), j_hi_pop, mass_hi(end), mass_hi(1), ...
    j_lo_pop, mass_lo(end), mass_lo(1));

%% 5) Fig 5-13: 定理 2 实证 (单栏竖排 2x1; 原 4 子图筛为 2)
%   (a) 均衡路径距离 (定理 2(i): 凹聚合下路径非退化、α-active);
%   (b) 群体质量转移 (定理 2(ii): FOU-aversion, 高ρ→低ρ 策略)。
%   被删两子图 (逐步斜率 vs Lipschitz 界、log-似然比线性律) 仍由上方计算并
%   打印, 其关键数值 (斜率≤界; Δρ/λ 斜率) 在论文正文以一句话报告。
figure('Name', 'Empirical Illustration of Theorem 2', 'Position', [100,80,480,640]);

subplot(2, 1, 1);
hold on;
plot(alpha_grid, dist_to_one_uni, '-s', 'Color', [0.49 0.18 0.56], ...
    'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', [0.49 0.18 0.56]);
plot(alpha_grid, dist_to_one_bell, '-o', 'Color', [0 0.6 0], ...
    'LineWidth', 2.2, 'MarkerSize', 8, 'MarkerFaceColor', [0 0.6 0]);
hold off;
xlabel('Confidence Level \alpha', 'FontSize', 12);
ylabel('||\pi^*(\alpha) - \pi^*(1)||_1', 'FontSize', 12);
title('(a) Path distance to midpoint (\alpha=1)', 'FontSize', 12);
legend({sprintf('Uniform FOU (\\delta=%.2f): \\rho_{var}=%.3f', delta_uni, rho_var_bar_uni), ...
    sprintf('Bell FOU (\\delta=%.2f): heterogeneous \\rho', delta_bell)}, ...
    'Location', 'northeast', 'FontSize', 9);
grid on;

subplot(2, 1, 2);
hold on;
strategy_names = params_base.S;
colors_s = {[0 0.45 0.74], [0.85 0.33 0.10], [0.93 0.69 0.13], [0.49 0.18 0.56]};
for j = 1:params_base.num_strategies
    plot(alpha_grid, mass_bell(:, j), '-o', 'Color', colors_s{j}, ...
        'LineWidth', 1.8, 'MarkerSize', 6, 'MarkerFaceColor', colors_s{j});
end
hold off;
xlabel('Confidence Level \alpha', 'FontSize', 12);
ylabel('Population Strategy Mass', 'FontSize', 12);
title(sprintf('(b) Mass transfer: %s \\rightarrow %s', ...
    strategy_names{j_hi_pop}, strategy_names{j_lo_pop}), 'FontSize', 12);
legend(strategy_names, 'Location', 'east', 'FontSize', 9);
grid on;
apply_fig5_publication_style(gcf);
exportgraphics(gcf, fullfile(img_dir, 'fig5_13_theorem2.png'), 'Resolution', 300);
% 矢量 PDF: ContentType=vector 按内容边界裁剪, 无整页留白边框
exportgraphics(gcf, fullfile(img_dir, 'fig5_13_theorem2.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('\n[图] %s\n', fullfile('image', 'fig5_13_theorem2.png'));

sync_named_figures(img_dir, fullfile(script_dir, '..', 'Latex'), {
    'fig5_13_theorem2.png';
    'fig5_13_theorem2.pdf';
    });

%% 7) 表 5-4: α 网格汇总 (两条 FOU 路线的路径距离/逐步斜率/ρ̄_var)
T = table(alpha_grid', dist_to_one_uni, [NaN; step_slope_uni], rho_var_u, ...
    dist_to_one_bell, [NaN; step_slope], rho_var_g, ...
    mass_bell(:, 1), mass_bell(:, 2), mass_bell(:, 3), mass_bell(:, 4), ...
    'VariableNames', ...
    {'alpha', 'DistToOne_Uniform', 'StepSlope_Uniform', 'RhoVar_Uniform', ...
     'DistToOne_Bell', 'StepSlope_Bell', 'RhoVar_Bell', ...
     'Mass_SC', 'Mass_SP', 'Mass_DC', 'Mass_DP'});
csv_path = fullfile(tbl_dir, 'table5_4_alpha_path.csv');
writetable(T, csv_path);
fprintf('[表] %s\n', fullfile('table', 'table5_4_alpha_path.csv'));

%% 8) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) uniform FOU: 凹聚合下路径非退化 (ρ̄_var>0) 且 Lipschitz 正则 (斜率≤界)
%     线性聚合下 uniform FOU 才恒定; 凹聚合曲率使其 α-active 但仍受定理 2(i) 约束。
pass_i = (rho_var_bar_uni > 1e-6) && sat_ok_uni && ...
    all(step_slope_uni <= slope_bound_uni + 1e-9);
fprintf(['(i) uniform FOU 凹聚合非退化+Lipschitz 正则: ρ̄_var=%.4f (>0), ' ...
    'max 斜率 %.4f ≤ 界 %.4f %s\n'], rho_var_bar_uni, max(step_slope_uni), ...
    slope_bound_uni, pass_label(pass_i));

% (ii) bell FOU: 逐步斜率全部低于定理 3 理论界
pass_ii = all(step_slope <= slope_bound + 1e-9);
fprintf('(ii) bell FOU Lipschitz 界: max 斜率 %.4f ≤ 界 %.4f (紧致比 %.1f%%) %s\n', ...
    max(step_slope), slope_bound, 100 * max(step_slope) / slope_bound, ...
    pass_label(pass_ii));

% (iii) 似然比线性律: 实测斜率 = (Δρ)/λ (实现级一致性, 容差 0.1%)
pass_iii = (rel_err < 1e-3);
fprintf('(iii) FOU 规避斜率: 实测 %.6f vs 理论 %.6f, 相对误差 %.2e %s\n', ...
    slope_meas, slope_theory, rel_err, pass_label(pass_iii));

% (iv) 质量转移方向: 高 ρ 策略质量随 α 增加而单调不减 (允许数值容差)
diffs_hi = diff(mass_hi);
pass_iv = all(diffs_hi >= -1e-6) && (mass_hi(end) > mass_hi(1));
fprintf('(iv) 高 ρ 策略 (%s) 质量随 α 单调上升: %.4f → %.4f %s\n', ...
    strategy_names{j_hi_pop}, mass_hi(1), mass_hi(end), pass_label(pass_iv));

% (v) 端点一致性: α=1 时 α-cut 求解器与 Û 决策求解器重合
[pi_check, ~] = sec4_3_1_wfbri_solve(params_bell, delta_bell, theta);
endpoint_gap = sum(abs(pi_bell{end} - pi_check), 'all');
pass_v = (endpoint_gap < 1e-10);
fprintf('(v) 端点一致性: ||π*(1) - π_WFBRI||_1 = %.3e %s\n', ...
    endpoint_gap, pass_label(pass_v));

fprintf('\n===== 实验四完成 =====\n');

%% ====== 辅助函数 ======
function rho_mat = per_strategy_rho(pi_profile, delta, theta, params)
% PER_STRATEGY_RHO  每个 agent 每个纯策略的不确定半径 ρ_{i,j} (定理 3 记号)
%   ρ_{i,j} = ρ_i(δ_j, π_{-i}; θ): agent i 单边切换到纯策略 j 时的收益 FOU 半宽
    [~, ~, ~, rho_mat] = sec4_1_2_pure_interval_payoff_matrix( ...
        pi_profile, delta, theta, params);
end

function nu_i = alpha_lower_payoff_fixed(pi_profile, delta, theta, params, ...
    agent_idx, alpha)
% ALPHA_LOWER_PAYOFF_FIXED  固定 π_{-i} 下 agent i 的 α-cut 下界收益向量
%   ν_{i,j}^α = Û_i(δ_j, π_{-i}) - (1-α)·ρ_i(δ_j, π_{-i})
    [~, ~, U_hat, rho] = sec4_1_2_pure_interval_payoff_vector( ...
        pi_profile, delta, theta, params, agent_idx);
    nu_i = U_hat - (1 - alpha) * rho;
end

function s = pass_label(ok)
    if ok; s = '[PASS]'; else; s = '[WARN]'; end
end

function sync_named_figures(img_dir, latex_dir, names)
% 将仿真输出按原始描述性文件名同步到 LaTeX 目录。
    if ~exist(latex_dir, 'dir')
        return;
    end
    fprintf('[同步检查] MATLAB image -> Latex\n');
    for idx = 1:numel(names)
        name = names{idx};
        src_path = fullfile(img_dir, name);
        dst_path = fullfile(latex_dir, name);
        if exist(src_path, 'file')
            copyfile(src_path, dst_path);
            fprintf('  [SYNC] %s\n', name);
        else
            fprintf('  [MISS] %s\n', name);
        end
    end
end
