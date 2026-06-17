% exp_5_1_1_convergence.m - 论文 §5.1 实验一: W-FBRI 收敛性与加权机制验证
%
% 验证目标 (对齐 chapter5.md §5.1 实验一新版设计):
%   (a) 定理 2 全局压缩收敛: e_pi^(r) 几何衰减, q_hat <= q_th = (1-β) + β·κ
%   (b) 加权机制 (3-7)(3-8) 必要性: Proposed (θ=P_pay·ω) vs Fixed-weight IT2 (θ=均匀)
%   (c) 压缩条件 κ = D(θ)/(2λ) < 1 的工程边界 (命题 1 结构化模量, 非采样估计)
%   (d) (4-26) 单轮复杂度 O(|S|N) → 收敛轮数 R 关于 N 近似常数
%
% 对比方法 (相比旧版删除 Deterministic 和 Type-1 Fuzzy 两个伪对比):
%   1) Greedy           - λ→0,β=1 硬响应, 验证软响应必要性
%   2) Fixed-weight IT2 - δ>0 但 θ=[1/3;1/3;1/3] 固定, 验证 W 机制必要性
%   3) Proposed         - 完整 W-FBRI (软响应+阻尼+动态 θ)
%
% 输出:
%   image/fig5_1_residual_convergence.png  - 残差几何衰减 + (4-25) 理论包络
%   image/fig5_2_payoff_convergence.png    - 平均收益, 体现 Proposed > Fixed-W
%   image/fig5_3_strategy_evolution.png    - Proposed 策略概率演化
%   image/fig5_4_contraction_scalability.png - (a) (λ,β) 热力图; (b) R vs N 扩展性
%   table/table5_1_convergence.csv         - 含 q_hat / q_th / D_theta 共 8 列

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

%% 参数设置（统一从 config_params 取值）
params_base = config_params();
delta = params_base.delta;        % 0.10
theta = params_base.theta;        % P_pay × omega_init = [0.40; 0.35; 0.25]
N_list = [20, 50, 100];           % 论文 §5.1 表5.1 智能体数量扫描
default_N_idx = 2;                % 用 N=50 作为代表性绘图

methods = {'Greedy', 'Fixed-weight IT2', 'Proposed IT2-W-FBRI'};
num_methods = length(methods);

fprintf('===== 论文 §5.1 实验一: W-FBRI 收敛性与加权机制验证 =====\n');
fprintf('扫描 N = [%s], delta = %.2f, theta = [%.2f; %.2f; %.2f]\n', ...
    num2str(N_list), delta, theta(1), theta(2), theta(3));

%% 0b) JIT 预热: 先以最小规模各跑一次三条求解链, 避免首次调用的
%      MATLAB JIT 编译时间污染表 5-1 的 Runtime 列 (复核时发现首行虚高约 9 倍)
params_warm = params_base;
params_warm.N = 5;
[~, ~] = sec5_1_greedy_solve(params_warm, delta, theta);
[~, ~] = sec5_1_fixed_weight_it2_solve(params_warm, delta);
[~, ~] = sec4_3_1_wfbri_solve(params_warm, delta, theta);

%% 1) 主扫描: N × Method 笛卡尔积
results_all = cell(length(N_list), num_methods);
for n_idx = 1:length(N_list)
    params = params_base;
    params.N = N_list(n_idx);
    fprintf('\n--- N = %d ---\n', params.N);

    fprintf('[1/3] Greedy ...');
    tic; [~, results_all{n_idx, 1}] = sec5_1_greedy_solve(params, delta, theta);
    results_all{n_idx, 1}.time = toc;
    fprintf(' %d 轮, %.2fs\n', results_all{n_idx, 1}.iterations, ...
        results_all{n_idx, 1}.time);

    fprintf('[2/3] Fixed-weight IT2 ...');
    tic; [~, results_all{n_idx, 2}] = sec5_1_fixed_weight_it2_solve(params, delta);
    results_all{n_idx, 2}.time = toc;
    fprintf(' %d 轮, %.2fs\n', results_all{n_idx, 2}.iterations, ...
        results_all{n_idx, 2}.time);

    fprintf('[3/3] Proposed IT2-W-FBRI ...');
    tic; [~, results_all{n_idx, 3}] = sec4_3_1_wfbri_solve(params, delta, theta);
    results_all{n_idx, 3}.time = toc;
    fprintf(' %d 轮, %.2fs\n', results_all{n_idx, 3}.iterations, ...
        results_all{n_idx, 3}.time);
end

%% 2) 几何压缩率 q_hat 与理论压缩率 q_th 计算
%   q_hat = (e^(R) / e^(1))^(1/(R-1))    (实测)
%   q_th  = (1-β) + β·κ, κ = D(θ)/(2λ)   (定理 2 + 命题 1 结构化模量)
%   D(θ)  由成对交互核矩阵闭式计算 (公式 4-Dtheta), 不依赖采样

% 命题 1 结构化模量: Proposed (θ=P_pay·ω) 与 Fixed (θ=均匀)
fprintf('\n[D(θ) 结构化计算] 由核矩阵闭式求得 (命题 1)...\n');
[D_proposed, info_prop] = sec4_3_1_kernel_variation_modulus(params_base, theta);
[D_fixed, ~] = sec4_3_1_kernel_variation_modulus(params_base, ones(3,1)/3);

% Greedy: λ→0, q_th 不适用 (κ<1 失效), 标 NaN
D_theta_list = [NaN, D_fixed, D_proposed];
fprintf('D(Fixed) = %.5f, D(Proposed) = %.5f (极差最大策略对: %d-%d)\n', ...
    D_fixed, D_proposed, info_prop.argmax_pair(1), info_prop.argmax_pair(2));

% 命题 1 前提: 均匀 FOU 不饱和检查 (沿 N=50 Proposed 迭代轨迹)
%   μ_k(j,r) = M_k(j,:)·x̄(r) 须落在 [δ, 1-δ] 内, 否则裁剪会破坏共同平移消去
sat_ok = check_fou_saturation(params_base, delta, ...
    results_all{default_N_idx, 3}.strategy_dist);
fprintf('[饱和检查] 均匀 FOU 沿迭代轨迹不饱和 (μ∈[δ,1-δ]): %s\n', ...
    pass_label(sat_ok));

lambda_default = params_base.lambda;   % 0.10
beta_default   = params_base.beta;     % 0.3
kappa_fixed    = D_fixed    / (2 * lambda_default);
kappa_proposed = D_proposed / (2 * lambda_default);
q_th_list = zeros(num_methods, 1);
q_th_list(1) = NaN;                    % Greedy 无定理 2 保证
q_th_list(2) = (1-beta_default) + beta_default * kappa_fixed;
q_th_list(3) = (1-beta_default) + beta_default * kappa_proposed;

% 实测 q_hat (N × Method)
q_hat_grid = NaN(length(N_list), num_methods);
for n_idx = 1:length(N_list)
    for m = 1:num_methods
        res = results_all{n_idx, m};
        R = res.iterations;
        if R >= 3 && res.residual(1) > 1e-12 && res.residual(R) > 1e-12
            q_hat_grid(n_idx, m) = (res.residual(R) / res.residual(1))^(1/(R-1));
        end
    end
end

fprintf('\n[压缩率] 默认 (λ=%.2f, β=%.1f):\n', lambda_default, beta_default);
fprintf('  κ(Fixed)=%.4f, q_th(Fixed)    = %.4f, q_hat(Fixed,N=50)    = %.4f\n', ...
    kappa_fixed, q_th_list(2), q_hat_grid(default_N_idx, 2));
fprintf('  κ(Prop) =%.4f, q_th(Proposed) = %.4f, q_hat(Proposed,N=50) = %.4f\n', ...
    kappa_proposed, q_th_list(3), q_hat_grid(default_N_idx, 3));
fprintf('  [核验] 默认工作点 κ<1 (定理 2 收缩条件): Fixed %s | Proposed %s\n', ...
    pass_label(kappa_fixed < 1), pass_label(kappa_proposed < 1));

%% 3) 取代表性 N = 50 用于绘图
results = results_all(default_N_idx, :);
N_plot = N_list(default_N_idx);

%% 4) 图5-1 / 图5-2 通用绘图参数 (只展示同质 W-FBRI 收敛轨迹: Fixed-W 与 Proposed)
%   Greedy 是硬响应、2 轮即终止 (r=2 残差归零, 在 log scale 不可见), 不属于
%   "迭代收敛过程对比"的合适展示对象, 因此从图 5-1/5-2 移除;
%   Greedy 数据保留在表 5-1 (定量对比) 和图 5-4(b) 柱状图 (扩展性对比) 中。
colors      = {'r',           'm',           [0 0.6 0]};      % Greedy/Fixed/Proposed (沿用)
line_styles = {'--',          '-.',          '-'};
markers     = {'v',           '^',           'o'};
linewidths  = [1.8,           2.2,           2.2];
marker_sizes= [9,             10,            10];
plot_methods_curve = [2, 3];   % 仅 Fixed-weight IT2, Proposed IT2-W-FBRI

%% Fig 5-1: Strategy residual geometric convergence (Fixed-W vs Proposed)
figure('Name', 'W-FBRI Strategy Residual Geometric Convergence', ...
    'Position', [100,100,750,520]);
hold on;
handles = gobjects(length(plot_methods_curve), 1);
for k = 1:length(plot_methods_curve)
    m = plot_methods_curve(k);
    iters = 1:length(results{m}.residual);
    mark_step = max(1, floor(length(iters)/10));
    handles(k) = plot(iters, results{m}.residual, ...
        'Color', colors{m}, 'LineStyle', line_styles{m}, ...
        'LineWidth', linewidths(m), ...
        'Marker', markers{m}, 'MarkerIndices', 1:mark_step:length(iters), ...
        'MarkerSize', marker_sizes(m), 'MarkerFaceColor', colors{m});
end
hold off;
set(gca, 'YScale', 'log');
xlabel('Iteration r', 'FontSize', 12);
ylabel('Strategy Residual e_\pi^{(r)}', 'FontSize', 12);
title(sprintf('W-FBRI Strategy Residual Geometric Convergence (N=%d, \\lambda=%.2f, \\beta=%.1f)', ...
    N_plot, lambda_default, beta_default), 'FontSize', 13);
legend(handles, methods(plot_methods_curve), 'Location', 'northeast', 'FontSize', 11);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_1_residual_convergence.png'));
% 矢量 PDF: exportgraphics 默认按内容边界裁剪, 无整页留白边框
exportgraphics(gcf, fullfile(img_dir, 'fig5_1_residual_convergence.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('\n[图] %s\n', fullfile('image', 'fig5_1_residual_convergence.png'));

%% Fig 5-2: Average crystallized payoff convergence (Proposed > Fixed-W via W mechanism)
figure('Name', 'Average Crystallized Payoff Convergence', ...
    'Position', [150,100,750,520]);
hold on;
handles2 = gobjects(length(plot_methods_curve), 1);
for k = 1:length(plot_methods_curve)
    m = plot_methods_curve(k);
    iters = 1:length(results{m}.avg_payoff);
    mark_step = max(1, floor(length(iters)/10));
    handles2(k) = plot(iters, results{m}.avg_payoff, ...
        'Color', colors{m}, 'LineStyle', line_styles{m}, ...
        'LineWidth', linewidths(m), ...
        'Marker', markers{m}, 'MarkerIndices', 1:mark_step:length(iters), ...
        'MarkerSize', marker_sizes(m), 'MarkerFaceColor', colors{m});
end
hold off;
xlabel('Iteration r', 'FontSize', 12);
ylabel('Average Crystallized Payoff U^{(r)}_{avg}', 'FontSize', 12);
title(sprintf('Average Crystallized Payoff Convergence (N=%d)', N_plot), 'FontSize', 13);
legend(handles2, methods(plot_methods_curve), 'Location', 'southeast', 'FontSize', 11);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_2_payoff_convergence.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_2_payoff_convergence.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_2_payoff_convergence.png'));

%% Fig 5-3: Strategy probability evolution of four classes (Proposed method, idx=3)
figure('Name', 'Strategy Probability Evolution', ...
    'Position', [200,100,750,520]);
strategy_names = {'SC', 'SP', 'DC', 'DP'};
strategy_colors = {'b', 'r', [0.9 0.6 0], [0.5 0 0.5]};
hold on;
for j = 1:4
    plot(1:results{3}.iterations, results{3}.strategy_dist(:, j), ...
        'Color', strategy_colors{j}, 'LineWidth', 2.2);
end
hold off;
xlabel('Iteration r', 'FontSize', 12);
ylabel('Strategy Probability', 'FontSize', 12);
title(sprintf('Strategy Probability Evolution (Proposed, N=%d)', N_plot), 'FontSize', 13);
legend(strategy_names, 'Location', 'east', 'FontSize', 11);
grid on;
saveas(gcf, fullfile(img_dir, 'fig5_3_strategy_evolution.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_3_strategy_evolution.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_3_strategy_evolution.png'));

%% 5) (λ, β) 扫描: 验证压缩条件 κ=D(θ)/(2λ)<1 的工程边界与 q_hat 网格
% λ 网格覆盖认证窗口 (D/2, ε_acc/ln|S|] = (0.077, 0.108] 的两侧与内部:
%   0.05 → 收缩侧认证失败 (κ>1); 0.08 → 窗口内边界点; 0.10 → 默认;
%   0.20 → 收缩认证成立但偏差预算超标 (λ·ln|S| > ε_acc)
lambda_list = [0.05, 0.08, 0.10, 0.20];
beta_list   = [0.10, 0.30, 0.50];
q_hat_LB    = NaN(length(beta_list), length(lambda_list));
q_th_LB     = NaN(length(beta_list), length(lambda_list));

fprintf('\n[扫描] (λ × β) 网格 %dx%d, 仅 Proposed 方法...\n', ...
    length(beta_list), length(lambda_list));
for ib = 1:length(beta_list)
    for il = 1:length(lambda_list)
        params_lb = params_base;
        params_lb.N = 50;
        params_lb.lambda = lambda_list(il);
        params_lb.beta = beta_list(ib);
        [~, hist_lb] = sec4_3_1_wfbri_solve(params_lb, delta, theta);
        R_lb = hist_lb.iterations;
        if R_lb >= 3 && hist_lb.residual(1) > 1e-12 && hist_lb.residual(R_lb) > 1e-12
            q_hat_LB(ib, il) = (hist_lb.residual(R_lb) / hist_lb.residual(1))^(1/(R_lb-1));
        else
            q_hat_LB(ib, il) = 0;     % 收敛极快, q_hat ≈ 0
        end
        q_th_LB(ib, il) = (1-beta_list(ib)) ...
            + beta_list(ib) * D_proposed / (2 * lambda_list(il));
        fprintf('  λ=%.2f, β=%.1f: q_th=%.3f, q_hat=%.3f, R=%d\n', ...
            lambda_list(il), beta_list(ib), q_th_LB(ib, il), q_hat_LB(ib, il), R_lb);
    end
end

%% Fig 5-4: (a) (lambda, beta) contraction-rate heatmap; (b) convergence rounds R vs N
figure('Name', 'Contraction Condition and Scalability', ...
    'Position', [250,100,1100,460]);

% (a) (lambda, beta) contraction-rate heatmap
subplot(1, 2, 1);
imagesc(q_hat_LB);
colormap(flipud(parula));
caxis([0, 1]);
colorbar;
set(gca, 'XTick', 1:length(lambda_list), 'XTickLabel', ...
    arrayfun(@(x) sprintf('%.2f', x), lambda_list, 'UniformOutput', false));
set(gca, 'YTick', 1:length(beta_list), 'YTickLabel', ...
    arrayfun(@(x) sprintf('%.1f', x), beta_list, 'UniformOutput', false));
xlabel('Entropy Regularization \lambda', 'FontSize', 12);
ylabel('Damping \beta', 'FontSize', 12);
title('(a) Proposed Empirical Contraction Rate q_{hat}', 'FontSize', 12);
% 在每个 cell 写出 q_hat 与 q_th
for ib = 1:length(beta_list)
    for il = 1:length(lambda_list)
        txt_color = 'k';
        if q_hat_LB(ib, il) > 0.7; txt_color = 'w'; end
        text(il, ib, sprintf('q^=%.2f\nq_t=%.2f', ...
            q_hat_LB(ib, il), q_th_LB(ib, il)), ...
            'HorizontalAlignment', 'center', 'Color', txt_color, ...
            'FontSize', 9, 'FontWeight', 'bold');
    end
end

% (b) 收敛轮数 R 关于 N 的扩展性 (柱状图, 避免 Fixed/Proposed R 相同时的重合)
subplot(1, 2, 2);
R_grid = zeros(length(N_list), num_methods);
for n_idx = 1:length(N_list)
    for m = 1:num_methods
        R_grid(n_idx, m) = results_all{n_idx, m}.iterations;
    end
end
b = bar(R_grid, 'grouped');
for m = 1:num_methods
    b(m).FaceColor = colors{m};
    b(m).EdgeColor = 'k';
    b(m).LineWidth = 0.8;
end
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('N=%d', x), N_list, ...
    'UniformOutput', false));
xlabel('Number of Agents N', 'FontSize', 12);
ylabel('Convergence Rounds R', 'FontSize', 12);
title('(b) Scalability of Convergence Rounds R vs N', 'FontSize', 12);
legend(methods, 'Location', 'northwest', 'FontSize', 10);
grid on;
ylim([0, max(R_grid(:))*1.2 + 1]);
% 在柱子上标数值
for n_idx = 1:length(N_list)
    for m = 1:num_methods
        x_pos = n_idx + (m - (num_methods+1)/2) * 0.22;
        text(x_pos, R_grid(n_idx, m) + 0.5, sprintf('%d', R_grid(n_idx, m)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    end
end

saveas(gcf, fullfile(img_dir, 'fig5_4_contraction_scalability.png'));
exportgraphics(gcf, fullfile(img_dir, 'fig5_4_contraction_scalability.pdf'), ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('[图] %s\n', fullfile('image', 'fig5_4_contraction_scalability.png'));

sync_named_figures(img_dir, fullfile(script_dir, '..', 'Latex'), {
    'fig5_1_residual_convergence.png';
    'fig5_1_residual_convergence.pdf';
    'fig5_2_payoff_convergence.png';
    'fig5_2_payoff_convergence.pdf';
    'fig5_3_strategy_evolution.png';
    'fig5_3_strategy_evolution.pdf';
    'fig5_4_contraction_scalability.png';
    'fig5_4_contraction_scalability.pdf';
    });

%% 5b) λ 认证窗口边界分析 (Remark 3): 认证边界 vs 实测边界
%   收缩侧认证: λ > D(θ)/2 ⟺ κ = D/(2λ) < 1 (定理 1 前提)
%   偏差侧认证: λ ≤ ε_acc / C_λ, C_λ ≤ ln|S| (Remark 3 精度预算)
%   取 (λ,β) 扫描中 β=默认值 0.3 的行, 对照"认证状态"与"实测 q_hat",
%   量化认证窗口外的实际行为 (认证保守度 / 真实失败边界)。
eps_acc   = 0.15;                              % 与论文 Remark 3 一致
bias_coef = log(params_base.num_strategies);   % C_λ 上界 = ln|S| = ln4
beta_row  = find(abs(beta_list - beta_default) < 1e-9, 1);

fprintf('\n--- 5b: λ 认证窗口边界分析 (β=%.1f, 窗口 (%.4f, %.4f]) ---\n', ...
    beta_default, D_proposed/2, eps_acc/bias_coef);
fprintf('%-6s | %-7s | %-6s | %-8s | %-9s | %-8s | %-6s | %s\n', ...
    'λ', 'κ=D/2λ', 'q_th', '收缩认证', '偏差预算', '预算达标', 'q_hat', '窗口内');
fprintf('%s\n', repmat('-', 1, 80));

T_lw_rows = cell(length(lambda_list), 8);
for il = 1:length(lambda_list)
    lam = lambda_list(il);
    kappa_l = D_proposed / (2 * lam);
    contraction_ok = (kappa_l < 1);
    bias_bound = lam * bias_coef;
    bias_ok = (bias_bound <= eps_acc + 1e-12);
    in_window = contraction_ok && bias_ok;
    fprintf('%-6.2f | %-7.3f | %-6.3f | %-8s | %-9.3f | %-8s | %-6.3f | %s\n', ...
        lam, kappa_l, q_th_LB(beta_row, il), yn_label(contraction_ok), ...
        bias_bound, yn_label(bias_ok), q_hat_LB(beta_row, il), ...
        yn_label(in_window));
    T_lw_rows(il, :) = {lam, kappa_l, q_th_LB(beta_row, il), ...
        double(contraction_ok), bias_bound, double(bias_ok), ...
        q_hat_LB(beta_row, il), double(in_window)};
end
T_lw = cell2table(T_lw_rows, 'VariableNames', ...
    {'lambda','kappa_struct','q_th','ContractionCertified', ...
     'BiasBound','BiasWithinBudget','q_hat','InCertifiedWindow'});
writetable(T_lw, fullfile(tbl_dir, 'table5_1c_lambda_window.csv'));
fprintf('[表] %s\n', fullfile('table', 'table5_1c_lambda_window.csv'));
fprintf(['[结论] λ=%.2f 在认证窗口外 (κ=%.2f>1) 的实测 q_hat=%.3f; ' ...
    'λ=%.2f 收缩认证成立但偏差预算 %.3f 超出 ε_acc=%.2f\n'], ...
    lambda_list(1), D_proposed/(2*lambda_list(1)), q_hat_LB(beta_row, 1), ...
    lambda_list(end), lambda_list(end)*bias_coef, eps_acc);

%% 6) 表5-1: N × Method 笛卡尔积, 含 q_hat / q_th / D_theta
fprintf('\n===== 表5-1 W-FBRI 收敛性能与几何压缩率对比 =====\n');
fprintf('%-4s | %-22s | %4s | %8s | %10s | %6s | %6s | %6s | %8s\n', ...
    'N', '方法', '轮数', 'Û_avg', '残差', 'q_hat', 'q_th', 'D(θ)', '时间(s)');
fprintf('%s\n', repmat('-', 1, 105));

T_rows = cell(length(N_list) * num_methods, 9);
row = 1;
for n_idx = 1:length(N_list)
    for m = 1:num_methods
        res = results_all{n_idx, m};
        final_payoff = res.avg_payoff(end);
        final_residual = res.residual(end);
        q_hat_val = q_hat_grid(n_idx, m);
        q_th_val = q_th_list(m);
        D_theta_val = D_theta_list(m);

        fprintf('%-4d | %-22s | %4d | %8.4f | %10.2e | %6.3f | %6.3f | %6.3f | %8.2f\n', ...
            N_list(n_idx), methods{m}, res.iterations, ...
            final_payoff, final_residual, q_hat_val, q_th_val, D_theta_val, res.time);
        T_rows(row, :) = {N_list(n_idx), methods{m}, res.iterations, ...
            final_payoff, final_residual, q_hat_val, q_th_val, D_theta_val, res.time};
        row = row + 1;
    end
end

T = cell2table(T_rows, 'VariableNames', ...
    {'N','Method','Iterations','FinalAvgPayoff','FinalResidual', ...
     'q_hat','q_th','D_theta','RuntimeSec'});
csv_path = fullfile(tbl_dir, 'table5_1_convergence.csv');
writetable(T, csv_path);
fprintf('\n[表] %s\n', fullfile('table', 'table5_1_convergence.csv'));

%% 7) E7: Greedy 收益反超的鲁棒性代价量化 (N=50)
%   Greedy 终态 Ū=0.8325 高于 Proposed 0.7379, 但该优势以三重代价换取:
%   (a) 无收敛证书: 硬最优响应不满足定理 2 前提 (λ→0 ⟹ κ→∞), q_th 不存在;
%   (b) 零决策边距: argmax 间隔可被 FOU 量级扰动击穿 → 决策翻转;
%   (c) 扰动脆弱: 与实验二相同扰动协议 (σ_ξ=δ/2, n=30) 下, 量化
%       决策翻转率 (Greedy argmax 变化的 agent 比例 vs Proposed 软响应 L1 漂移)
%       与 Worst-case Q5 收益跌幅。
fprintf('\n--- E7: Greedy 反超的鲁棒性代价量化 (N=%d) ---\n', N_plot);
params_e7 = params_base;
params_e7.N = N_plot;
[pi_greedy, ~] = sec5_1_greedy_solve(params_e7, delta, theta);
[pi_prop_e7, ~] = sec4_3_1_wfbri_solve(params_e7, delta, theta);

sigma_xi_e7 = delta / 2;       % 与实验二 σ_ξ=δ·0.5 协议一致
n_perturb_e7 = 30;

% (a) Greedy 终态决策边距: 各 agent top-2 纯策略收益间隔
gap_top2 = zeros(params_e7.N, 1);
for i = 1:params_e7.N
    nu_i = sec4_3_1_pure_payoff_vector(pi_greedy, delta, theta, params_e7, i);
    nu_sorted = sort(nu_i, 'descend');
    gap_top2(i) = nu_sorted(1) - nu_sorted(2);
end
fprintf('  Greedy 决策边距 (top-2 ν 间隔): min=%.4f, median=%.4f\n', ...
    min(gap_top2), median(gap_top2));

% (b)(c) 扰动重采样: 决策翻转率 + Worst-case Q5
rng(params_e7.rng_seed + 42);
flip_rate    = zeros(n_perturb_e7, 1);   % Greedy argmax 翻转比例
soft_shift   = zeros(n_perturb_e7, 1);   % Proposed 软响应平均 L1 漂移
U_greedy_pert = zeros(n_perturb_e7, 1);
U_prop_pert   = zeros(n_perturb_e7, 1);
for k = 1:n_perturb_e7
    p = params_e7;
    p.trust_matrix = max(0, min(1, params_e7.trust_matrix + ...
        sigma_xi_e7 * randn(size(params_e7.trust_matrix))));
    p.delay_matrix = max(0, min(1, params_e7.delay_matrix + ...
        sigma_xi_e7 * randn(size(params_e7.delay_matrix))));
    p.res_matrix = max(0, min(1, params_e7.res_matrix + ...
        sigma_xi_e7 * randn(size(params_e7.res_matrix))));

    n_flip = 0; shift_sum = 0;
    for i = 1:p.N
        % Greedy: 扰动后 argmax 是否翻转
        nu_g0 = sec4_3_1_pure_payoff_vector(pi_greedy, delta, theta, params_e7, i);
        nu_g1 = sec4_3_1_pure_payoff_vector(pi_greedy, delta, theta, p, i);
        [~, j0] = max(nu_g0); [~, j1] = max(nu_g1);
        n_flip = n_flip + (j0 ~= j1);
        % Proposed: 软响应 L1 漂移 (softmax 的 Lipschitz 平滑性)
        nu_p0 = sec4_3_1_pure_payoff_vector(pi_prop_e7, delta, theta, params_e7, i);
        nu_p1 = sec4_3_1_pure_payoff_vector(pi_prop_e7, delta, theta, p, i);
        br0 = sec4_3_1_softmax_br(nu_p0, lambda_default);
        br1 = sec4_3_1_softmax_br(nu_p1, lambda_default);
        shift_sum = shift_sum + sum(abs(br1 - br0));
    end
    flip_rate(k) = n_flip / p.N;
    soft_shift(k) = shift_sum / p.N;

    % 扰动收益 (终态策略固定, 状态核扰动)
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_greedy, delta, p);
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    U_hat_g = sec4_2_1_crystallized_payoff(U_l, U_u);
    U_greedy_pert(k) = mean(U_hat_g);
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_prop_e7, delta, p);
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    U_hat_p = sec4_2_1_crystallized_payoff(U_l, U_u);
    U_prop_pert(k) = mean(U_hat_p);
end
WC_greedy = quantile(U_greedy_pert, 0.05);
WC_prop_e7 = quantile(U_prop_pert, 0.05);
U_greedy_nom = results{1}.avg_payoff(end);
U_prop_nom   = results{3}.avg_payoff(end);
drop_greedy = U_greedy_nom - WC_greedy;
drop_prop   = U_prop_nom - WC_prop_e7;
fprintf('  决策稳定性: Greedy argmax 翻转率 = %.1f%% (均值) / %.1f%% (最坏扰动样本);\n', ...
    100 * mean(flip_rate), 100 * max(flip_rate));
fprintf('              Proposed 软响应 L1 漂移均值 = %.4f (连续小幅, Lipschitz 界 ||Δν||_1/λ)\n', ...
    mean(soft_shift));
fprintf('  Worst-case Q5: Greedy %.4f→%.4f (跌幅 %.4f); Proposed %.4f→%.4f (跌幅 %.4f)\n', ...
    U_greedy_nom, WC_greedy, drop_greedy, U_prop_nom, WC_prop_e7, drop_prop);
fprintf('  跌幅比 (Greedy/Proposed) = %.2f\n', drop_greedy / max(drop_prop, eps));

% E7 量化结果导出 (翻转率仅对硬响应 Greedy 有定义; 软响应漂移仅对 Proposed 有定义)
T_e7 = table({'Greedy'; 'Proposed'}, [U_greedy_nom; U_prop_nom], ...
    [WC_greedy; WC_prop_e7], [drop_greedy; drop_prop], ...
    [100 * mean(flip_rate); NaN], [100 * max(flip_rate); NaN], ...
    [NaN; mean(soft_shift)], 'VariableNames', ...
    {'Method', 'NominalPayoff', 'WorstCase_Q5', 'PayoffDrop', ...
     'FlipRateMeanPct', 'FlipRateMaxPct', 'SoftShiftL1Mean'});
writetable(T_e7, fullfile(tbl_dir, 'table5_1b_greedy_fragility.csv'));
fprintf('  [表] %s\n', fullfile('table', 'table5_1b_greedy_fragility.csv'));

%% 8) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) 定理 2 + 命题 1: q_th<1 (条件成立) 且 q_hat <= q_th (上界覆盖实测)
q_hat_fixed = q_hat_grid(default_N_idx, 2);
q_hat_prop  = q_hat_grid(default_N_idx, 3);
fprintf('(i) 几何收敛率核验 (N=%d):\n', N_plot);
fprintf('    Fixed:    q_hat = %.3f <= q_th = %.3f < 1  %s\n', ...
    q_hat_fixed, q_th_list(2), ...
    pass_label(q_hat_fixed <= q_th_list(2) && q_th_list(2) < 1));
fprintf('    Proposed: q_hat = %.3f <= q_th = %.3f < 1  %s\n', ...
    q_hat_prop, q_th_list(3), ...
    pass_label(q_hat_prop <= q_th_list(3) && q_th_list(3) < 1));
fprintf('    [说明] q_th 由命题 1 结构化模量 D(θ) 闭式给出 (κ=D/(2λ)),\n');
fprintf('           默认工作点 λ=%.2f 满足收缩条件; λ<D/2=%.4f 区域超出认证范围\n', ...
    lambda_default, D_proposed/2);

% (ii) Greedy 收敛轮数 <= 3
gr_iter = results{1}.iterations;
fprintf('(ii) Greedy 收敛轮数 = %d %s\n', gr_iter, pass_label(gr_iter <= 3));

% (iii) Proposed U_avg > Fixed-W U_avg (W 机制)
U_prop  = results{3}.avg_payoff(end);
U_fixed = results{2}.avg_payoff(end);
W_gap = U_prop - U_fixed;
fprintf('(iii) W 机制效果: Proposed U=%.4f vs Fixed U=%.4f, 差=%.4f %s\n', ...
    U_prop, U_fixed, W_gap, pass_label(W_gap > 0.005));

% (iv) 收敛轮数 R 关于 N 近似常数 (用 max-min 比值)
R_prop = R_grid(:, 3);
R_ratio = max(R_prop) / min(R_prop);
fprintf('(iv) Proposed R(N) 扩展性: R=[%s], max/min=%.2f %s\n', ...
    num2str(R_prop'), R_ratio, pass_label(R_ratio <= 1.5));

fprintf('\n===== 实验一完成 =====\n');

%% ====== 辅助函数 ======
function sat_ok = check_fou_saturation(params, delta, x_bar_hist)
% CHECK_FOU_SATURATION  命题 1 前提核验: 均匀 FOU 沿迭代轨迹不饱和
%   对每个迭代轮 r 的群体平均策略 x̄(r), 计算各核行的名义隶属度
%   μ_k(j,r) = M_k(j,:)·x̄(r), 检查是否全部落在 [δ, 1-δ] 内
%   (落在该区间内 ⇒ 上下界不发生 [0,1] 裁剪 ⇒ 共同平移消去论证成立)
    mats = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    sat_ok = true;
    for r = 1:size(x_bar_hist, 1)
        xb = x_bar_hist(r, :)';
        for k = 1:3
            mu = mats{k} * xb;
            if any(mu < delta - 1e-12) || any(mu > 1 - delta + 1e-12)
                sat_ok = false;
                return;
            end
        end
    end
end

function s = pass_label(ok)
% 简洁通过/未通过标记
    if ok
        s = '[PASS]';
    else
        s = '[WARN]';
    end
end

function s = yn_label(ok)
% 是/否标记 (用于 λ 窗口分析表的认证状态列)
    if ok
        s = 'YES';
    else
        s = 'NO';
    end
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
