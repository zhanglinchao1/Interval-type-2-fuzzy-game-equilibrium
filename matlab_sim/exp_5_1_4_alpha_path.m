% exp_5_1_4_alpha_path.m - 均衡路径与固定对手响应的独立检查
% 路径距离、网格斜率和半径变差均按采样结果报告。
% 固定对手时核验定理 2(ii) 的 log 似然比恒等式。
% uniform FOU: delta=0.10, lambda=0.15；bell FOU: delta=0.20, lambda=0.50。
% 输出沿用 image/fig5_13_theorem2 与 table/table5_4_alpha_path.csv。

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
delta_uni  = 0.10;
lambda_uni = params_base.lambda;     % 0.15，完整截断模型未获收缩认证

% Part B: bell FOU 配置
delta_bell  = 0.20;
lambda_bell = 0.50;

fprintf('===== 论文 §5.1 实验四: 均衡路径 α 正则性与 FOU 规避 (定理 2) =====\n');
fprintf('α 网格 = [%s]\n', num2str(alpha_grid, '%.1f '));

%% 1) Uniform FOU 的完整截断包络
[D_nu_uni, D_info] = sec4_3_1_kernel_variation_modulus( ...
    params_base, theta, delta_uni);
kappa_uni = D_nu_uni / (2 * lambda_uni);
fprintf('\n[Uniform FOU] D_nu=%.3f, D_sf=%.3f, kappa=%.3f\n', ...
    D_nu_uni, D_info.D_saturation_free, kappa_uni);

%% 2) Part A: uniform FOU 的实测均衡路径
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

% 半径变差是路径上的采样最大值。
rho_var_bar_uni = max(rho_var_u);
step_slope_uni = zeros(num_alpha - 1, 1);
for a_idx = 1:num_alpha - 1
    step_slope_uni(a_idx) = sum(abs(pi_uni{a_idx + 1} - pi_uni{a_idx}), 'all') / ...
        (alpha_grid(a_idx + 1) - alpha_grid(a_idx));
end
fprintf('  ρ̄_var=%.4f (>0: 曲率诱导), max_α ||π*(α)-π*(1)||_1 = %.4f\n', ...
    rho_var_bar_uni, max(dist_to_one_uni));
fprintf('  Empirical maximum path slope=%.4f; sampled clipping check=%d\n', ...
    max(step_slope_uni), sat_ok_uni);

%% 3) Part B: bell FOU 的实测均衡路径
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

% ρ̄_var 仅取已计算路径上的最大值。
rho_var_bar = max(rho_var_g);

% 逐步路径增量与斜率
step_dist  = zeros(num_alpha - 1, 1);
step_slope = zeros(num_alpha - 1, 1);
for a_idx = 1:num_alpha - 1
    step_dist(a_idx) = sum(abs(pi_bell{a_idx + 1} - pi_bell{a_idx}), 'all');
    step_slope(a_idx) = step_dist(a_idx) / ...
        (alpha_grid(a_idx + 1) - alpha_grid(a_idx));
end
dist_to_one_bell = cellfun(@(p) sum(abs(p - pi_bell{end}), 'all'), pi_bell);

fprintf('  Sampled radius spread=%.4f; empirical maximum path slope=%.4f\n', ...
    rho_var_bar, max(step_slope));

%% 4) Part C: 固定对手的软响应似然比
fprintf('\n--- Fixed-opponent response at the bell-FOU alpha=1 profile ---\n');
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

%% 5) Fig 5-13: 实测均衡路径与策略概率
figure('Name', 'Computed Equilibrium Paths', 'Position', [100,80,480,640]);

subplot(2, 1, 1);
hold on;
plot(alpha_grid, dist_to_one_uni, '-s', 'Color', [0.49 0.18 0.56], ...
    'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', [0.49 0.18 0.56]);
plot(alpha_grid, dist_to_one_bell, '-o', 'Color', [0 0.6 0], ...
    'LineWidth', 2.2, 'MarkerSize', 8, 'MarkerFaceColor', [0 0.6 0]);
hold off;
xlabel('Pessimism Parameter \alpha', 'FontSize', 12);
ylabel('||\pi^*(\alpha) - \pi^*(1)||_1', 'FontSize', 12);
title('(a) Path distance to midpoint (\alpha=1)', 'FontSize', 12);
legend({sprintf('Uniform FOU (\\delta=%.2f): sampled \\rho_{var}=%.3f', delta_uni, rho_var_bar_uni), ...
    sprintf('Bell FOU (\\delta=%.2f): heterogeneous \\rho', delta_bell)}, ...
    'Location', 'northeast', 'FontSize', 9);
ylim([0, 1.4 * max([dist_to_one_uni; dist_to_one_bell])]);
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
xlabel('Pessimism Parameter \alpha', 'FontSize', 12);
ylabel('Population Strategy Mass', 'FontSize', 12);
title('(b) Mean equilibrium strategy probabilities', 'FontSize', 12);
legend(strategy_names, 'Location', 'south', 'NumColumns', 4, 'FontSize', 9);
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

fprintf('(i) Uniform path: maximum distance=%.4f, grid slope=%.4f [empirical]\n', ...
    max(dist_to_one_uni), max(step_slope_uni));
fprintf('(ii) Bell path: maximum distance=%.4f, grid slope=%.4f [empirical]\n', ...
    max(dist_to_one_bell), max(step_slope));

% (iii) 似然比线性律: 实测斜率 = (Δρ)/λ (实现级一致性, 容差 0.1%)
pass_iii = (rel_err < 1e-3);
fprintf('(iii) FOU 规避斜率: 实测 %.6f vs 理论 %.6f, 相对误差 %.2e %s\n', ...
    slope_meas, slope_theory, rel_err, pass_label(pass_iii));

% (iv) 仅报告本配置网格上的概率变化方向。
diffs_hi = diff(mass_hi);
pass_iv = all(diffs_hi >= -1e-6) && (mass_hi(end) > mass_hi(1));
fprintf('(iv) Empirical %s probability: %.4f -> %.4f; grid-monotone=%d\n', ...
    strategy_names{j_hi_pop}, mass_hi(1), mass_hi(end), pass_iv);

% (v) 端点一致性: α=1 时 α-cut 求解器与 Û 决策求解器重合
[pi_check, ~] = sec4_3_1_wfbri_solve(params_bell, delta_bell, theta);
endpoint_gap = sum(abs(pi_bell{end} - pi_check), 'all');
pass_v = (endpoint_gap < 1e-10);
fprintf('(v) 端点一致性: ||π*(1) - π_WFBRI||_1 = %.3e %s\n', ...
    endpoint_gap, pass_label(pass_v));

fprintf('\n===== 实验四完成 =====\n');

%% ====== 辅助函数 ======
function rho_mat = per_strategy_rho(pi_profile, delta, theta, params)
% PER_STRATEGY_RHO  每个 agent 每个纯策略的不确定半径 ρ_{i,j} (定理 2 记号)
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
