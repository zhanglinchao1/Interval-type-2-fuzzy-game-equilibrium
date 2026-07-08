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
        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, delta, theta, params);
        avg_payoff_grid(a_idx, d_idx) = mean(U_hat);

        fprintf('    α=%.1f: 2(1-α)ρ̄=%.4f, ε_req=%.4f, Ū=%.4f\n', ...
            alpha, theoretical_bound(a_idx, d_idx), ...
            eps_required(a_idx, d_idx), avg_payoff_grid(a_idx, d_idx));
    end
end

%% 2) 引理 1 baseline 扣除 + 按 agent 通过率
% W-FBRI 输出 π* 是熵正则软响应均衡 (λ>0), 与精确 α-FNE 存在常量基线偏差。
% ε_req = ε_base(δ) (软响应误差 + 中心偏移) + ε_robust_actual (α-cut 半径增量)
% 引理 1 真正验证: ε_robust_actual ≤ 2(1-α)ρ̄
%
% 注 (Route C): 引理 1 比较的是"同一 δ 下 α-cut 相对中点 (α=1) 的半径预算"。
% 在凹聚合 + bell-FOU 下, 类型缩减中心随策略异质偏移 -Σθδ_eff², 因此 α=1 的中点
% 收益本身已含 δ 相关偏移。基线必须按"同 δ 的 α=1 行"扣除 (而非固定 (α=1,δ=0)),
% 才能正确剥离中心偏移、只保留 α-cut 半径增量。线性聚合下中心与 δ 无关, 两种基线
% 等价; 凹聚合下必须用按-δ 基线 (否则 α=1 行会因中心偏移残差出现 0 预算的伪违反)。
alpha_one_idx  = find(abs(alpha_values - 1.0) < 1e-9, 1);
delta_zero_idx = find(abs(delta_values - 0.0) < 1e-9, 1);
eps_base = eps_required(alpha_one_idx, delta_zero_idx);
% 每个 δ 列单独的 α=1 baseline (按-δ 中点基线, 见上)
per_agent_base_byd = per_agent_gap_all(alpha_one_idx, :);  % 1×num_delta cell

fprintf('\n--- Step 2: 引理 1 验证 (按-δ 中点基线, 按 agent 通过率) ---\n');
fprintf('%-4s | %-5s | %12s | %12s | %14s | %10s | %s\n', ...
    'α', 'δ', '理论 2(1-α)ρ̄', '实测 ε_req', '鲁棒增量', '通过率', '是否成立');
fprintf('%s\n', repmat('-', 1, 90));

lemma1_pass = 0;
lemma1_total = 0;
for a_idx = 1:num_alpha
    for d_idx = 1:num_delta
        gap_all = per_agent_gap_all{a_idx, d_idx};
        % 按 agent 扣除"同 δ 的 α=1 中点基线"后的 α-cut 半径增量
        gap_robust = max(0, gap_all - per_agent_base_byd{d_idx});
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
    [~, ~, U_hat, rho_t1] = sec4_1_2_mixed_payoff( ...
        pi_t1, 0, theta, params);
    U_t1_mean(d_idx) = mean(U_hat);
    margin_t1(d_idx) = (1 - alpha_default) * max(rho_t1);  % 必为 0 (因 δ=0)
    WC_t1(d_idx) = worst_case_payoff(pi_t1, 0, theta, params, ...
        sigma_xi, n_perturb);

    % --- IT2-midpoint: δ>0 训练, 决策用 Û (即 α=1) ---
    [pi_mid, ~] = sec4_3_1_wfbri_solve(params, delta, theta);
    [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
        pi_mid, delta, theta, params);
    U_mid_mean(d_idx) = mean(U_hat);
    % IT2-midpoint 决策仍用 Û, 故决策边距按 α_used=1 计 = 0
    margin_mid(d_idx) = 0;
    WC_mid(d_idx) = worst_case_payoff(pi_mid, delta, theta, params, ...
        sigma_xi, n_perturb);

    % --- Proposed: δ>0 训练, 决策用 U̲^α=Û-(1-α)ρ ---
    [pi_prop, ~] = sec5_1_alpha_robust_solve(params, delta, theta, ...
        alpha_default);
    [~, ~, U_hat, rho_prop] = sec4_1_2_mixed_payoff( ...
        pi_prop, delta, theta, params);
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

%% 3b) 直接判据基线: Worst-case 鲁棒博弈 (α→0) 与 Hurwicz-fixed (未标定区间)
% 回应审稿意见"缺直接竞争判据":
%   Worst-case (α→0): ν = U̲ = Û - ρ, 即家族 {Γ_α} 的 α→0 端点,
%     对应 Aghassi-Bertsimas 型最坏情形鲁棒博弈判据在降型区间上的实例;
%   Hurwicz-fixed (uncalibrated): 固定悲观态度 (同 α=0.5 等效权重) 但
%     不确定性区间外生固定 (δ_guess=0.05, 不按真实 FOU 半带宽 δ 标定),
%     对应相关工作中 "fix a single attitude toward payoff uncertainty
%     in advance" 的经典 Hurwicz 区间博弈路线。
%   两条基线均在与 Step 3 相同的真实环境 (真实 δ, σ_ξ=δ/2) 下评估。
fprintf('\n--- Step 3b: 直接判据基线 (Worst-case α→0 / Hurwicz-fixed) ---\n');

delta_guess = 0.05;   % Hurwicz-fixed 的外生固定区间半带宽 (不随真实 δ 标定)

U_wc_mean   = zeros(1, num_delta);  margin_wc = zeros(1, num_delta);
WC_wc       = zeros(1, num_delta);
U_hw_mean   = zeros(1, num_delta);  margin_hw = zeros(1, num_delta);
WC_hw       = zeros(1, num_delta);

for d_idx = 1:num_delta
    delta = delta_values(d_idx);
    sigma_xi = delta * sigma_factor;
    fprintf('\n  δ = %.2f (σ_ξ=%.3f)\n', delta, sigma_xi);

    % --- Worst-case (α→0): δ 真实标定, 决策用 ν = Û - ρ (全悲观) ---
    [pi_wc, ~] = sec5_1_alpha_robust_solve(params, delta, theta, 0);
    [~, ~, U_hat, rho_wc] = sec4_1_2_mixed_payoff( ...
        pi_wc, delta, theta, params);
    U_wc_mean(d_idx) = mean(U_hat);
    margin_wc(d_idx) = 1.0 * max(rho_wc);   % (1-α)|_{α=0} = 1
    WC_wc(d_idx) = worst_case_payoff(pi_wc, delta, theta, params, ...
        sigma_xi, n_perturb);

    % --- Hurwicz-fixed: 区间按外生 δ_guess 构造求解, 在真实 δ 环境评估 ---
    [pi_hw, ~] = sec5_1_alpha_robust_solve(params, delta_guess, theta, ...
        alpha_default);
    % 其"相信的"决策边距来自未标定半径 ρ(δ_guess)
    [~, ~, ~, rho_hw_guess] = sec4_1_2_mixed_payoff( ...
        pi_hw, delta_guess, theta, params);
    margin_hw(d_idx) = (1 - alpha_default) * max(rho_hw_guess);
    % 真实环境下的均衡收益与最差扰动收益
    [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
        pi_hw, delta, theta, params);
    U_hw_mean(d_idx) = mean(U_hat);
    WC_hw(d_idx) = worst_case_payoff(pi_hw, delta, theta, params, ...
        sigma_xi, n_perturb);

    fprintf('    Worst-case(α→0):   Ū=%.4f, 边距=%.4f, WC_Q5=%.4f\n', ...
        U_wc_mean(d_idx), margin_wc(d_idx), WC_wc(d_idx));
    fprintf('    Hurwicz-fixed:     Ū=%.4f, 边距(相信)=%.4f, WC_Q5=%.4f\n', ...
        U_hw_mean(d_idx), margin_hw(d_idx), WC_hw(d_idx));
end

%% 4) Fig 5-5: empirical eps_req vs theoretical 2(1-alpha)*rho_bar (grouped by delta)
figure('Name', 'Lemma 1 Empirical Budget vs Theoretical Upper Bound', ...
    'Position', [100,100,480,330]);
hold on;
delta_colors = {[0.0 0.45 0.74], [0.85 0.33 0.10], [0.93 0.69 0.13], [0.49 0.18 0.56]};
h_theory = gobjects(num_delta, 1);
h_actual = gobjects(num_delta, 1);
for d_idx = 1:num_delta
    h_theory(d_idx) = plot(alpha_values, theoretical_bound(:, d_idx), '-o', ...
        'Color', delta_colors{d_idx}, 'LineWidth', 2.2, 'MarkerSize', 9, ...
        'MarkerFaceColor', delta_colors{d_idx});
    h_actual(d_idx) = plot(alpha_values, ...
        max(0, eps_required(:, d_idx) - eps_required(alpha_one_idx, d_idx)), '--s', ...
        'Color', delta_colors{d_idx}, 'LineWidth', 1.6, 'MarkerSize', 8);
end
% 图例代理(nan 不可见): 颜色=δ ×4, 再加 线型=方法 (实线○=理论界, 虚线□=实测)
hp_leg = gobjects(num_delta + 2, 1);
for d_idx = 1:num_delta
    hp_leg(d_idx) = plot(nan, nan, '-', 'Color', delta_colors{d_idx}, 'LineWidth', 3);
end
hp_leg(num_delta+1) = plot(nan, nan, '-o', 'Color', 'k', 'LineWidth', 1.8, ...
    'MarkerFaceColor', 'k', 'MarkerSize', 6);
hp_leg(num_delta+2) = plot(nan, nan, '--s', 'Color', 'k', 'LineWidth', 1.6, ...
    'MarkerSize', 6);
hold off;
xlabel('Confidence Level \alpha', 'FontSize', 12);
ylabel('Robust Budget', 'FontSize', 12);
title('(a) Robust increment vs budget', 'FontSize', 13);
% 完整图例(颜色=δ ×4 + 线型=方法)放图内右上角, 2 列紧凑(3 行)使其落在曲线上方留白区, 不遮挡
leg_labels = [arrayfun(@(d) sprintf('\\delta=%.2f', d), delta_values, ...
    'UniformOutput', false), {'Theoretical', 'Empirical'}];
legend(hp_leg, leg_labels, 'Location', 'northeast', 'NumColumns', 2, 'FontSize', 9);
grid on;
% 顶部留白带, 使 2 列图例位于所有曲线之上; δ=0 退化(\rho_{bar}=0 \Rightarrow budget\equiv0)见图注
ymax_5 = max(theoretical_bound(:)) * 1.50;
ylim([-ymax_5*0.03, ymax_5]);
apply_fig5_publication_style(gcf);
save_tight_figure(gcf, fullfile(img_dir, 'fig5_5_alpha_robust_error.png'), ...
    fullfile(img_dir, 'fig5_5_alpha_robust_error.pdf'));
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
apply_fig5_publication_style(gcf);
save_tight_figure(gcf, fullfile(img_dir, 'fig5_6_decision_margin.png'), ...
    fullfile(img_dir, 'fig5_6_decision_margin.pdf'));
fprintf('[图] %s\n', fullfile('image', 'fig5_6_decision_margin.png'));

%% 6) 图5-7: 扰动下 Worst-case 收益 (5% 分位数) 三方法对比
% Route C (凹聚合) 下 Type-1 与 IT2-mid 不再重合: IT2-mid 求解使用含曲率惩罚
% -Σθδ_eff² 的类型缩减中心, 其 π* 与 Type-1 (δ=0 决策) 分离, 故三方法 worst-case
% 分别绘制。实现 worst-case 统一在点隶属度 (δ=0) 下评估 (见 worst_case_payoff 注),
% 差异完全来自决策 π* 的鲁棒性, 体现 Proposed α-cut 决策的最差扰动收益提升。
figure('Name', 'Worst-case Payoff Under Perturbation', ...
    'Position', [200,100,820,520]);
hold on;
plot(delta_values, U_t1_mean, '--', 'Color', [0.5 0.5 0.5], ...
    'LineWidth', 1.4, 'Marker', 's', 'MarkerSize', 7);
plot(delta_values, WC_t1, '-s', 'Color', [0 0.45 0.74], ...
    'LineWidth', 1.8, 'MarkerSize', 9);
plot(delta_values, WC_mid, '-^', 'Color', 'm', ...
    'LineWidth', 1.8, 'MarkerSize', 9);
plot(delta_values, WC_prop, '-o', 'Color', [0 0.6 0], ...
    'LineWidth', 2.4, 'MarkerSize', 11, 'MarkerFaceColor', [0 0.6 0]);

% Annotate the improvement of Proposed relative to Type-1 realized worst-case
for d_idx = 2:num_delta
    gap = WC_prop(d_idx) - WC_t1(d_idx);
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
legend({'Type-1 Unperturbed \bar{U} (Baseline)', ...
    'Type-1 Q_5(\bar{U}_\xi)', 'IT2-mid Q_5(\bar{U}_\xi)', ...
    sprintf('Proposed Q_5(\\bar{U}_\\xi), \\alpha=%.1f', alpha_default)}, ...
    'Location', 'southwest', 'FontSize', 10);
grid on;
apply_fig5_publication_style(gcf);
save_tight_figure(gcf, fullfile(img_dir, 'fig5_7_worst_case_payoff.png'), ...
    fullfile(img_dir, 'fig5_7_worst_case_payoff.pdf'));
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
apply_fig5_publication_style(gcf);
save_tight_figure(gcf, fullfile(img_dir, 'fig5_8_safety_coverage.png'), ...
    fullfile(img_dir, 'fig5_8_safety_coverage.pdf'));
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
        gap_robust = max(0, gap_all - per_agent_base_byd{d_idx});
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

% 副表 2d: 五判据对比 (Step 3 三方法 + Step 3b 两条直接判据基线)
fprintf('\n===== 表5-2(d) 五判据对比 (固定 α=%.1f, Hurwicz δ_guess=%.2f) =====\n', ...
    alpha_default, delta_guess);
methods_5 = {'Type-1', 'IT2-midpoint', 'Hurwicz-fixed', 'Proposed', ...
    'Worst-case(a->0)'};
T_d_rows = cell(num_delta * 5, 5);
row_d = 1;
for d_idx = 1:num_delta
    metrics_5 = {
        U_t1_mean(d_idx),   margin_t1(d_idx),   WC_t1(d_idx);
        U_mid_mean(d_idx),  margin_mid(d_idx),  WC_mid(d_idx);
        U_hw_mean(d_idx),   margin_hw(d_idx),   WC_hw(d_idx);
        U_prop_mean(d_idx), margin_prop(d_idx), WC_prop(d_idx);
        U_wc_mean(d_idx),   margin_wc(d_idx),   WC_wc(d_idx)
    };
    for m = 1:5
        fprintf('%-5.2f | %-18s | %9.4f | %9.4f | %12.4f\n', ...
            delta_values(d_idx), methods_5{m}, ...
            metrics_5{m, 1}, metrics_5{m, 2}, metrics_5{m, 3});
        T_d_rows(row_d, :) = {delta_values(d_idx), methods_5{m}, ...
            metrics_5{m, 1}, metrics_5{m, 2}, metrics_5{m, 3}};
        row_d = row_d + 1;
    end
end
T_d = cell2table(T_d_rows, 'VariableNames', ...
    {'delta','Method','AvgPayoff','DecisionMargin','WorstCase_Q5'});
writetable(T_d, fullfile(tbl_dir, 'table5_2d_criterion_baselines.csv'));
fprintf('[表] %s\n', fullfile('table', 'table5_2d_criterion_baselines.csv'));

%% 8b) Scenario B: risk-return coupled stress test for alpha-family value
fprintf('\n--- Step 8b: Scenario B α-family Pareto/CE stress test ---\n');

alpha_pareto = [0, 0.1:0.1:1.0];
gamma_ce = 0.50;
n_pareto = 300;

% Scenario B 环境参数取自规范配置文件 scenario_b_config.m(单一来源), 与
% exp_5_1_6 共享、完全可复现; 不再做"动态择配", 避免历史上因边界 PASS 判据与
% 运行顺序导致的静默漂移(以及经 table5_2e 向 exp_5_1_6 的隐式耦合)。
scenB = scenario_b_config();
delta_B = scenB.delta;
p_shock = scenB.p_shock;
sigma_small = scenB.sigma_small;
fou_scale_B_final = scenB.fou_scale;
shock_strength_B_final = scenB.shock_strength;
scenarioB_choice = 2;   % canonical config-2 (定义见 scenario_b_config.m)
fprintf('  Canonical config-2: fou_scale=[%s], shock=%.2f\n', ...
    num2str(fou_scale_B_final, '%.2f '), shock_strength_B_final);

[T_e_final, pi_alpha_B_final] = scenario_b_alpha_sweep(params, theta, ...
    alpha_pareto, delta_B, gamma_ce, n_pareto, fou_scale_B_final, ...
    shock_strength_B_final, p_shock, sigma_small);

idx_alpha0 = find(abs(T_e_final.alpha - 0.0) < 1e-9, 1);
idx_alpha1 = find(abs(T_e_final.alpha - 1.0) < 1e-9, 1);
[~, idx_best_ce_final] = max(T_e_final.CE_gamma);
alpha_ce = T_e_final.alpha(idx_best_ce_final);
% 诚实口径: δ=0 公平评估下 mean-tail 前沿近线性, 内点 CE 最优浅且随 γ 移动,
% 此处如实记录, 不再作为强鲁棒结论的依据(强鲁棒证据见 §V SOTA Scenario B)。
pass_inner = alpha_ce > 0.1 && alpha_ce < 1.0;
pass_mean = T_e_final.ExpectedPayoff(idx_best_ce_final) > ...
    T_e_final.ExpectedPayoff(idx_alpha0);
pass_tail = T_e_final.WorstCase_Q5(idx_best_ce_final) > ...
    T_e_final.WorstCase_Q5(idx_alpha1);
scenarioB_pass = pass_inner && pass_mean && pass_tail;
fprintf('    α_CE=%.1f, E_CE=%.4f, Q5_CE=%.4f, CE=%.4f %s\n', ...
    alpha_ce, T_e_final.ExpectedPayoff(idx_best_ce_final), ...
    T_e_final.WorstCase_Q5(idx_best_ce_final), ...
    T_e_final.CE_gamma(idx_best_ce_final), pass_label(scenarioB_pass));

T_e_final.ConfigIndex = repmat(scenarioB_choice, height(T_e_final), 1);
T_e_final.FOUScale_SC = repmat(fou_scale_B_final(1), height(T_e_final), 1);
T_e_final.ShockStrength = repmat(shock_strength_B_final, height(T_e_final), 1);
writetable(T_e_final, fullfile(tbl_dir, 'table5_2e_alpha_pareto_scenarioB.csv'));
fprintf('[表] %s\n', fullfile('table', 'table5_2e_alpha_pareto_scenarioB.csv'));

% FOU-adaptive (α,s) frontier overlay: s=10 focusing dominates the scalar
% α frontier in the tail direction (论文 Γ_{α,s} 二维悲观族, 与 tab:sota-scenb 一致)。
focus_s_overlay = 10;
[T_e_adapt, ~] = scenario_b_alpha_sweep(params, theta, alpha_pareto, ...
    delta_B, gamma_ce, n_pareto, fou_scale_B_final, shock_strength_B_final, ...
    p_shock, sigma_small, focus_s_overlay);
T_e_adapt.FocusS = repmat(focus_s_overlay, height(T_e_adapt), 1);
writetable(T_e_adapt, fullfile(tbl_dir, 'table5_2f_alpha_s_pareto_scenarioB.csv'));
fprintf('[表] %s\n', fullfile('table', 'table5_2f_alpha_s_pareto_scenarioB.csv'));

% Pareto figure: alpha family exposes mean-tail tradeoff under coupled risk.
figure('Name', 'Scenario B Alpha-Family Pareto Frontier', ...
    'Position', [220, 100, 480, 400]);
hold on;
scatter(T_e_final.ExpectedPayoff, T_e_final.WorstCase_Q5, 64, ...
    T_e_final.alpha, 'filled', 'MarkerEdgeColor', 'k');
plot(T_e_final.ExpectedPayoff, T_e_final.WorstCase_Q5, '-', ...
    'Color', [0.2 0.2 0.2], 'LineWidth', 1.2);
% adaptive frontier (s=10): solid red curve above the scalar frontier
hadapt = plot(T_e_adapt.ExpectedPayoff, T_e_adapt.WorstCase_Q5, '--^', ...
    'Color', [0.85 0.10 0.10], 'LineWidth', 1.6, 'MarkerSize', 5, ...
    'MarkerFaceColor', [0.85 0.10 0.10], 'MarkerEdgeColor', 'k');
idx_alpha0 = find(abs(T_e_final.alpha - 0.0) < 1e-9, 1);
idx_alpha1 = find(abs(T_e_final.alpha - 1.0) < 1e-9, 1);
idx_best_ce = idx_best_ce_final;
h0 = plot(T_e_final.ExpectedPayoff(idx_alpha0), T_e_final.WorstCase_Q5(idx_alpha0), ...
    'ks', 'MarkerSize', 11, 'LineWidth', 2.0);
h1 = plot(T_e_final.ExpectedPayoff(idx_alpha1), T_e_final.WorstCase_Q5(idx_alpha1), ...
    'kd', 'MarkerSize', 11, 'LineWidth', 2.0);
hce = plot(T_e_final.ExpectedPayoff(idx_best_ce), T_e_final.WorstCase_Q5(idx_best_ce), ...
    'rp', 'MarkerSize', 15, 'LineWidth', 2.2, 'MarkerFaceColor', 'r');
hold off;
% 用图例标注三个关键点, 避免小幅面里文字框遮挡曲线/色条; 并留白边距防裁切
allE = [T_e_final.ExpectedPayoff; T_e_adapt.ExpectedPayoff];
allW = [T_e_final.WorstCase_Q5; T_e_adapt.WorstCase_Q5];
xrng = max(allE) - min(allE);
yrng = max(allW) - min(allW);
xlim([min(allE) - 0.08*xrng, max(allE) + 0.08*xrng]);
ylim([min(allW) - 0.10*yrng, max(allW) + 0.12*yrng]);
colormap(parula);
cb = colorbar;
cb.Label.String = 'Confidence Level alpha';
xlabel('Expected Payoff E(Ubar)', 'FontSize', 12, 'Interpreter', 'none');
ylabel('Worst Tail Payoff WCQ5', 'FontSize', 12, 'Interpreter', 'none');
title('(b) Scenario-B mean--tail frontier', 'FontSize', 12);
legend([h0, h1, hce, hadapt], {'Worst-case (\alpha=0)', 'Midpoint (\alpha=1)', ...
    sprintf('CE-best (\\alpha=%.1f)', T_e_final.alpha(idx_best_ce)), ...
    'FOU-adaptive (s=10)'}, 'Location', 'southwest', 'FontSize', 9);
grid on;
apply_fig5_publication_style(gcf);
save_tight_figure(gcf, fullfile(img_dir, 'fig5_15_pareto_alpha.png'), ...
    fullfile(img_dir, 'fig5_15_pareto_alpha.pdf'));
fprintf('[图] %s\n', fullfile('image', 'fig5_15_pareto_alpha.png'));

latex_dir = fullfile(script_dir, '..', 'Latex');
if exist(latex_dir, 'dir')
    sync_specs = {
        'fig5_5_alpha_robust_error', 'fig5_5_alpha_robust_error';
        'fig5_15_pareto_alpha',      'fig5_15_pareto_alpha';
        'fig5_6_decision_margin',    'fig5_6_decision_margin';
        'fig5_7_worst_case_payoff',  'fig5_7_worst_case_payoff';
        'fig5_8_safety_coverage',    'fig5_8_safety_coverage';
        };
    sync_figure_outputs(img_dir, latex_dir, sync_specs);
end

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

% (iv) Route C 凹聚合: IT2 类型缩减中心保守地低于 Type-1 (中心分离 = 曲率惩罚 Σθδ²)
%      这是 IT2≠Type-1 的结构性证据 (线性聚合下二者重合, 见 exp_5_1_7 精确验证)。
%      Proposed 以"均值换鲁棒": 中心保守下移, 换取正决策边距 (iii) 与公平实现
%      worst-case 不劣 (ii)。线性聚合时该分离恒为 0。
center_sep = U_t1_mean(end) - U_prop_mean(end);
fprintf('(iv) IT2 中心分离 Û_T1 - Û_Prop (δ=%.2f) = %.4f (>0: 凹聚合曲率惩罚) %s\n', ...
    delta_values(end), center_sep, pass_label(center_sep > 1e-3));

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

% (vii) Scenario B: CE optimum must be an interior alpha with mean/tail tradeoff.
fprintf('(vii) Scenario B α-family Pareto/CE evidence:\n');
fprintf('      Config %d, fou_scale=[%s], shock=%.2f\n', scenarioB_choice, ...
    num2str(fou_scale_B_final, '%.2f '), shock_strength_B_final);
fprintf('      α=1: E=%.4f, Q5=%.4f, CE=%.4f\n', ...
    T_e_final.ExpectedPayoff(idx_alpha1), T_e_final.WorstCase_Q5(idx_alpha1), ...
    T_e_final.CE_gamma(idx_alpha1));
fprintf('      α=0: E=%.4f, Q5=%.4f, CE=%.4f\n', ...
    T_e_final.ExpectedPayoff(idx_alpha0), T_e_final.WorstCase_Q5(idx_alpha0), ...
    T_e_final.CE_gamma(idx_alpha0));
fprintf('      α_CE=%.1f: E=%.4f, Q5=%.4f, CE=%.4f %s\n', ...
    T_e_final.alpha(idx_best_ce), ...
    T_e_final.ExpectedPayoff(idx_best_ce), ...
    T_e_final.WorstCase_Q5(idx_best_ce), ...
    T_e_final.CE_gamma(idx_best_ce), pass_label(scenarioB_pass));

fprintf('\n===== 实验二完成 =====\n');
close all;

%% ====== 辅助函数 ======
function [T_e, pi_alpha] = scenario_b_alpha_sweep(base_params, theta, ...
    alpha_grid, delta_B, gamma_ce, n_perturb, fou_scale, shock_strength, ...
    p_shock, sigma_small, focus_s)
% SCENARIO_B_ALPHA_SWEEP  高收益-高暴露策略下的 α-family 风险收益前沿。
%   focus_s (可选, 默认 0): FOU 自适应聚焦指数 s (论文 Γ_{α,s})。s=0 为标量 α
%   前沿; s>0 把悲观预算聚焦到高-FOU 策略, 整条前沿向高尾部方向外推。
    % Risk-return coupled Scenario-B environment (kernels + strategy exposure)
    % is shared with exp_5_1_6 via scenario_b_env for a single source of truth.
    if nargin < 11 || isempty(focus_s); focus_s = 0; end
    params_B = scenario_b_env(base_params, fou_scale);

    num_alpha_B = length(alpha_grid);
    expected_payoff = zeros(num_alpha_B, 1);
    wc_q5 = zeros(num_alpha_B, 1);
    ce_gamma = zeros(num_alpha_B, 1);
    margin_B = zeros(num_alpha_B, 1);
    sc_share = zeros(num_alpha_B, 1);
    pi_alpha = cell(num_alpha_B, 1);

    for a_idx = 1:num_alpha_B
        alpha = alpha_grid(a_idx);
        [pi_star, ~] = sec5_1_alpha_robust_solve(params_B, delta_B, ...
            theta, alpha, focus_s);
        pi_alpha{a_idx} = pi_star;
        sc_share(a_idx) = mean(pi_star(:, 1));

        [~, ~, ~, rho_B] = sec4_1_2_mixed_payoff( ...
            pi_star, delta_B, theta, params_B);
        margin_B(a_idx) = (1 - alpha) * max(rho_B);

        [expected_payoff(a_idx), wc_q5(a_idx)] = scenario_b_payoff_stats(...
            pi_star, delta_B, theta, params_B, n_perturb, p_shock, ...
            sigma_small, shock_strength);
        ce_gamma(a_idx) = expected_payoff(a_idx) - ...
            gamma_ce * (expected_payoff(a_idx) - wc_q5(a_idx));
    end

    T_e = table(alpha_grid(:), expected_payoff, wc_q5, ce_gamma, ...
        margin_B, sc_share, ...
        'VariableNames', {'alpha','ExpectedPayoff','WorstCase_Q5', ...
        'CE_gamma','DecisionMargin','SCShare'});
end

function save_tight_figure(fig_handle, png_path, pdf_path)
% SAVE_TIGHT_FIGURE  导出紧边界 PNG 预览和矢量 PDF。
%   exportgraphics 使用内容边界导出，避免 print -dpdf 的整页留白。
    drawnow;
    apply_fig5_publication_style(fig_handle);
    set(fig_handle, 'Color', 'w');
    exportgraphics(fig_handle, png_path, 'Resolution', 200, ...
        'BackgroundColor', 'white');
    exportgraphics(fig_handle, pdf_path, 'ContentType', 'vector', ...
        'BackgroundColor', 'white');
end

function sync_figure_outputs(img_dir, latex_dir, sync_specs)
% SYNC_FIGURE_OUTPUTS  将 MATLAB 生成的 PNG/PDF 同步到 LaTeX 目录。
%   目标文件名与仿真输出文件名保持一致, 避免图号别名导致引用错误。
    exts = {'.png', '.pdf'};
    fprintf('[同步检查] MATLAB image -> Latex\n');
    for row = 1:size(sync_specs, 1)
        src_base = sync_specs{row, 1};
        dst_base = sync_specs{row, 2};
        for ext_idx = 1:numel(exts)
            ext = exts{ext_idx};
            src_path = fullfile(img_dir, [src_base ext]);
            dst_path = fullfile(latex_dir, [dst_base ext]);
            if exist(src_path, 'file')
                copyfile(src_path, dst_path);
                fprintf('  [SYNC] %s -> %s\n', [src_base ext], [dst_base ext]);
            else
                fprintf('  [MISS] %s\n', [src_base ext]);
            end
        end
    end
end

function wc = worst_case_payoff(pi_star, delta_solve, theta, params, ...
    sigma_xi, n_perturb)
% WORST_CASE_PAYOFF  扰动下 mean(U_hat) 的 5% 分位数 (Worst-case 实现收益)
%   对 M^(trust)/M^(delay)/M^(res) 矩阵加 N(0,σ²) 噪声, n_perturb 次重采样,
%   返回最差 5% 扰动下的均值收益, 衡量"鲁棒实现收益下界"。
%
%   注 (Route C 公平性): "实现收益" 评估在点隶属度 (δ=0) 下进行 —— 扰动 σ_ξ
%   已经代表了不确定性的一次实现, FOU 半带宽 δ 是决策时的先验不确定带, 不应
%   再叠加到实现收益上 (否则凹聚合的中心偏移 -Σθδ² 会被不公平地计入实现收益,
%   使 IT2/Proposed 相对 Type-1 系统性偏低)。各方法仅在求解 π* 时按各自 δ 决策,
%   实现收益统一在 δ=0 下评估, 差异完全来自决策 π* 的鲁棒性。delta_solve 保留
%   仅作签名兼容, 不进入实现收益计算。
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
