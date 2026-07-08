% diag_m4_geometry.m  [临时诊断脚本, 验证后删除]
%
% 目的 (M4 可行性 / que.md Q1):
%   验证"最优 FOU 聚焦强度 s* 是否可由决策时可见的 ρ 集中度 HHI(ρ) 预测"。这是 M4
%   (风险几何自适应: s*=g(HHI(ρ))) 能否成立的前提。若 profile 从集中→均匀时, HHI 单调
%   下降且最优 s* 也单调下降(集中→大 s、均匀→s≈0), 则映射 g 存在, M4 可行。
%
% 公平性设定 (que.md Q2 的物理假设):
%   "FOU 是风险敞口代理"——冲击按各策略 FOU 暴露 fou_strategy_scale 加权随机命中
%   (shock_mode='dispersed')。集中 profile → 冲击集中在高 FOU 策略; 均匀 profile → 冲击分散。
%   方法只用决策可见的 ρ 决策, 不偷看冲击目标 (信息对称)。
%
% 输出: 每个 profile 的 HHI(ρ) | 最优 s* | CE@s* | CE@s0 | WC@s* | WC@s0 | 增益。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));

base = config_params();
base.fou_modulation = true;
base.R_max = 300;
base.eps_tol = 1e-4;
theta = base.theta;
delta = 0.20;
alpha = 0.50;
N = 50;
seeds = 42:44;
s_grid = [0 1 2 3 5 8 12 20];
gamma_ce = 0.55;
repeats = 200;
p_shock = 0.20;
sigma_small = 0.01;
shock_strength = 0.30;
ns = base.num_strategies;

% FOU 暴露 profile: 从集中 (单一高 FOU 策略) 到近均匀
profiles = { 'P1 concentrated', [1.90 0.50 0.40 0.35]; ...
             'P2 v1-like',      [1.60 1.15 0.85 0.70]; ...
             'P3 medium',       [1.30 1.10 0.95 0.85]; ...
             'P4 near-uniform', [1.05 1.00 0.98 0.97] };

fprintf('M4 geometry diagnostic (N=%d, seeds=%d-%d, alpha=%.2f, gamma=%.2f)\n', ...
    N, seeds(1), seeds(end), alpha, gamma_ce);
fprintf('%-18s %9s | %4s %8s %8s | %8s %8s\n', ...
    'profile', 'HHI(rho)', 's*', 'CE@s*', 'CE@s0', 'WC@s*', 'WC@s0');

results = zeros(size(profiles, 1), 6);
for pidx = 1:size(profiles, 1)
    fou = profiles{pidx, 2};

    % --- HHI(rho): 均匀剖面下 agent1 单方偏移到纯 j 的 rho_j (匹配 solver 截面) ---
    p0 = base; p0.N = N; p0.rng_seed = seeds(1);
    pB0 = scenario_b_env(p0, fou);
    unif = ones(N, ns) / ns;
    [~, ~, ~, rho_j] = sec4_1_2_pure_interval_payoff_vector( ...
        unif, delta, theta, pB0, 1);
    rho_j = rho_j';
    w = rho_j / sum(rho_j);
    HHI = sum(w .^ 2);            % 1/ns(均匀) ~ 1(完全集中)

    % --- 扫 s, 多 seed 评估 (E, WC) → CE ---
    CE_s = zeros(1, numel(s_grid));
    WC_s = zeros(1, numel(s_grid));
    for si = 1:numel(s_grid)
        ce_acc = zeros(numel(seeds), 1);
        wc_acc = zeros(numel(seeds), 1);
        for k = 1:numel(seeds)
            p = base; p.N = N; p.rng_seed = seeds(k);
            pB = scenario_b_env(p, fou);
            pB.shock_mode = 'dispersed';   % 冲击按 FOU 暴露加权 (FOU=风险代理)
            [pi_star, ~] = sec5_1_alpha_robust_solve(pB, delta, theta, alpha, s_grid(si));
            [E, WC] = scenario_b_payoff_stats(pi_star, delta, theta, pB, ...
                repeats, p_shock, sigma_small, shock_strength);
            ce_acc(k) = E - gamma_ce * (E - WC);
            wc_acc(k) = WC;
        end
        CE_s(si) = mean(ce_acc);
        WC_s(si) = mean(wc_acc);
    end
    [ce_best, bi] = max(CE_s);
    s_star = s_grid(bi);
    results(pidx, :) = [HHI, s_star, ce_best, CE_s(1), WC_s(bi), WC_s(1)];
    fprintf('%-18s %9.4f | %4d %8.4f %8.4f | %8.4f %8.4f\n', ...
        profiles{pidx, 1}, HHI, s_star, ce_best, CE_s(1), WC_s(bi), WC_s(1));

    % 打印整条 CE(s) 曲线, 看单调性/平台
    fprintf('   CE(s): ');
    for si = 1:numel(s_grid)
        fprintf('s%d=%.4f ', s_grid(si), CE_s(si));
    end
    fprintf('\n');
end

fprintf('\n--- M4 verdict ---\n');
fprintf('HHI 单调? %s | s* 随 HHI 单调? %s\n', ...
    tf(issorted(results(:,1), 'descend')), ...
    tf(issorted(results(:,2), 'descend')));
fprintf('[diag] done.\n');

function s = tf(b)
    if b; s = 'YES'; else; s = 'NO'; end
end
