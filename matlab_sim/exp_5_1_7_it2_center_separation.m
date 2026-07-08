% exp_5_1_7_it2_center_separation.m - 论文 §5.1 实验七: IT2 type-reduced 中心分离 (Route C)
%
% 验证目标 (对齐 que.md §4 新实验证据 + §6 验收标准):
%   (a) 曲率驱动的中心偏移: 在单调凹聚合 g(μ)=2μ-μ² 下, type-reduced 中心
%         Û_IT2 = Û_T1 - Σ_k θ_k δ_k²   (uniform FOU, 无截断)
%       即 IT2 中心相对 Type-1 中心 (同模型 δ=0) 出现 -Σθδ² 的二阶保守偏移,
%       且偏移幅度随 δ² 单调增长 —— 这是 Type-1 无法捕捉的结构性差异。
%   (b) 线性聚合对照: g(μ)=μ 时 Û_IT2 = Û_T1 (中心与 δ 解析无关), center gap≡0,
%       从而 "线性聚合下 Type-1 与 IT2-midpoint 重合、曲率聚合下分离" 得到直证。
%   (c) 半径闭式: ρ̄ = Σ_k θ_k 2(1-μ_k) δ_k 随 δ 线性增长。
%   (d) 偏移的鲁棒收益意义: 中心偏移使 α-cut 决策值 ν_α=Û_IT2-(1-α)ρ 在凹饱和区
%       更保守, 扰动下尾部 (Worst-case Q5) 更稳。
%
% 输出:
%   image/fig5_19_center_separation.png/pdf - (a) 中心偏移 vs δ (凹 vs 线性 vs 理论)
%                                              (b) 半径/α-cut 决策值 vs δ
%   table/table5_7_center_separation.csv     - δ × {U_T1, Û_IT2, gap, 理论-δ², ρ̄, 线性gap}

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

%% 参数设置 (uniform FOU 以匹配闭式; 关闭 bell 调制保证 μ±δ 对 π 仿射)
params = config_params();
params.N = 50;
params.fou_modulation = false;
theta = params.theta;
sum_theta = sum(theta);

delta_values = [0, 0.05, 0.10, 0.15, 0.20];
num_delta = numel(delta_values);
alpha_default = params.alpha;     % 0.5, 用于 α-cut 决策值演示

% 状态扰动协议 (与实验二一致: σ_ξ = δ/2)
sigma_factor = 0.5;
n_perturb = 30;

fprintf('===== 论文 §5.1 实验七: IT2 type-reduced 中心分离 (Route C) =====\n');
fprintf('聚合方式 = %s, θ=[%.2f %.2f %.2f], Σθ=%.2f\n', ...
    params.payoff_aggregation, theta, sum_theta);
fprintf('δ 扫描 = [%s]\n', num2str(delta_values));

%% 1) 逐 δ 计算中心偏移 (凹聚合 vs 线性聚合)
U_T1_con   = zeros(1, num_delta);   % Type-1 中心 (凹模型 δ=0) = Σθ g(μ)
U_hat_con  = zeros(1, num_delta);   % IT2 中心 (凹模型 δ>0)
gap_con    = zeros(1, num_delta);   % Û_IT2 - Û_T1 (凹)
gap_theory = zeros(1, num_delta);   % 理论 -Σθδ²
rho_bar    = zeros(1, num_delta);   % 平均半径
nu_alpha   = zeros(1, num_delta);   % α-cut 决策值 Û_IT2-(1-α)ρ̄
U_hat_lin  = zeros(1, num_delta);   % IT2 中心 (线性模型 δ>0)
U_T1_lin   = zeros(1, num_delta);   % Type-1 中心 (线性模型 δ=0)
gap_lin    = zeros(1, num_delta);   % Û_IT2 - Û_T1 (线性, 应≡0)
WC_con     = zeros(1, num_delta);   % 凹聚合 α-cut 决策的扰动 Worst-case Q5

for d_idx = 1:num_delta
    delta = delta_values(d_idx);

    % --- 凹聚合 (默认): 在真实 δ 下用 α-cut 鲁棒决策求解均衡 ---
    [pi_con, ~] = sec5_1_alpha_robust_solve(params, delta, theta, alpha_default);
    [~, ~, U_t1] = sec4_1_2_mixed_payoff( ...
        pi_con, 0, theta, params);
    U_T1_con(d_idx) = mean(U_t1);
    [~, ~, U_hat, rho] = sec4_1_2_mixed_payoff( ...
        pi_con, delta, theta, params);
    U_hat_con(d_idx) = mean(U_hat);
    rho_bar(d_idx)   = mean(rho);
    gap_con(d_idx)   = U_hat_con(d_idx) - U_T1_con(d_idx);
    gap_theory(d_idx)= -sum_theta * delta^2;       % -Σθδ²
    nu_alpha(d_idx)  = mean(U_hat - (1 - alpha_default) * rho);
    WC_con(d_idx)    = local_worst_case(pi_con, delta, theta, params, ...
        delta * sigma_factor, n_perturb, alpha_default);

    % --- 线性聚合对照: 同一均衡策略下中心与 δ 解析无关, center gap≡0 ---
    params_linear = params;
    params_linear.payoff_aggregation = 'linear';
    [~, ~, U_hat_l] = sec4_1_2_mixed_payoff( ...
        pi_con, delta, theta, params_linear);
    [~, ~, U_t1_l] = sec4_1_2_mixed_payoff( ...
        pi_con, 0, theta, params_linear);
    U_hat_lin(d_idx) = mean(U_hat_l);
    U_T1_lin(d_idx)  = mean(U_t1_l);
    gap_lin(d_idx)   = U_hat_lin(d_idx) - U_T1_lin(d_idx);

    fprintf('  δ=%.2f: U_T1=%.4f, Û_IT2=%.4f, gap=%.5f (理论 %.5f), ρ̄=%.4f | 线性 gap=%.2e\n', ...
        delta, U_T1_con(d_idx), U_hat_con(d_idx), gap_con(d_idx), ...
        gap_theory(d_idx), rho_bar(d_idx), gap_lin(d_idx));
end

%% 2) 图 5-19: 双纵轴单面板 (共享 δ 横轴)
%   左轴 Payoff Quantity : 半径 ρ̄ / IT2 中心 Û_IT2 / α-cut 决策值 ν_α
%   右轴 Center Shift    : 凹聚合实测 & 理论 -Σθδ² (二者重合) / 线性 g (≡0)
%   图例置于绘图框外下方 (southoutside), 不遮挡任何曲线; 每项加 (L)/(R) 标注所属轴
figure('Name', 'IT2 Type-Reduced Center Separation', ...
    'Position', [120, 90, 660, 500]);
ax = axes; hold(ax, 'on');

c_center = [0    0.45 0.74];   % 蓝   - Û_IT2 中心      (左轴)
c_nu     = [0.85 0.33 0.10];   % 橙   - ν_α 决策值       (左轴)
c_rho    = [0.49 0.18 0.56];   % 紫   - 半径 ρ̄          (左轴)
c_shift  = [0.15 0.15 0.15];   % 近黑 - 中心偏移 实测/理论 (右轴)
c_lin    = [0.47 0.67 0.19];   % 绿   - 线性 g ≡0        (右轴)

% --- 左轴: Payoff Quantity ---
yyaxis left;
h_rho = plot(delta_values, rho_bar, '-^', 'Color', c_rho, ...
    'LineWidth', 2.2, 'MarkerSize', 9, 'MarkerFaceColor', c_rho);
h_ctr = plot(delta_values, U_hat_con, '-o', 'Color', c_center, ...
    'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', 'none');
h_nu  = plot(delta_values, nu_alpha, '--d', 'Color', c_nu, ...
    'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', 'none');
ylabel('Payoff Quantity', 'FontSize', 12);
ylim([0, 0.95]);
set(ax, 'YColor', 'k');

% --- 右轴: Center Shift (实测 ○ 落在理论线上; 线性对照 ≡0) ---
yyaxis right;
h_th  = plot(delta_values, gap_theory, '-', 'Color', c_shift, 'LineWidth', 2.2);
h_msr = plot(delta_values, gap_con, 'o', 'Color', c_shift, ...
    'MarkerSize', 9, 'MarkerFaceColor', c_shift, 'LineStyle', 'none');
h_lin = plot(delta_values, gap_lin, '--s', 'Color', c_lin, ...
    'LineWidth', 1.8, 'MarkerSize', 8, 'MarkerFaceColor', 'none');
ylabel('Center Shift  \^U_{IT2} - \^U_{T1}', 'FontSize', 12);
ylim([-0.045, 0.006]);
set(ax, 'YColor', 'k');

hold(ax, 'off');
yyaxis left;                    % 收尾切回左轴, 使主纵轴标签加粗一致
xlabel('Uncertainty Half-Bandwidth \delta', 'FontSize', 12);
xlim([-0.006, 0.206]);
grid on;

% 图例置于绘图区正中空白带: 仅压黑色下垂线, 不碰左轴三条结论曲线 (半径/中心/ν_α)。
% MATLAB 无 'center' 选项, 故手动居中; 先按最终字号 (12pt, 与出版样式一致) 测尺寸再定位,
% 避免后续字号覆盖使文字溢出图例框。图例白底不透明, 会干净盖住其后的黑线。
lgd = legend([h_rho, h_ctr, h_nu, h_th, h_msr, h_lin], ...
    {'Radius \rho_{bar} (L)', '\^U_{IT2} center (L)', ...
     '\nu_\alpha=\^U-(1-\alpha)\rho, \alpha=0.5 (L)', ...
     'Theory -\Sigma\theta\delta^2 (R)', 'Concave g meas. (R)', ...
     'Linear g \equiv0 (R)'}, ...
    'NumColumns', 2, 'FontSize', 12);
drawnow;
axp = ax.Position;                         % 绘图区位置 (figure 归一化)
lgd.Units = 'normalized';
lp = lgd.Position;                         % 图例自然尺寸 (12pt 下)
lgd.Location = 'none';
% 水平居中; 纵向下移至轴高 0.25 处, 使图例顶边落在 δ=0.10(0.65) 与 δ=0.15(0.42) 两黑点下方,
% 坐落于黑线与半径线之间的空三角区, 只压黑线、不压任何黑色实测点。
y_center_frac = 0.25;
lgd.Position = [axp(1) + axp(3)/2 - lp(3)/2, ...
                axp(2) + y_center_frac*axp(4) - lp(4)/2, ...
                lp(3), lp(4)];

apply_fig5_publication_style(gcf);
local_save_figure(gcf, fullfile(img_dir, 'fig5_19_center_separation.png'), ...
    fullfile(img_dir, 'fig5_19_center_separation.pdf'));
fprintf('\n[图] %s\n', fullfile('image', 'fig5_19_center_separation.png'));

%% 3) 表 5-7: 中心分离数据
T = table(delta_values(:), U_T1_con(:), U_hat_con(:), gap_con(:), ...
    gap_theory(:), rho_bar(:), nu_alpha(:), WC_con(:), gap_lin(:), ...
    'VariableNames', {'delta', 'U_T1_concave', 'U_hat_IT2_concave', ...
    'CenterGap_concave', 'Theory_minus_sumThetaDelta2', 'RhoBar', ...
    'NuAlpha', 'WorstCase_Q5', 'CenterGap_linear'});
csv_path = fullfile(tbl_dir, 'table5_7_center_separation.csv');
writetable(T, csv_path);
fprintf('[表] %s\n', fullfile('table', 'table5_7_center_separation.csv'));

%% 4) 同步图到 LaTeX 目录
latex_dir = fullfile(script_dir, '..', 'Latex');
if exist(latex_dir, 'dir')
    for ext = {'.png', '.pdf'}
        src = fullfile(img_dir, ['fig5_19_center_separation' ext{1}]);
        if exist(src, 'file')
            copyfile(src, fullfile(latex_dir, ['fig5_19_center_separation' ext{1}]));
            fprintf('  [SYNC] fig5_19_center_separation%s\n', ext{1});
        end
    end
end

%% 5) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) 凹聚合 center gap ≈ -Σθδ² (相对误差; δ=0 除外)
rel_err = zeros(1, num_delta);
for d_idx = 2:num_delta
    rel_err(d_idx) = abs(gap_con(d_idx) - gap_theory(d_idx)) / abs(gap_theory(d_idx));
end
max_rel = max(rel_err);
fprintf('(i) 凹聚合 center gap ≈ -Σθδ² (max 相对误差=%.2f%%) %s\n', ...
    max_rel * 100, local_pass(max_rel < 0.05));

% (ii) center gap 随 δ² 单调 (|gap| 递增)
mono = all(diff(abs(gap_con)) >= -1e-9);
fprintf('(ii) |center gap| 随 δ 单调递增 %s\n', local_pass(mono));

% (iii) 线性聚合 center gap ≡ 0
max_lin_gap = max(abs(gap_lin));
fprintf('(iii) 线性聚合 center gap ≡ 0 (max=%.2e) %s\n', ...
    max_lin_gap, local_pass(max_lin_gap < 1e-6));

% (iv) 半径 ρ̄ 随 δ 线性增长 (与 δ 的相关系数≈1)
if num_delta >= 3
    cc = corrcoef(delta_values, rho_bar);
    lin_corr = cc(1, 2);
else
    lin_corr = NaN;
end
fprintf('(iv) ρ̄ 与 δ 线性相关系数=%.4f %s\n', lin_corr, local_pass(lin_corr > 0.999));

% (v) Worst-case Q5 随 δ 增大未崩塌 (中心偏移的尾部稳定性)
fprintf('(v) 凹聚合 α-cut 决策 Worst-case Q5 随 δ:\n');
for d_idx = 1:num_delta
    fprintf('     δ=%.2f: WC_Q5=%.4f\n', delta_values(d_idx), WC_con(d_idx));
end

fprintf('\n===== 实验七完成 =====\n');
close all;

%% ====== 辅助函数 ======
function wc = local_worst_case(pi_star, delta, theta, params, sigma_xi, ...
    n_perturb, alpha)
% LOCAL_WORST_CASE  α-cut 决策值 ν_α=Û-(1-α)ρ 在状态核扰动下的 5% 分位 (尾部稳定性)
    if sigma_xi <= 0
        [~, ~, U_hat, rho] = sec4_1_2_mixed_payoff( ...
            pi_star, delta, theta, params);
        wc = mean(U_hat - (1 - alpha) * rho); return;
    end
    vals = zeros(n_perturb, 1);
    rng(params.rng_seed + 71);
    for k = 1:n_perturb
        p = params;
        p.trust_matrix = max(0, min(1, params.trust_matrix + ...
            sigma_xi * randn(size(params.trust_matrix))));
        p.delay_matrix = max(0, min(1, params.delay_matrix + ...
            sigma_xi * randn(size(params.delay_matrix))));
        p.res_matrix = max(0, min(1, params.res_matrix + ...
            sigma_xi * randn(size(params.res_matrix))));
        [~, ~, U_hat, rho] = sec4_1_2_mixed_payoff( ...
            pi_star, delta, theta, p);
        vals(k) = mean(U_hat - (1 - alpha) * rho);
    end
    wc = quantile(vals, 0.05);
end

function local_save_figure(fig_handle, png_path, pdf_path)
% LOCAL_SAVE_FIGURE  导出紧边界 PNG + 矢量 PDF
    drawnow;
    apply_fig5_publication_style(fig_handle);
    set(fig_handle, 'Color', 'w');
    exportgraphics(fig_handle, png_path, 'Resolution', 200, 'BackgroundColor', 'white');
    exportgraphics(fig_handle, pdf_path, 'ContentType', 'vector', 'BackgroundColor', 'white');
end

function s = local_pass(ok)
    if ok; s = '[PASS]'; else; s = '[WARN]'; end
end
