% exp_5_1_3_dual_timescale.m - 论文 §5.1 实验三: 双时间尺度稳定性与 Fuzzy-ESS 验证
%
% 验证目标 (对齐 chapter5.md §5.1 实验三新版设计):
%   (i)   切空间最大对称特征值 λ_max^T < 0 在所有 ε_g 下成立 (定理 3 (4-34))
%   (ii)  终态参考能量沿耦合轨迹下降（数值诊断，不替代 A5 证明）
%   (iii) 固定物理时间下 d_slow 和 Osc 随 ε_g 增大, 反映时间尺度分离误差
%   (iv)  匹配慢时间运行到 ||g||_∞<g_tol 后记录 d_slow(tc)；仅作终点诊断
%   (v)   过大 ε_g (1e-2) 破坏时间尺度分离假设, 导致 Osc 与 d_slow 同步增大
%
% 关键指标 (差异敏感):
%   λ_max^T  - 雅可比对称部分在切空间最大特征值 (sec5_1_jacobian_lambda_max)
%   Osc(x;T_w) - 末窗口 (20% 时长) 平均振荡幅度 (sec5_1_oscillation)
%   d_slow(T)  - 终态与慢流形 x*(ω(T)) 距离 (sec5_1_slow_manifold)
%   ||g||_∞(T) - 治理驱动项末值
%
% 输出:
%   image/fig5_9_slow_manifold.png         - 慢流形跟踪误差 d_slow(t), 三 ε_g 叠加
%   image/fig5_10_governance_weights.png   - ω(h) 与 θ(h) 演化 (代表性 ε_g=1e-3)
%   image/fig5_11_lyapunov.png             - 终态参考能量下降曲线 (log scale)
%   image/fig5_12_eps_g_scaling.png        - 固定物理时间下 ε_g vs Osc/d_slow 诊断图
%   image/fig5_12_matched_slow_scaling.png - 匹配慢时间收敛点诊断图
%   table/table5_3_dual_timescale_stability.csv

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
params = config_params();
params.N = 50;
% T_evo × dt_evo = 100 (演化总时长), 让 ε_g × T × dt 在三个量级下产生可观差异:
%   ε_g=1e-4 → 0.01 (缓慢响应, 时间尺度分离严格)
%   ε_g=1e-3 → 0.10 (中等响应)
%   ε_g=1e-2 → 1.00 (快速响应, 破坏 A4 假设)
params.T_evo = 2000;
params.dt_evo = 0.05;

% --- 实验三专属参数覆盖 ---
% 设计目标: 构造内点稳定的快子系统, 使慢流形 x*(ω) 随治理权重移动。
% 对角线较低表示同类策略拥挤/竞争, 非对角交互较高表示异质协作收益;
% 三个矩阵分别强调 trust、delay、resource 维度下的协作互补性。
% 该设置避免顶点吸收导致 d_slow 在长时退化为数值零, 因而适合观察
% Proposition 4 所讨论的有限 epsilon_g 慢流形跟踪行为。
params.trust_matrix = [0.32, 0.82, 0.76, 0.70;
                       0.80, 0.34, 0.73, 0.68;
                       0.72, 0.69, 0.33, 0.77;
                       0.68, 0.65, 0.75, 0.34];
params.delay_matrix = [0.33, 0.86, 0.71, 0.68;
                       0.84, 0.32, 0.79, 0.73;
                       0.69, 0.77, 0.34, 0.81;
                       0.66, 0.74, 0.83, 0.33];
params.res_matrix   = [0.34, 0.70, 0.84, 0.79;
                       0.68, 0.35, 0.86, 0.81;
                       0.82, 0.84, 0.33, 0.75;
                       0.78, 0.80, 0.77, 0.34];

% P_pay 设计:
% 各列在三层权重上有温和差异, 让 ω 的慢演化改变内点 ESS 位置但不触发
% 跨 basin 跳变。
%   规则 1: trust 较高 (协作激励)
%   规则 2: delay 较高 (时效激励)
%   规则 3-4: res 强主导 (资源激励)
%   规则 5: 均衡 (保险项)
params.P_pay = [0.45, 0.30, 0.25, 0.20, 0.34;
                0.30, 0.45, 0.30, 0.25, 0.33;
                0.25, 0.25, 0.45, 0.55, 0.33];

eps_g_values = [1e-4, 1e-3, 1e-2];
num_eps = length(eps_g_values);

rng(params.rng_seed);
% 初始群体: 远离任一边界, 给快子系统充分演化空间
x0 = [0.30; 0.25; 0.25; 0.20];
x0 = x0 / sum(x0);

K = params.K;
% 初始治理状态: 偏向 res-heavy 规则 4 (适度), 让 ω 朝 σ(Δ) 平衡点演化
% 演化路径上 θ_res 始终 ≥ 0.45, DC 始终是 Fuzzy-ESS, 不跨 basin
omega0 = [0.15; 0.15; 0.15; 0.35; 0.20];
params.omega_init = omega0;
params.theta = params.P_pay * omega0;

% 末窗口 (后 20%) 长度
T_w = round(0.2 * params.T_evo);

fprintf('===== 论文 §5.1 实验三: 双时间尺度稳定性与 Fuzzy-ESS 验证 =====\n');
fprintf('T_evo = %d, dt = %.3f, K = %d, 末窗口 T_w = %d\n', ...
    params.T_evo, params.dt_evo, K, T_w);
fprintf('初始群体分布 x0 = [%.2f, %.2f, %.2f, %.2f]\n', x0);
fprintf('ε_g 扫描 = [%s]\n\n', num2str(eps_g_values));

%% ε_g 扫描
all_x_hist     = cell(num_eps, 1);
all_omega_hist = cell(num_eps, 1);
all_theta_hist = cell(num_eps, 1);
all_V_hist     = cell(num_eps, 1);
Osc_window     = zeros(num_eps, 1);
d_slow_T       = zeros(num_eps, 1);
g_inf_T        = zeros(num_eps, 1);
lambda_max_T   = zeros(num_eps, 1);
final_payoff   = zeros(num_eps, 1);
final_omega    = zeros(num_eps, K);
V_final        = zeros(num_eps, 1);
lyap_descent_ratio = zeros(num_eps, 1);
lambda_V_descent   = zeros(num_eps, 1);

for e_idx = 1:num_eps
    params.varepsilon_g = eps_g_values(e_idx);
    fprintf('--- ε_g = %.0e ---\n', eps_g_values(e_idx));

    [x_hist, omega_hist, theta_hist, V_hist] = sec4_4_4_dual_timescale(...
        x0, omega0, params);

    all_x_hist{e_idx}     = x_hist;
    all_omega_hist{e_idx} = omega_hist;
    all_theta_hist{e_idx} = theta_hist;
    all_V_hist{e_idx}     = V_hist;

    x_final = x_hist(end, :)';
    omega_final_vec = omega_hist(end, :)';
    theta_final = theta_hist(end, :)';

    % --- 指标 1: λ_max^T 切空间最大对称特征值 (定理 3) ---
    lambda_max_T(e_idx) = sec5_1_jacobian_lambda_max(x_final, theta_final, params);

    % --- 指标 2: Osc(x; T_w) 末窗口振荡幅度 ---
    Osc_window(e_idx) = sec5_1_oscillation(x_hist, T_w);

    % --- 指标 3: d_slow(T) 终态与慢流形距离 ---
    x_star_at_omega_T = sec5_1_slow_manifold(omega_final_vec, params, x0);
    d_slow_T(e_idx) = norm(x_final - x_star_at_omega_T, 2);

    % --- 指标 4: ||g||_∞(T) 治理驱动项末值 ---
    Delta_T = sec4_4_3_governance_performance(x_final, omega_final_vec, ...
        params.P_pay, params);
    sigma_T = sec3_2_bounded_sigma(Delta_T);
    g_T = sigma_T - omega_final_vec;
    g_inf_T(e_idx) = max(abs(g_T));

    % --- 辅助统计 ---
    U_j_final = sec4_4_1_population_payoff(x_final, theta_final, params);
    final_payoff(e_idx) = x_final' * U_j_final;
    final_omega(e_idx, :) = omega_final_vec';
    V_final(e_idx) = V_hist(end);

    dV = diff(V_hist);
    lyap_descent_ratio(e_idx) = sum(dV <= 1e-8) / length(dV);

    % V 的前半段几何衰减率: V(t) ≈ V(0) * (1-lambda_V)^t, lambda_V 越大下降越快
    V_safe = max(V_hist, 1e-12);
    half_idx = floor(length(V_safe) / 2);
    if V_safe(1) > 1e-10 && V_safe(half_idx) > 1e-12
        lambda_V_descent(e_idx, 1) = 1 - (V_safe(half_idx) / V_safe(1))^(1 / half_idx);
    else
        lambda_V_descent(e_idx, 1) = NaN;
    end

    fprintf('  λ_max^T      = %.4e   %s\n', lambda_max_T(e_idx), ...
        pass_label(lambda_max_T(e_idx) < 0));
    fprintf('  Osc(末%d步) = %.4e\n', T_w, Osc_window(e_idx));
    fprintf('  d_slow(T)    = %.4e   (x* = [%.3f %.3f %.3f %.3f])\n', ...
        d_slow_T(e_idx), x_star_at_omega_T);
    fprintf('  ||g||_∞(T)   = %.4e\n', g_inf_T(e_idx));
    fprintf('  最终 Ū       = %.6f\n', final_payoff(e_idx));
    fprintf('  最终 x       = [%.3f %.3f %.3f %.3f]\n', x_final);
    fprintf('  最终 ω       = [%.3f %.3f %.3f %.3f %.3f]\n', omega_final_vec);
    fprintf('  V(T)         = %.4e\n', V_final(e_idx));
    fprintf('  Lyap 下降率  = %.2f%%\n', lyap_descent_ratio(e_idx) * 100);
    fprintf('  λ_V 前半段衰减率 = %.4e\n\n', lambda_V_descent(e_idx));
end

%% Fig 5-9: Slow-manifold tracking error d_slow(t) (single-column, 3 eps_g overlaid)
% 三条 ε_g 叠加于一张单栏图: 群体对慢流形 x*(ω(t)) 的跟踪误差
%   d_slow(t) = ||x(t) - x*(ω(t))||_2
% 观察有限 ε_g 平台, 与 Table V 的 d_slow(T) 列搭配说明。
% 慢流形逐点求解成本较高, 故对轨迹子采样 n_sub 个点 (以 x(t) 暖启动加速)。
figure('Name', 'Slow-Manifold Tracking', 'Position', [100, 100, 470, 340]);
eps_colors = {[0.0 0.45 0.74], [0.85 0.33 0.10], [0.47 0.67 0.19]};
eps_styles = {'-', '--', ':'};
n_sub = 70;
leg_entries = cell(num_eps, 1);
hold on;
for e_idx = 1:num_eps
    x_hist_e     = all_x_hist{e_idx};
    omega_hist_e = all_omega_hist{e_idx};
    T_e = size(x_hist_e, 1);
    idx_sub = unique(round(linspace(1, T_e, n_sub)));
    t_sub = idx_sub(:) * params.dt_evo;
    d_sub = zeros(numel(idx_sub), 1);
    for q = 1:numel(idx_sub)
        tt = idx_sub(q);
        x_star_tt = sec5_1_slow_manifold(omega_hist_e(tt, :)', params, ...
            x_hist_e(tt, :)');
        d_sub(q) = norm(x_hist_e(tt, :)' - x_star_tt, 2);
    end
    d_sub = max(d_sub, 1e-12);
    plot(t_sub, d_sub, eps_styles{e_idx}, 'Color', eps_colors{e_idx}, ...
        'LineWidth', 2.2);
    leg_entries{e_idx} = sprintf('\\epsilon_g = 10^{%d}', ...
        round(log10(eps_g_values(e_idx))));
end
hold off;
set(gca, 'YScale', 'log');   % 平台跨越多个数量级, 三条曲线方可分辨
ylim([1e-7, 1e-1]);
xlabel('Evolution Time t');
ylabel('Slow-manifold distance d_{slow}(t)');
legend(leg_entries, 'Location', 'northeast');
grid on; box on;
apply_fig5_publication_style(gcf);
saveas(gcf, fullfile(img_dir, 'fig5_9_slow_manifold.png'));
% 矢量 PDF: exportgraphics 默认按内容边界裁剪, 无整页留白边框
exportgraphics(gcf, fullfile(img_dir, 'fig5_9_slow_manifold.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_9_slow_manifold.png'));

%% 图5-10: 治理权重 ω(h) 与收益层权重 θ(h) 演化 (代表性 ε_g=1e-3)
default_idx = 2;
omega_hist_plot = all_omega_hist{default_idx};
theta_hist_plot = all_theta_hist{default_idx};
T_plot = size(omega_hist_plot, 1);
t_axis = (1:T_plot) * params.dt_evo;

figure('Name', 'Governance Weight Evolution', 'Position', [150, 100, 900, 420]);

subplot(1, 2, 1);
hold on;
for ell = 1:K
    plot(t_axis, omega_hist_plot(:, ell), 'LineWidth', 1.8);
end
hold off;
xlabel('Slow-Timescale Period t', 'FontSize', 11);
ylabel('\omega_l(h)', 'FontSize', 12);
title('Governance Weight \omega(h) Evolution', 'FontSize', 12);
legend(arrayfun(@(k) sprintf('\\omega_%d', k), 1:K, 'UniformOutput', false), ...
    'Location', 'east', 'FontSize', 9);
grid on;

subplot(1, 2, 2);
theta_labels = {'\theta_{trust}', '\theta_{delay}', '\theta_{res}'};
theta_colors = {'b', 'r', [0 0.6 0]};
hold on;
for k = 1:3
    plot(t_axis, theta_hist_plot(:, k), '-', ...
        'Color', theta_colors{k}, 'LineWidth', 2.2);
end
hold off;
xlabel('Slow-Timescale Period t', 'FontSize', 11);
ylabel('\theta_k(h)', 'FontSize', 12);
title('Payoff Weight \theta(h) Evolution', 'FontSize', 12);
legend(theta_labels, 'Location', 'east', 'FontSize', 11);
grid on;

sgtitle(sprintf(['Governance Weight \\omega(h) and \\theta(h) Slow-Timescale Trajectory ' ...
    '(\\epsilon_g=10^{-3}, \\epsilon_g\\cdot T\\cdot dt=%.2f)'], ...
    eps_g_values(default_idx) * params.T_evo * params.dt_evo), 'FontSize', 12);
apply_fig5_publication_style(gcf);
saveas(gcf, fullfile(img_dir, 'fig5_10_governance_weights.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_10_governance_weights.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_10_governance_weights.png'));

%% Fig 5-11: Joint Lyapunov V(x, omega) descent curve (grouped by eps_g, log scale)
% 单栏竖排子图(a): 画布缩到 ~480px 使正文 \columnwidth 下字号 >=8pt; (a)/(b) 标签置于图内顶部, 全局一致
figure('Name', 'Joint Lyapunov Descent', 'Position', [200, 100, 480, 330]);
eps_colors = {[0.0 0.45 0.74], [0.85 0.33 0.10], [0.49 0.18 0.56]};
hold on;
for e_idx = 1:num_eps
    V_curve = max(all_V_hist{e_idx}, 1e-12);
    plot(1:length(V_curve), V_curve, '-', ...
        'Color', eps_colors{e_idx}, 'LineWidth', 1.8);
end
hold off;
set(gca, 'YScale', 'log');
xlabel('Evolution Time Step', 'FontSize', 12);
ylabel('Joint Lyapunov V(x, \omega)', 'FontSize', 12);
title('(a) Joint Lyapunov descent', 'FontSize', 12);
legend(arrayfun(@(e) sprintf('\\epsilon_g = 10^{%d}', round(log10(e))), ...
    eps_g_values, 'UniformOutput', false), ...
    'Location', 'southwest', 'FontSize', 11);
grid on;
apply_fig5_publication_style(gcf);
saveas(gcf, fullfile(img_dir, 'fig5_11_lyapunov.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_11_lyapunov.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_11_lyapunov.png'));

%% Fig 5-12: Fixed-wall-time terminal metrics vs eps_g (diagnostic)
figure('Name', 'Terminal Metrics Scaling Law', 'Position', [250, 100, 900, 520]);

% Fit slope in log-log: log(metric) = slope * log(eps_g) + intercept
log_eps = log10(eps_g_values(:));
log_osc = log10(max(Osc_window, 1e-16));
log_dsl = log10(max(d_slow_T, 1e-16));
p_osc = polyfit(log_eps, log_osc, 1);
p_dsl = polyfit(log_eps, log_dsl, 1);

hold on;
loglog(eps_g_values, Osc_window, 's-', 'Color', [0.0 0.45 0.74], ...
    'LineWidth', 2.2, 'MarkerSize', 12, 'MarkerFaceColor', [0.0 0.45 0.74]);
loglog(eps_g_values, d_slow_T, 'o-', 'Color', [0.85 0.33 0.10], ...
    'LineWidth', 2.2, 'MarkerSize', 12, 'MarkerFaceColor', [0.85 0.33 0.10]);
% O(eps_g) reference line (slope = 1)
ref_y_at_min = min(Osc_window) * (eps_g_values / eps_g_values(1));
loglog(eps_g_values, ref_y_at_min, 'k--', 'LineWidth', 1.4);
hold off;
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('Governance Step Size \epsilon_g', 'FontSize', 12);
ylabel('Terminal Metrics', 'FontSize', 12);
title(sprintf(['Log-Log Scaling Law of Terminal Metrics vs \\epsilon_g\n' ...
    'Osc slope\\approx%.2f, d_{slow} slope\\approx%.2f (first-order=1, ' ...
    'gap from \\sigma(\\Delta) saturation)'], p_osc(1), p_dsl(1)), 'FontSize', 11);
legend({sprintf('Osc(x; T_w), slope=%.2f', p_osc(1)), ...
        sprintf('d_{slow}(T), slope=%.2f', p_dsl(1)), ...
        'O(\epsilon_g) Reference (slope=1, strict only as \epsilon_g\rightarrow 0)'}, ...
    'Location', 'southeast', 'FontSize', 10);
% Annotate saturation effect
text(eps_g_values(1) * 1.5, max(d_slow_T) * 0.5, ...
    {'\bf{Monotone Scaling Preserved:}', ...
     sprintf('\\epsilon_g\\uparrow 10^2 \\Rightarrow d_{slow}\\uparrow %.1fx', ...
        d_slow_T(end)/d_slow_T(1)), ...
     'Sub-first-order reflects \sigma(\Delta) softmax higher-order residual'}, ...
    'FontSize', 9, 'Color', [0.3 0.3 0.3], ...
    'BackgroundColor', [1 1 0.85]);
grid on;
apply_fig5_publication_style(gcf);
saveas(gcf, fullfile(img_dir, 'fig5_12_eps_g_scaling.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_12_eps_g_scaling.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_12_eps_g_scaling.png'));

%% Fig 5-12b: Matched slow-time convergence-point diagnostic
% 固定 wall-time 只验证快变量贴近慢流形, 不能证明慢变量已到 g=0。
% 这里按慢时间 t_g = epsilon_g * t 运行到 ||g||_inf < g_tol, 在收敛点测
% d_slow。最小 ε_g 下可能进入数值误差地板，因此不把三点斜率当作定理验证。
g_tol_match = 1e-3;
t_g_cap = 6.0;
dt_match = params.dt_evo;
matched_steps = zeros(num_eps, 1);
matched_tg = zeros(num_eps, 1);
matched_g_inf = zeros(num_eps, 1);
matched_d_slow = zeros(num_eps, 1);
matched_payoff = zeros(num_eps, 1);
matched_converged = false(num_eps, 1);

fprintf('\n--- Matched slow-time convergence measurement ---\n');
for e_idx = 1:num_eps
    eps_g = eps_g_values(e_idx);
    match_report = simulate_matched_slow_time(x0, omega0, params, eps_g, ...
        dt_match, g_tol_match, t_g_cap);
    matched_steps(e_idx) = match_report.steps;
    matched_tg(e_idx) = match_report.slow_time;
    matched_g_inf(e_idx) = match_report.g_inf;
    matched_d_slow(e_idx) = match_report.d_slow;
    matched_payoff(e_idx) = match_report.payoff;
    matched_converged(e_idx) = match_report.converged;
    fprintf('  ε_g=%.0e: steps=%d, t_g=%.3f, ||g||_∞=%.3e, d_slow=%.3e %s\n', ...
        eps_g, matched_steps(e_idx), matched_tg(e_idx), ...
        matched_g_inf(e_idx), matched_d_slow(e_idx), ...
        pass_label(matched_converged(e_idx)));
end

log_dslow_match = log10(max(matched_d_slow, 1e-16));
p_dslow_match = polyfit(log_eps, log_dslow_match, 1);

figure('Name', 'Matched Slow-Time Diagnostic', ...
    'Position', [260, 100, 480, 330]);
hold on;
loglog(eps_g_values, matched_d_slow, 'o-', ...
    'Color', [0.0 0.45 0.74], 'LineWidth', 2.4, ...
    'MarkerSize', 11, 'MarkerFaceColor', [0.0 0.45 0.74]);
ref_match = matched_d_slow(1) * (eps_g_values / eps_g_values(1));
loglog(eps_g_values, ref_match, 'k--', 'LineWidth', 1.6);
hold off;
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('Governance Step Size \epsilon_g', 'FontSize', 12);
ylabel('Convergence-point d_{slow}', 'FontSize', 12);
title('(b) Matched slow-time diagnostic', 'FontSize', 12);
legend({sprintf('d_{slow}(t_c), descriptive slope=%.2f', ...
        p_dslow_match(1)), 'Linear reference (guide only)'}, ...
        'Location', 'northwest', 'FontSize', 10);
grid on;
apply_fig5_publication_style(gcf);
exportgraphics(gcf, fullfile(img_dir, 'fig5_12_matched_slow_scaling.png'), ...
    'Resolution', 300, 'BackgroundColor', 'white');
exportgraphics(gcf, fullfile(img_dir, 'fig5_12_matched_slow_scaling.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_12_matched_slow_scaling.png'));

sync_named_figures(img_dir, fullfile(script_dir, '..', 'Latex'), {
    'fig5_9_slow_manifold.png';
    'fig5_9_slow_manifold.pdf';
    'fig5_10_governance_weights.png';
    'fig5_10_governance_weights.pdf';
    'fig5_11_lyapunov.png';
    'fig5_11_lyapunov.pdf';
    'fig5_12_eps_g_scaling.png';
    'fig5_12_eps_g_scaling.pdf';
    'fig5_12_matched_slow_scaling.png';
    'fig5_12_matched_slow_scaling.pdf';
    });

%% 表5-3: 双时间尺度稳定性指标汇总
fprintf('\n===== 表5-3 双时间尺度稳定性指标汇总 =====\n');
fprintf('%-9s | %12s | %12s | %12s | %12s | %12s | %12s | %10s | %s\n', ...
    'ε_g', 'λ_max^T', 'Osc(T_w)', 'd_slow(T)', '||g||_∞(T)', ...
    'd_slow(tc)', '||g||∞(tc)', '最终 Ū', '最终 ω');
fprintf('%s\n', repmat('-', 1, 140));
T_rows = cell(num_eps, 11);
for e_idx = 1:num_eps
    om_str = sprintf('[%.3f %.3f %.3f %.3f %.3f]', final_omega(e_idx, :));
    fprintf('%-9.0e | %12.4e | %12.4e | %12.4e | %12.4e | %12.4e | %12.4e | %10.6f | %s\n', ...
        eps_g_values(e_idx), lambda_max_T(e_idx), ...
        Osc_window(e_idx), d_slow_T(e_idx), g_inf_T(e_idx), ...
        matched_d_slow(e_idx), matched_g_inf(e_idx), final_payoff(e_idx), om_str);
    T_rows(e_idx, :) = {eps_g_values(e_idx), lambda_max_T(e_idx), ...
        Osc_window(e_idx), d_slow_T(e_idx), g_inf_T(e_idx), ...
        matched_d_slow(e_idx), matched_g_inf(e_idx), matched_tg(e_idx), ...
        matched_steps(e_idx), final_payoff(e_idx), om_str};
end
T = cell2table(T_rows, 'VariableNames', ...
    {'epsilon_g', 'LambdaMaxTangent', 'Oscillation_Tw', 'DSlow_T', ...
     'GInfNorm_T', 'MatchedDSlow', 'MatchedGInfNorm', 'MatchedSlowTime', ...
     'MatchedSteps', 'FinalAvgPayoff', 'FinalOmega'});
csv_path = fullfile(tbl_dir, 'table5_3_dual_timescale_stability.csv');
writetable(T, csv_path);
fprintf('\n[表] %s\n', fullfile('table', 'table5_3_dual_timescale_stability.csv'));

% A2/A5 局部 premise diagnostics：只评价代表性轨迹终点，不外推为全局证书。
omega_diag = final_omega(2, :)';
premise = sec5_1_premise_diagnostics(omega_diag, params);
Tp = table(premise.L_sigma_local, premise.c_omega_local, ...
    premise.lambda_max_tangent, premise.fast_margin_local, ...
    premise.reduced_residual_inf, premise.basin_spread, ...
    premise.num_basin_initializations, premise.governance_basin_spread, ...
    premise.num_governance_initializations, ...
    premise.fixed_point_iterations, premise.global_certificate, ...
    premise.epsilon_g_threshold, ...
    'VariableNames', {'L_sigma_local','c_omega_local', ...
    'LambdaMaxTangentLocal','FastMarginLocal','ReducedResidualInf', ...
    'FastBasinSpread','NumFastInitializations', ...
    'GovernanceBasinSpread','NumGovernanceInitializations', ...
    'FixedPointIterations','GlobalCertificate', ...
    'CertifiedEpsilonGThreshold'});
writetable(Tp, fullfile(tbl_dir, 'table5_3b_premise_diagnostics.csv'));
fprintf('[表] %s\n', fullfile('table', ...
    'table5_3b_premise_diagnostics.csv'));
fprintf(['[局部前提诊断] L_sigma=%.4f, c_omega=%.4g, fast/governance ' ...
    'basin spread=[%.3e, %.3e]; ' ...
    'global certificate=%d\n'], premise.L_sigma_local, ...
    premise.c_omega_local, premise.basin_spread, ...
    premise.governance_basin_spread, ...
    premise.global_certificate);

%% 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) λ_max^T < 0 在所有 ε_g 下成立 (定理 3 (4-34))
all_negative = all(lambda_max_T < 0);
fprintf('(i)   λ_max^T < 0 (定理 3 切空间负定): %s\n', pass_label(all_negative));
for e_idx = 1:num_eps
    fprintf('      ε_g=%.0e: λ_max^T = %+.4e\n', ...
        eps_g_values(e_idx), lambda_max_T(e_idx));
end

% (ii) 终态参考能量下降；这是轨迹诊断，不替代 A5/Lyapunov 证明
all_descent_ratio_ok = all(lyap_descent_ratio >= 0.95);
v_collapse_ok = true;
for e_idx = 1:num_eps
    V_curve = all_V_hist{e_idx};
    if V_curve(1) <= V_curve(end) * 10
        v_collapse_ok = false;
    end
end
fprintf('(ii)  终态参考能量下降 (≥95%%) 且 V(0) >> V(T): %s [诊断]\n', ...
    pass_label(all_descent_ratio_ok && v_collapse_ok));
for e_idx = 1:num_eps
    V_curve = all_V_hist{e_idx};
    fprintf('      ε_g=%.0e: 下降率=%.2f%%, V(0)=%.4e, V(T)=%.4e, λ_V_half=%.4e\n', ...
        eps_g_values(e_idx), lyap_descent_ratio(e_idx) * 100, ...
        V_curve(1), V_curve(end), lambda_V_descent(e_idx));
end

% (iii) Osc 和 d_slow 随 ε_g 单调递增; 双对数斜率 ∈ [0.1, 1.0]
osc_monotone_inc = (Osc_window(1) <= Osc_window(2) + 1e-10) && ...
                   (Osc_window(2) <= Osc_window(3) + 1e-10);
dsl_monotone_inc = (d_slow_T(1)  <= d_slow_T(2)  + 1e-10) && ...
                   (d_slow_T(2)  <= d_slow_T(3)  + 1e-10);
slope_range_osc = p_osc(1) >= 0.1 && p_osc(1) <= 1.2;
slope_range_dsl = p_dsl(1) >= 0.1 && p_dsl(1) <= 1.2;
fprintf('(iii) Osc 和 d_slow 随 ε_g 单调递增 (O(ε_g) 邻域弱化):\n');
fprintf('      Osc 单调:  %s, 斜率 = %.3f %s\n', ...
    pass_label(osc_monotone_inc), p_osc(1), pass_label(slope_range_osc));
fprintf('      d_slow 单调: %s, 斜率 = %.3f %s\n', ...
    pass_label(dsl_monotone_inc), p_dsl(1), pass_label(slope_range_dsl));

% (iii-b) 匹配慢时间: 只检查均到达同一治理残差阈值。
matched_all_converged = all(matched_converged) && all(matched_g_inf < g_tol_match);
fprintf('(iii-b) 匹配慢时间均到达治理残差阈值: %s\n', ...
    pass_label(matched_all_converged));
fprintf('        descriptive slope(d_slow(tc)) = %.3f, g_tol = %.1e; 不作阶数判定\n', ...
    p_dslow_match(1), g_tol_match);
for e_idx = 1:num_eps
    fprintf('        ε_g=%.0e: t_g=%.3f, ||g||_∞=%.3e, d_slow=%.3e\n', ...
        eps_g_values(e_idx), matched_tg(e_idx), ...
        matched_g_inf(e_idx), matched_d_slow(e_idx));
end

% (iv) ||g||_∞(T) 在 ε_g 较大时趋近 0 (ω 演化到 σ 平衡点)
g_monotone_dec = (g_inf_T(1) >= g_inf_T(2) - 1e-4) && ...
                 (g_inf_T(2) >= g_inf_T(3) - 1e-3);
g_smallest_at_max_eps = (g_inf_T(end) < g_inf_T(1) / 2);
fprintf('(iv)  ||g||_∞(T) 在 ε_g 大时趋近 0 (σ 平衡): %s\n', ...
    pass_label(g_monotone_dec && g_smallest_at_max_eps));
for e_idx = 1:num_eps
    fprintf('      ε_g=%.0e: ||g||_∞ = %.4e\n', ...
        eps_g_values(e_idx), g_inf_T(e_idx));
end

% (v) ε_g=1e-2 (最大) 同步增大 Osc 和 d_slow (破坏 A4 时间尺度分离)
osc_amp_factor = Osc_window(end) / max(Osc_window(1), 1e-16);
dsl_amp_factor = d_slow_T(end)  / max(d_slow_T(1),  1e-16);
osc_v_passed = osc_amp_factor >= 1.5;
dsl_v_passed = dsl_amp_factor >= 1.5;
fprintf('(v)   过大 ε_g=1e-2 同步增大 Osc/d_slow: %s\n', ...
    pass_label(osc_v_passed && dsl_v_passed));
fprintf('      Osc:    ε_g=1e-4 %.2e → ε_g=1e-2 %.2e (放大 %.2fx)\n', ...
    Osc_window(1), Osc_window(end), osc_amp_factor);
fprintf('      d_slow: ε_g=1e-4 %.2e → ε_g=1e-2 %.2e (放大 %.2fx)\n', ...
    d_slow_T(1), d_slow_T(end), dsl_amp_factor);

fprintf('\n===== 实验三完成 =====\n');

%% ====== 辅助函数 ======
function report = simulate_matched_slow_time(x0, omega0, params, eps_g, ...
    dt, g_tol, t_g_cap)
%SIMULATE_MATCHED_SLOW_TIME  按慢时间运行到治理驱动收敛。
%   t_g = epsilon_g * t; 在 ||sigma(Delta)-omega||_inf < g_tol 时记录
%   慢流形偏差 d_slow；结果用于终点诊断，不单独证明渐近阶数。
    max_steps = ceil(t_g_cap / max(eps_g * dt, eps));
    x = x0(:);
    omega = omega0(:);
    converged = false;

    for step = 1:max_steps
        theta = params.P_pay * omega;
        theta = max(theta, 0);
        if sum(theta) > 0
            theta = theta / sum(theta);
        else
            theta = ones(3, 1) / 3;
        end

        U_j = sec4_4_1_population_payoff(x, theta, params);
        U_bar = x' * U_j;
        dx = x .* (U_j - U_bar);
        x_next = x + dt * dx;
        x_next = max(x_next, 1e-10);
        x_next = x_next / sum(x_next);

        Delta_h = sec4_4_3_governance_performance(x_next, omega, ...
            params.P_pay, params);
        sigma_Delta = sec3_2_bounded_sigma(Delta_h);
        g = sigma_Delta - omega;
        g_inf = max(abs(g));

        omega_next = omega + eps_g * dt * g;
        omega_next = sec3_2_project_simplex(omega_next);

        x = x_next;
        omega = omega_next;

        if g_inf < g_tol
            converged = true;
            break;
        end
    end

    x_star = sec5_1_slow_manifold(omega, params, x);
    theta = params.P_pay * omega;
    theta = max(theta, 0);
    theta = theta / sum(theta);
    U_j = sec4_4_1_population_payoff(x, theta, params);

    report.steps = step;
    report.slow_time = eps_g * step * dt;
    report.g_inf = g_inf;
    report.d_slow = norm(x - x_star, 2);
    report.payoff = x' * U_j;
    report.converged = converged;
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
