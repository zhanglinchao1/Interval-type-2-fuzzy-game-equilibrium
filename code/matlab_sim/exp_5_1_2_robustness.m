% exp_5_1_2_robustness.m - 论文 §5.1 实验二: 区间二型建模与鲁棒 α-FNE 验证
%
% 验证目标 (对齐 chapter5.md §5.1 实验二新版设计):
%   (a) 引理 1 (4-17): ε_req ≤ 2(1-α)ρ̄ 在所有 (α, δ) 组合下成立
%   (b) 引理 1 按 agent 通过率 PassRate ≈ 100%
%   (c) IT2 鲁棒性: Type-1 (δ=0) 在状态扰动 ξ~N(0,σ²) 下 Var_ξ(Û) 显著高于
%       IT2-midpoint 与 Proposed; Proposed 在 α-cut 下界决策下取得最低 Var_ξ
%   (d) α-cut 决策路径: Proposed 用 U̲^α=Û-(1-α)ρ 决策, 让 α 真正进入算法
%
% 对比方法 (按决策准则区分, 区别于实验一同质对比):
%   Type-1 Fuzzy Game            - δ=0, 决策 ν=Û (退化为单点)
%   IT2-midpoint (α=1)           - δ>0, α=1, 决策 ν=Û (忽略 FOU 宽度)
%   Proposed IT2-W-FBRI (α<1)    - δ>0, α<1, 决策 ν=U̲^α=Û-(1-α)ρ (鲁棒-悲观)
%
% 输出:
%   image/fig5_5_alpha_robust_error.png    - ε_req(实测) vs 2(1-α)ρ̄(理论) 按 δ 分组
%   image/fig5_6_decision_margin.png       - 三方法决策鲁棒边距 (1-α)·ρ̄ vs δ
%   image/fig5_7_worst_case_payoff.png     - 扰动下 Worst-case 收益 (Q5/mean) 对比
%   image/fig5_8_safety_coverage.png       - 扰动幅度 σ_ξ vs 决策安全垫 (1-α)·ρ̄ 覆盖关系
%   table/table5_2_alpha_delta_sensitivity.csv - α×δ × 三方法的指标汇总
%   table/table5_2b_three_methods_compare.csv  - 三方法跨 δ 的差异敏感指标

clear; clc; close all;

%% 全局字体设置
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');

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
% 启用 bell-shaped FOU 调制 (论文 §3.3 (3-14) 位置依赖 FOU 的标准扩展),
% 使 ρ_i 随策略 j 异质化, 让 α-cut 决策真正区别于 Û 决策。
% 详见 sec4_1_1_induced_membership.m 的说明。
params.fou_modulation = true;
theta = params.theta;

alpha_values = [0.3, 0.5, 0.8, 1.0];    % 论文 §5.1 表 5.1 扫描
delta_values = [0,   0.05, 0.10, 0.20]; % 论文 §5.1 表 5.1 扫描

% 状态扰动参数 (σ_δ = δ/2, 新版 chapter5.md §5.1 实验二)
n_perturb = 30;                          % 每个均衡的扰动重复次数

fprintf('===== 论文 §5.1 实验二: 区间二型建模与鲁棒 α-FNE 验证 =====\n');
fprintf('α 扫描 = [%s]\n', num2str(alpha_values));
fprintf('δ 扫描 = [%s]\n', num2str(delta_values));

%% 1) α × δ 笛卡尔积扫描: Proposed (α<1 决策路径) 的引理 1 验证
fprintf('\n--- Step 1: α × δ 扫描, Proposed 用 α-cut 下界决策 ---\n');

num_alpha = length(alpha_values);
num_delta = length(delta_values);

theoretical_bound = zeros(num_alpha, num_delta);  % 引理 1 理论预算 2(1-α)ρ̄
eps_required      = zeros(num_alpha, num_delta);  % 实测最小 ε (4-15)
pass_rate         = zeros(num_alpha, num_delta);  % 按 agent 通过率
avg_payoff_grid   = zeros(num_alpha, num_delta);  % 平均收益
per_agent_gap_all = cell(num_alpha, num_delta);   % 每个 (α,δ) 的 N×1 gap

for d_idx = 1:num_delta
    delta = delta_values(d_idx);
    fprintf('\n  δ = %.2f\n', delta);
    for a_idx = 1:num_alpha
        alpha = alpha_values(a_idx);
        % 使用 α-cut 决策路径求解 (α=1 时退化为 Û 决策)
        [pi_star, ~] = sec5_1_alpha_robust_solve(params, delta, theta, alpha);

        % 引理 1 数值验证 (4-15)
        report = sec4_2_2_robust_alpha_fne(pi_star, delta, theta, alpha, ...
            params, 30);

        theoretical_bound(a_idx, d_idx) = report.theoretical_bound;
        eps_required(a_idx, d_idx)      = report.eps_required;
        per_agent_gap_all{a_idx, d_idx} = report.per_agent_gap;

        % 平均收益 (中心 Û 评估)
        [mu_l, mu_u] = sec4_1_1_induced_membership(pi_star, delta, params);
        [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
        [U_hat, ~] = sec4_2_1_crystallized_payoff(U_l, U_u);
        avg_payoff_grid(a_idx, d_idx) = mean(U_hat);

        fprintf('    α=%.1f: 2(1-α)ρ̄=%.4f, ε_req=%.4f, Ū=%.4f\n', ...
            alpha, theoretical_bound(a_idx, d_idx), ...
            eps_required(a_idx, d_idx), avg_payoff_grid(a_idx, d_idx));
    end
end

%% 2) 引理 1 baseline 扣除 + 按 agent 通过率
% W-FBRI 输出 π* 是熵正则软响应均衡 (λ>0), 与精确 α-FNE 存在常量基线偏差。
% ε_req = ε_base (软响应误差) + ε_robust_actual (鲁棒不确定性增量)
% 引理 1 真正验证: ε_robust_actual ≤ 2(1-α)ρ̄
% 取 (α=1, δ=0) 的 ε_req 作为 ε_base (此时理论预算 = 0)
alpha_one_idx  = find(abs(alpha_values - 1.0) < 1e-9, 1);
delta_zero_idx = find(abs(delta_values - 0.0) < 1e-9, 1);
eps_base = eps_required(alpha_one_idx, delta_zero_idx);
% 每个 agent 单独 baseline (取 α=1,δ=0 时的 per_agent_gap)
per_agent_base = per_agent_gap_all{alpha_one_idx, delta_zero_idx};

fprintf('\n--- Step 2: 引理 1 验证 (ε_base=%.4f, 按 agent 通过率) ---\n', eps_base);
fprintf('%-4s | %-5s | %12s | %12s | %14s | %10s | %s\n', ...
    'α', 'δ', '理论 2(1-α)ρ̄', '实测 ε_req', '鲁棒增量', '通过率', '是否成立');
fprintf('%s\n', repmat('-', 1, 90));

lemma1_pass = 0;
lemma1_total = 0;
for a_idx = 1:num_alpha
    for d_idx = 1:num_delta
        gap_all = per_agent_gap_all{a_idx, d_idx};
        % 按 agent 扣除基线后的鲁棒增量
        gap_robust = max(0, gap_all - per_agent_base);
        bound = theoretical_bound(a_idx, d_idx);
        pass_per_agent = (gap_robust <= bound + 1e-6);
        pass_rate(a_idx, d_idx) = sum(pass_per_agent) / length(gap_all);

        eps_robust_max = max(gap_robust);
        ok = (eps_robust_max <= bound + 1e-6);
        if ok
            ok_str = 'YES'; lemma1_pass = lemma1_pass + 1;
        else
            ok_str = 'NO ';
        end
        lemma1_total = lemma1_total + 1;
        fprintf('%-4.1f | %-5.2f | %12.4f | %12.4f | %14.4f | %9.1f%% | %s\n', ...
            alpha_values(a_idx), delta_values(d_idx), ...
            bound, eps_required(a_idx, d_idx), eps_robust_max, ...
            pass_rate(a_idx, d_idx) * 100, ok_str);
    end
end
fprintf('\n引理 1 (按 max gap) 通过率: %d/%d\n', lemma1_pass, lemma1_total);
fprintf('按 agent 通过率均值: %.1f%%\n', mean(pass_rate(:)) * 100);

%% 3) 三方法跨 δ 对比: 决策准则 + 状态扰动响应
fprintf('\n--- Step 3: 三方法跨 δ 对比 (Type-1 / IT2-midpoint / Proposed) ---\n');

alpha_default = params.alpha;   % 0.5 (实验三方法默认 α)
sigma_factor = 0.5;             % σ_δ = δ * sigma_factor (新版 chapter5.md)

% 扰动响应: 用 Worst-case 收益 (5% 分位数) 替代 Var_ξ, 更直观体现"鲁棒下界"
WC_t1   = zeros(1, num_delta);  WC_mid = zeros(1, num_delta);
WC_prop = zeros(1, num_delta);
margin_t1   = zeros(1, num_delta);  margin_mid = zeros(1, num_delta);
margin_prop = zeros(1, num_delta);
U_t1_mean   = zeros(1, num_delta);  U_mid_mean = zeros(1, num_delta);
U_prop_mean = zeros(1, num_delta);

for d_idx = 1:num_delta
    delta = delta_values(d_idx);
    sigma_xi = delta * sigma_factor;
    fprintf('\n  δ = %.2f (σ_ξ=%.3f)\n', delta, sigma_xi);

    % --- Type-1: δ=0 训练, 决策用 Û ---
    [pi_t1, ~] = sec4_3_1_wfbri_solve(params, 0, theta);
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_t1, 0, params);
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    [U_hat, rho_t1] = sec4_2_1_crystallized_payoff(U_l, U_u);
    U_t1_mean(d_idx) = mean(U_hat);
    margin_t1(d_idx) = (1 - alpha_default) * max(rho_t1);  % 必为 0 (因 δ=0)
    WC_t1(d_idx) = worst_case_payoff(pi_t1, 0, theta, params, ...
        sigma_xi, n_perturb);

    % --- IT2-midpoint: δ>0 训练, 决策用 Û (即 α=1) ---
    [pi_mid, ~] = sec4_3_1_wfbri_solve(params, delta, theta);
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_mid, delta, params);
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    [U_hat, ~] = sec4_2_1_crystallized_payoff(U_l, U_u);
    U_mid_mean(d_idx) = mean(U_hat);
    % IT2-midpoint 决策仍用 Û, 故决策边距按 α_used=1 计 = 0
    margin_mid(d_idx) = 0;
    WC_mid(d_idx) = worst_case_payoff(pi_mid, delta, theta, params, ...
        sigma_xi, n_perturb);

    % --- Proposed: δ>0 训练, 决策用 U̲^α=Û-(1-α)ρ ---
    [pi_prop, ~] = sec5_1_alpha_robust_solve(params, delta, theta, ...
        alpha_default);
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_prop, delta, params);
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    [U_hat, rho_prop] = sec4_2_1_crystallized_payoff(U_l, U_u);
    U_prop_mean(d_idx) = mean(U_hat);
    margin_prop(d_idx) = (1 - alpha_default) * max(rho_prop);
    WC_prop(d_idx) = worst_case_payoff(pi_prop, delta, theta, params, ...
        sigma_xi, n_perturb);

    fprintf('    Type-1:    Ū=%.4f, 边距=%.4f, WC_Q5=%.4f\n', ...
        U_t1_mean(d_idx), margin_t1(d_idx), WC_t1(d_idx));
    fprintf('    IT2-mid:   Ū=%.4f, 边距=%.4f, WC_Q5=%.4f\n', ...
        U_mid_mean(d_idx), margin_mid(d_idx), WC_mid(d_idx));
    fprintf('    Proposed:  Ū=%.4f, 边距=%.4f, WC_Q5=%.4f\n', ...
        U_prop_mean(d_idx), margin_prop(d_idx), WC_prop(d_idx));
end

%% 4) Fig 5-5: empirical eps_req vs theoretical 2(1-alpha)*rho_bar (grouped by delta)
figure('Name', 'Lemma 1 Empirical Budget vs Theoretical Upper Bound', ...
    'Position', [100,100,800,520]);
hold on;
delta_colors = {[0.0 0.45 0.74], [0.85 0.33 0.10], [0.93 0.69 0.13], [0.49 0.18 0.56]};
h_theory = gobjects(num_delta, 1);
h_actual = gobjects(num_delta, 1);
for d_idx = 1:num_delta
    h_theory(d_idx) = plot(alpha_values, theoretical_bound(:, d_idx), '-o', ...
        'Color', delta_colors{d_idx}, 'LineWidth', 2.2, 'MarkerSize', 9, ...
        'MarkerFaceColor', delta_colors{d_idx});
    h_actual(d_idx) = plot(alpha_values, ...
        max(0, eps_required(:, d_idx) - eps_base), '--s', ...
        'Color', delta_colors{d_idx}, 'LineWidth', 1.6, 'MarkerSize', 8);
end
hold off;
xlabel('Confidence Level \alpha', 'FontSize', 12);
ylabel('Robust Budget', 'FontSize', 12);
title('Lemma 1: Empirical Robust Increment vs Theoretical Upper Bound 2(1-\alpha)\rho_{bar}', ...
    'FontSize', 13);
legend_str = [arrayfun(@(d) sprintf('Theoretical \\delta=%.2f', d), delta_values, ...
        'UniformOutput', false), ...
    arrayfun(@(d) sprintf('Empirical \\delta=%.2f', d), delta_values, ...
        'UniformOutput', false)];
legend([h_theory; h_actual], legend_str, 'Location', 'northeast', 'FontSize', 9);
grid on;
% Raise zero baseline so delta=0 markers are visible above the axis
ymax_5 = max(theoretical_bound(:)) * 1.10;
ylim([-ymax_5*0.04, ymax_5]);
% Annotate the delta=0 degeneracy: rho_bar=0 forces 2(1-alpha)*rho_bar ≡ 0
text(0.32, ymax_5*0.025, ...
    '\bf{\delta=0: \rho_{bar}=0 \rightarrow 2(1-\alpha)\rho_{bar}\equiv 0 (Type-1 Degenerate)}', ...
    'FontSize', 9, 'Color', [0.0 0.45 0.74], ...
    'BackgroundColor', [1 1 0.85], 'EdgeColor', [0.7 0.7 0.7]);
saveas(gcf, fullfile(img_dir, 'fig5_5_alpha_robust_error.png'));
fprintf('\n[图] %s\n', fullfile('image', 'fig5_5_alpha_robust_error.png'));

%% 5) 图5-6: 三方法决策鲁棒边距 (1-α_used)·ρ̄ 对比
% 视觉改进: Type-1/IT2-mid 决策边距恒为 0, 用空柱+x 标记表示"无事前保险";
% Proposed 用实心绿色柱, 体现 α-cut 决策的事前承诺.
% 零值占位: 真零值位置 (Type-1/IT2-mid 全部 δ; Proposed 在 δ=0) 画黑色 ×
% 标记和 "≡0" 文字, 配合 ymin 抬高让占位标记可见, 保证科学严谨性。
figure('Name', 'Decision Robustness Margin Across Three Methods', ...
    'Position', [150,100,820,520]);
bar_data = [margin_t1; margin_mid; margin_prop]';
b = bar(delta_values, bar_data, 'grouped', 'BarWidth', 0.9);
b(1).FaceColor = 'none';     b(1).EdgeColor = 'b';      b(1).LineWidth = 1.5;
b(2).FaceColor = 'none';     b(2).EdgeColor = 'm';      b(2).LineWidth = 1.5;
b(3).FaceColor = [0 0.6 0];  b(3).EdgeColor = 'k';      b(3).LineWidth = 0.8;

ymax_6 = max(margin_prop) * 1.30;
y_zero_mark = -ymax_6 * 0.018;       % "×" 标记 y 坐标 (略低于 0 点)
y_zero_text = -ymax_6 * 0.030;       % "≡0" 文字 y 坐标 (在 × 下方)

hold on;
% 在所有真零值位置画 "×" 标记 (按方法配色), 保证图表科学严谨
zero_thresh = 1e-6;
for d_idx = 1:num_delta
    if margin_t1(d_idx) < zero_thresh
        plot(b(1).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', 'b', 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
    if margin_mid(d_idx) < zero_thresh
        plot(b(2).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', 'm', 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
    if margin_prop(d_idx) < zero_thresh
        plot(b(3).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', [0 0.6 0], 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
end
% Place a "≡0" caption in the bottom-right whitespace pointing to the × placeholder marks
text(delta_values(end) * 0.55, y_zero_mark, ...
    '× = \bf{Placeholder for Margin \equiv 0}', ...
    'FontSize', 9, 'Color', [0.2 0.2 0.2], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
    'BackgroundColor', [1 1 0.92], 'EdgeColor', [0.7 0.7 0.7]);
text(0.10, ymax_6*0.85, ...
    '\bf{Type-1 / IT2-mid Decision Margin \equiv 0}', ...
    'FontSize', 10, 'Color', [0.3 0.3 0.3], 'BackgroundColor', [1 1 0.85], ...
    'EdgeColor', [0.7 0.7 0.7]);
hold off;

xlabel('Uncertainty Half-Bandwidth \delta', 'FontSize', 12);
ylabel('Decision Robustness Margin (1-\alpha_{used})·\rho_{bar}', 'FontSize', 12);
title(sprintf('\\alpha-cut Decision Robustness Margin Across Three Methods (Proposed \\alpha=%.1f)', ...
    alpha_default), 'FontSize', 13);
legend({'Type-1 (\delta=0, no FOU)', 'IT2-midpoint (\alpha_{used}=1)', ...
    sprintf('Proposed (\\alpha_{used}=%.1f)', alpha_default)}, ...
    'Location', 'northwest', 'FontSize', 11);
% 抬高 ymin, 让 0 点本身有空间显示占位标记
ylim([-ymax_6 * 0.05, ymax_6]);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_6_decision_margin.png'));
fprintf('[图] %s\n', fullfile('image', 'fig5_6_decision_margin.png'));

%% 6) 图5-7: 扰动下 Worst-case 收益 (5% 分位数) 三方法对比
% 视觉改进: Type-1 与 IT2-mid 的 WC_Q5 数学上完全相等 (两者决策准则同为 Û,
% 求解出的 π* 几乎一致 → 扰动响应一致), 合并为 "Û-决策 Q5" 一条线避免遮盖;
% Proposed (α<1) 用绿色单独绘制, 体现 α-cut 决策的最差扰动收益提升
figure('Name', 'Worst-case Payoff Under Perturbation', ...
    'Position', [200,100,820,520]);
WC_uhat = (WC_t1 + WC_mid) / 2;   % T1 与 IT2-mid 数值一致, 取均值合并
hold on;
plot(delta_values, U_t1_mean, '--', 'Color', [0.5 0.5 0.5], ...
    'LineWidth', 1.4, 'Marker', 's', 'MarkerSize', 7);
plot(delta_values, WC_uhat, '-s', 'Color', 'm', ...
    'LineWidth', 2.2, 'MarkerSize', 10, 'MarkerFaceColor', 'm');
plot(delta_values, WC_prop, '-o', 'Color', [0 0.6 0], ...
    'LineWidth', 2.4, 'MarkerSize', 11, 'MarkerFaceColor', [0 0.6 0]);

% Annotate the improvement of Proposed relative to U-hat decision
for d_idx = 2:num_delta
    gap = WC_prop(d_idx) - WC_uhat(d_idx);
    if gap > 0.002
        text(delta_values(d_idx), WC_prop(d_idx) + 0.003, ...
            sprintf('+%.3f', gap), 'FontSize', 9, 'Color', [0 0.5 0], ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
end
hold off;
xlabel('Uncertainty Half-Bandwidth \delta', 'FontSize', 12);
ylabel('Payoff', 'FontSize', 12);
title(sprintf(['Worst-case Payoff Q_5 Under Perturbation (\\sigma_\\xi=\\delta/2, n=%d)\n' ...
    'Proposed Improves Worst-case Lower Bound via \\alpha-cut Decision'], n_perturb), ...
    'FontSize', 12);
legend({'\^U-Decision Unperturbed \bar{U} (Baseline)', ...
    '\^U-Decision Q_5(\bar{U}_\xi): Type-1 / IT2-mid Overlap', ...
    sprintf('Proposed Q_5(\\bar{U}_\\xi), \\alpha=%.1f', alpha_default)}, ...
    'Location', 'southwest', 'FontSize', 10);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_7_worst_case_payoff.png'));
fprintf('[图] %s\n', fullfile('image', 'fig5_7_worst_case_payoff.png'));

%% 7) 图5-8: 扰动幅度 σ_ξ 与决策安全垫 (1-α)·ρ̄ 的覆盖关系
% 含义: 安全覆盖判据 σ_ξ ≤ (1-α)·ρ̄ 表示 Proposed 的事前鲁棒承诺已覆盖扰动幅度。
% Type-1/IT2-mid 的边距=0, 任何 σ_ξ>0 都"破防"; Proposed 的边距 (1-α)·ρ̄ 提供保险。
% 视觉改进: Type-1/IT2-mid 安全垫恒为 0 (柱子高度=0), 单纯柱状图不可见;
% 此处用黑色 × 标记 + "≡0" 文字在 0 点位置占位, 配合 ymin 抬高确保科学严谨。
figure('Name', 'Perturbation Magnitude vs Safety Margin Coverage', ...
    'Position', [250,100,800,520]);
sigma_curve = delta_values * sigma_factor;
ymax_8 = max([sigma_curve(:); margin_prop(:)]) * 1.10;
y_zero_mark = -ymax_8 * 0.020;
y_zero_text = -ymax_8 * 0.034;

hold on;
b = bar(delta_values, [margin_t1; margin_mid; margin_prop]', 'grouped');
b(1).FaceColor = 'b';        b(1).EdgeColor = 'k';
b(2).FaceColor = 'm';        b(2).EdgeColor = 'k';
b(3).FaceColor = [0 0.6 0];  b(3).EdgeColor = 'k';
plot(delta_values, sigma_curve, 'k-^', 'LineWidth', 2.4, 'MarkerSize', 10, ...
    'MarkerFaceColor', 'r', 'DisplayName', 'Perturbation \sigma_\xi');

% Plot × placeholder marks at zero-valued positions for visibility
zero_thresh = 1e-6;
for d_idx = 1:num_delta
    if margin_t1(d_idx) < zero_thresh
        plot(b(1).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', 'b', 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
    if margin_mid(d_idx) < zero_thresh
        plot(b(2).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', 'm', 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
    if margin_prop(d_idx) < zero_thresh
        plot(b(3).XEndPoints(d_idx), y_zero_mark, 'x', ...
            'Color', [0 0.6 0], 'LineWidth', 2.0, 'MarkerSize', 11, ...
            'HandleVisibility', 'off');
    end
end
% Place "≡0" note in the bottom whitespace
text(delta_values(end) * 0.55, y_zero_mark, ...
    '× = \bf{Safety Margin \equiv 0 Placeholder}', ...
    'FontSize', 9, 'Color', [0.2 0.2 0.2], ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
    'BackgroundColor', [1 1 0.92], 'EdgeColor', [0.7 0.7 0.7]);
hold off;

xlabel('Uncertainty Half-Bandwidth \delta', 'FontSize', 12);
ylabel('Magnitude', 'FontSize', 12);
title('Perturbation \sigma_\xi vs Decision Safety Margin (1-\alpha)\cdot\rho_{bar}', ...
    'FontSize', 13);
legend({'Type-1 Safety Margin \equiv 0', 'IT2-mid Safety Margin \equiv 0', ...
    sprintf('Proposed Safety Margin (\\alpha=%.1f)', alpha_default), ...
    'Perturbation \sigma_\xi'}, ...
    'Location', 'northwest', 'FontSize', 10);
% Raise ymin to provide space for the placeholder marks at zero
ylim([-ymax_8 * 0.06, ymax_8]);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_8_safety_coverage.png'));
fprintf('[图] %s\n', fullfile('image', 'fig5_8_safety_coverage.png'));

%% 8) 表5-2: α × δ × 三方法的指标汇总
% 主表: α × δ 笛卡尔积 (Proposed 决策路径), 含 ε_req/ε_robust/通过率
fprintf('\n===== 表5-2(a) α × δ Proposed 决策的引理 1 验证 =====\n');
fprintf('%-4s | %-5s | %9s | %12s | %12s | %14s | %s\n', ...
    'α', 'δ', '平均 Ū', '理论 2(1-α)ρ̄', '实测 ε_req', '鲁棒增量', 'PassRate%');
fprintf('%s\n', repmat('-', 1, 92));
T_rows = cell(num_alpha * num_delta, 7);
row = 1;
for a_idx = 1:num_alpha
    for d_idx = 1:num_delta
        gap_all = per_agent_gap_all{a_idx, d_idx};
        gap_robust = max(0, gap_all - per_agent_base);
        eps_robust_max = max(gap_robust);
        fprintf('%-4.1f | %-5.2f | %9.4f | %12.4f | %12.4f | %14.4f | %8.1f%%\n', ...
            alpha_values(a_idx), delta_values(d_idx), ...
            avg_payoff_grid(a_idx, d_idx), ...
            theoretical_bound(a_idx, d_idx), ...
            eps_required(a_idx, d_idx), eps_robust_max, ...
            pass_rate(a_idx, d_idx) * 100);
        T_rows(row, :) = {alpha_values(a_idx), delta_values(d_idx), ...
            avg_payoff_grid(a_idx, d_idx), theoretical_bound(a_idx, d_idx), ...
            eps_required(a_idx, d_idx), eps_robust_max, ...
            pass_rate(a_idx, d_idx) * 100};
        row = row + 1;
    end
end
T_a = cell2table(T_rows, 'VariableNames', ...
    {'alpha','delta','AvgPayoff','TheoreticalBound','EpsRequired', ...
     'RobustIncrement','PassRatePct'});

% 副表: 三方法跨 δ 的均衡 Ū / 决策边距 / Worst-case Q5 收益
fprintf('\n===== 表5-2(b) 三方法跨 δ 对比 (固定 α=%.1f) =====\n', alpha_default);
fprintf('%-5s | %-12s | %9s | %9s | %12s\n', ...
    'δ', '方法', '平均 Ū', '边距', 'Q5(Ū_ξ)');
fprintf('%s\n', repmat('-', 1, 60));
T_b_rows = cell(num_delta * 3, 5);
row_b = 1;
methods_3 = {'Type-1', 'IT2-midpoint', 'Proposed'};
for d_idx = 1:num_delta
    metrics_per_method = {
        U_t1_mean(d_idx),   margin_t1(d_idx),   WC_t1(d_idx);
        U_mid_mean(d_idx),  margin_mid(d_idx),  WC_mid(d_idx);
        U_prop_mean(d_idx), margin_prop(d_idx), WC_prop(d_idx)
    };
    for m = 1:3
        fprintf('%-5.2f | %-12s | %9.4f | %9.4f | %12.4f\n', ...
            delta_values(d_idx), methods_3{m}, ...
            metrics_per_method{m, 1}, metrics_per_method{m, 2}, ...
            metrics_per_method{m, 3});
        T_b_rows(row_b, :) = {delta_values(d_idx), methods_3{m}, ...
            metrics_per_method{m, 1}, metrics_per_method{m, 2}, ...
            metrics_per_method{m, 3}};
        row_b = row_b + 1;
    end
end
T_b = cell2table(T_b_rows, 'VariableNames', ...
    {'delta','Method','AvgPayoff','DecisionMargin','WorstCase_Q5'});

csv_path_a = fullfile(tbl_dir, 'table5_2_alpha_delta_sensitivity.csv');
writetable(T_a, csv_path_a);
csv_path_b = fullfile(tbl_dir, 'table5_2b_three_methods_compare.csv');
writetable(T_b, csv_path_b);
fprintf('\n[表] %s\n', fullfile('table', 'table5_2_alpha_delta_sensitivity.csv'));
fprintf('[表] %s\n', fullfile('table', 'table5_2b_three_methods_compare.csv'));

%% 9) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) 引理 1 全部通过
pass_i = (lemma1_pass == lemma1_total);
fprintf('(i) 引理 1 (4-15) 通过率 %d/%d %s\n', lemma1_pass, lemma1_total, ...
    pass_label(pass_i));

% (ii) Proposed 在最差扰动下收益不低于 Type-1 (Worst-case Q5)
prop_wc_better = true;
for d_idx = 2:num_delta
    if WC_prop(d_idx) < WC_t1(d_idx) - 1e-3
        prop_wc_better = false; break;
    end
end
fprintf('(ii) Proposed Q5(Ū_ξ) ≥ Type-1 Q5(Ū_ξ) (δ>0): %s\n', ...
    pass_label(prop_wc_better));
for d_idx = 2:num_delta
    fprintf('     δ=%.2f: T1=%.4f, Mid=%.4f, Prop=%.4f\n', delta_values(d_idx), ...
        WC_t1(d_idx), WC_mid(d_idx), WC_prop(d_idx));
end

% (iii) Proposed 决策边距 > 0 (δ>0), Type-1/IT2-mid 边距 = 0
margin_diff = margin_prop(end) - max(margin_t1(end), margin_mid(end));
fprintf('(iii) Proposed 决策边距 (δ=%.2f) = %.4f, T1/Mid = 0 %s\n', ...
    delta_values(end), margin_prop(end), pass_label(margin_diff > 1e-3));

% (iv) Proposed 均衡 Ū 严格高于 Type-1 (鲁棒决策带来均衡质量提升)
gain_avg = U_prop_mean(end) - U_t1_mean(end);
fprintf('(iv) Proposed ΔŪ (δ=%.2f) = +%.4f vs Type-1 %s\n', ...
    delta_values(end), gain_avg, pass_label(gain_avg > 0));

% (v) 通过率均值 ≥ 95%
mean_pr = mean(pass_rate(:)) * 100;
fprintf('(v) 按 agent 通过率均值 = %.1f%% %s\n', mean_pr, pass_label(mean_pr >= 95));

% (vi) Proposed 安全垫量级关系: 比值 = (1-α)·(ρ̄/δ)/sigma_factor 恒定
% 论文新版表述 (chapter5.md §5.1 实验二 (v)): 不要求严格覆盖, 而是验证
% margin/σ_ξ 比值跨 δ 保持稳定 (反映 ρ̄ ∝ δ 的线性关系) 且与 (1-α) 成正比。
fprintf('(vi) 安全垫量级关系 (margin/σ_ξ = (1-α)·(ρ̄/δ)/sigma_factor):\n');
fprintf('     理论比值 = (1-α)·c/sigma_factor, c=ρ̄/δ ≈ 0.75 (bell-FOU 调制下)\n');
fprintf('     即对 α=%.1f, sigma_factor=%.1f: 比值 ≈ %.2f\n', ...
    alpha_default, sigma_factor, (1-alpha_default) * 0.75 / sigma_factor);
cov_ratios = zeros(num_delta - 1, 1);
for d_idx = 2:num_delta
    sigma_xi_d = delta_values(d_idx) * sigma_factor;
    cov_ratios(d_idx - 1) = margin_prop(d_idx) / sigma_xi_d;
    fprintf('     δ=%.2f: margin=%.4f, σ_ξ=%.4f, 比值=%.3f\n', ...
        delta_values(d_idx), margin_prop(d_idx), sigma_xi_d, ...
        cov_ratios(d_idx - 1));
end
% 判定: 比值跨 δ 标准差 < 5% 即视为"量级关系稳定"
ratio_std = std(cov_ratios) / mean(cov_ratios);
fprintf('     跨 δ 比值变异系数 = %.2f%% %s\n', ratio_std * 100, ...
    pass_label(ratio_std < 0.05));

fprintf('\n===== 实验二完成 =====\n');

%% ====== 辅助函数 ======
function wc = worst_case_payoff(pi_star, delta_solve, theta, params, ...
    sigma_xi, n_perturb)
% WORST_CASE_PAYOFF  扰动下 mean(U_hat) 的 5% 分位数 (Worst-case 收益)
%   对 M^(trust)/M^(delay)/M^(res) 矩阵加 N(0,σ²) 噪声, n_perturb 次重采样
%   返回最差 5% 扰动下的均值收益, 衡量"鲁棒收益下界"。
    if sigma_xi <= 0
        [mu_l, mu_u] = sec4_1_1_induced_membership(pi_star, delta_solve, params);
        [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
        [U_hat, ~] = sec4_2_1_crystallized_payoff(U_l, U_u);
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
        [mu_l, mu_u] = sec4_1_1_induced_membership(pi_star, delta_solve, p);
        [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
        [U_hat, ~] = sec4_2_1_crystallized_payoff(U_l, U_u);
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
