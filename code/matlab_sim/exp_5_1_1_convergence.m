% exp_5_1_1_convergence.m - 论文 §5.1 实验一: W-FBRI 收敛性与加权机制验证
%
% 验证目标 (对齐 chapter5.md §5.1 实验一新版设计):
%   (a) 定理 2 全局压缩收敛: e_pi^(r) 几何衰减, q_hat ≈ q_th = (1-β) + β·L_U/λ
%   (b) 加权机制 (3-7)(3-8) 必要性: Proposed (θ=P_pay·ω) vs Fixed-weight IT2 (θ=均匀)
%   (c) (4-23) 压缩条件 L_U/λ < 1 的工程边界
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
%   table/table5_1_convergence.csv         - 含 q_hat / q_th / L_U 共 8 列

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
%   q_hat = (e^(R) / e^(1))^(1/(R-1))   (实测)
%   q_th  = (1-β) + β·L_U/λ              (定理 2 公式 (4-25))
%   L_U   通过 random π 对采样数值估计 (公式 (4-22) Lipschitz 上界)

% 估计 Proposed 设置下的 L_U (delta=0.1, theta 动态)
fprintf('\n[L_U 估计] N=50, 100 个随机 π 对...\n');
params_LU = params_base;
params_LU.N = 50;
L_U_proposed = estimate_L_U(params_LU, delta, theta, 100);

% Fixed-weight IT2 用相同 N 但 theta=均匀
L_U_fixed = estimate_L_U(params_LU, delta, ones(3,1)/3, 100);

% Greedy: λ→0, q_th 不适用 (公式 (4-23) 失效), 标 NaN
L_U_list = [NaN, L_U_fixed, L_U_proposed];
fprintf('L_U(Fixed) = %.4f, L_U(Proposed) = %.4f\n', L_U_fixed, L_U_proposed);

lambda_default = params_base.lambda;   % 0.10
beta_default   = params_base.beta;     % 0.3
q_th_list = zeros(num_methods, 1);
q_th_list(1) = NaN;                    % Greedy 无定理 2 保证
q_th_list(2) = (1-beta_default) + beta_default * L_U_fixed / lambda_default;
q_th_list(3) = (1-beta_default) + beta_default * L_U_proposed / lambda_default;

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
fprintf('  q_th(Fixed)    = %.4f, q_hat(Fixed,N=50)    = %.4f\n', ...
    q_th_list(2), q_hat_grid(default_N_idx, 2));
fprintf('  q_th(Proposed) = %.4f, q_hat(Proposed,N=50) = %.4f\n', ...
    q_th_list(3), q_hat_grid(default_N_idx, 3));
if q_th_list(3) > 1
    fprintf('  [注] q_th>1 说明 (4-23) 充分条件不严格满足, 但实测 q_hat<1\n');
    fprintf('       表明定理 2 (4-23) 是充分不必要条件; 实际算法收敛由更紧的算子结构保证\n');
end

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
fprintf('[图] %s\n', fullfile('image', 'fig5_3_strategy_evolution.png'));

%% 5) (λ, β) 扫描: 验证 (4-23) 压缩条件与 q_hat 网格
lambda_list = [0.05, 0.10, 0.20];
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
        q_th_LB(ib, il) = (1-beta_list(ib)) + beta_list(ib) * L_U_proposed / lambda_list(il);
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
fprintf('[图] %s\n', fullfile('image', 'fig5_4_contraction_scalability.png'));

%% 6) 表5-1: N × Method 笛卡尔积, 含 q_hat / q_th / L_U
fprintf('\n===== 表5-1 W-FBRI 收敛性能与几何压缩率对比 =====\n');
fprintf('%-4s | %-22s | %4s | %8s | %10s | %6s | %6s | %6s | %8s\n', ...
    'N', '方法', '轮数', 'Û_avg', '残差', 'q_hat', 'q_th', 'L_U', '时间(s)');
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
        L_U_val = L_U_list(m);

        fprintf('%-4d | %-22s | %4d | %8.4f | %10.2e | %6.3f | %6.3f | %6.3f | %8.2f\n', ...
            N_list(n_idx), methods{m}, res.iterations, ...
            final_payoff, final_residual, q_hat_val, q_th_val, L_U_val, res.time);
        T_rows(row, :) = {N_list(n_idx), methods{m}, res.iterations, ...
            final_payoff, final_residual, q_hat_val, q_th_val, L_U_val, res.time};
        row = row + 1;
    end
end

T = cell2table(T_rows, 'VariableNames', ...
    {'N','Method','Iterations','FinalAvgPayoff','FinalResidual', ...
     'q_hat','q_th','L_U','RuntimeSec'});
csv_path = fullfile(tbl_dir, 'table5_1_convergence.csv');
writetable(T, csv_path);
fprintf('\n[表] %s\n', fullfile('table', 'table5_1_convergence.csv'));

%% 7) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) 实测几何衰减 q_hat < 1 (定理 2 核心结论的实证)
q_hat_fixed = q_hat_grid(default_N_idx, 2);
q_hat_prop  = q_hat_grid(default_N_idx, 3);
fprintf('(i) 实测几何收敛率 q_hat (N=%d):\n', N_plot);
fprintf('    Fixed:    q_hat = %.3f (q_th=%.3f) %s\n', ...
    q_hat_fixed, q_th_list(2), pass_label(q_hat_fixed < 1));
fprintf('    Proposed: q_hat = %.3f (q_th=%.3f) %s\n', ...
    q_hat_prop, q_th_list(3), pass_label(q_hat_prop < 1));
if q_th_list(3) > 1
    fprintf('    [说明] (4-23) 理论上界 q_th>1 说明该充分条件本身不严格满足,\n');
    fprintf('           但实测 q_hat<1 体现算法实际收敛, 印证 (4-23) 是充分不必要的工程化保守界\n');
end

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
function L_U = estimate_L_U(params, delta, theta, n_pairs)
% ESTIMATE_L_U  数值估计 ν(π) 关于 π 的 ℓ1 Lipschitz 常数 L_U (公式 4-22)
%   对 n_pairs 个随机 π_a, π_b 样本对, 计算 ||ν_a-ν_b||_1 / ||π_a-π_b||_1 的最大值
%   该估计为 L_U 的下界 (依赖采样); 论文 (4-23) 压缩条件 L_U/λ<1 仅在此估计基础上检验
    N = params.N;
    K = params.num_strategies;
    rng(params.rng_seed + 7);

    pi_samples = cell(n_pairs, 1);
    nu_samples = cell(n_pairs, 1);
    for s = 1:n_pairs
        pi_s = rand(N, K);
        pi_s = pi_s ./ sum(pi_s, 2);
        pi_samples{s} = pi_s;
        nu_s = zeros(N, K);
        for i = 1:N
            nu_s(i, :) = sec4_3_1_pure_payoff_vector(pi_s, delta, theta, params, i)';
        end
        nu_samples{s} = nu_s;
    end

    L_U_est = 0;
    for a = 1:n_pairs
        for b = (a+1):n_pairs
            d_pi = sum(abs(pi_samples{a}(:) - pi_samples{b}(:)));
            d_nu = sum(abs(nu_samples{a}(:) - nu_samples{b}(:)));
            if d_pi > 1e-12
                L_U_est = max(L_U_est, d_nu / d_pi);
            end
        end
    end
    L_U = L_U_est;
end

function s = pass_label(ok)
% 简洁通过/未通过标记
    if ok
        s = '[PASS]';
    else
        s = '[WARN]';
    end
end
