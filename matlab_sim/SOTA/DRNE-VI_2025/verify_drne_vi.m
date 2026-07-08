% verify_drne_vi.m  —  DRNE-VI'25 (Alizadeh-Farsi-Jalilzadeh) 复现自检 (与 solve_drne_vi 同处论文文件夹)
%
% 校验目标 (Karpathy 准则 §4 + 用户"忠实对手论文/保证公正"):
%   1. CVaR 模糊集正确性: max_{p∈P_α}Σp_j v_j == CVaR_α(v) (封顶单纯形 = CVaR 风险包络)。
%   2. GDA 遍历平均收敛: 可利用性 gap 随迭代下降 (DRNE 解质量↑)。
%   3. 风险厌恶: α_dr↑ → 最坏场景权重↑ → 策略更保守 → 最坏场景价值 worstV 上升。
%   4. α 极限: α→0 最坏分布 p̄→均匀 (风险中性/均值); α→1 → 最坏场景集中 (worst-case)。
%   5. solve_drne_vi 输出合法策略剖面 + 跨 seed/N 稳定。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));      % SOTA/DRNE-VI_2025
addpath(script_dir);                                 % 本文件夹: solve_drne_vi
addpath(fullfile(script_dir, '..', '..', 'utils'));  % 共享博弈模型 helper + config_params

params = config_params();
params.fou_modulation = true;
params.R_max = 4000;                                  % DRNE 为 O(1/ε²) 遍历法, 给足迭代预算
params.eps_tol = 1e-4;
params.N = 50;
params.rng_seed = 42;
theta = params.theta;
delta = 0.20;
ns = params.num_strategies;
m = 11; betas = linspace(-1, 1, m);
G = build_reduced_interval_game(params, delta);
Ms = cell(m, 1); for j = 1:m; Ms{j} = G.U_hat + betas(j) * G.rho; end

fprintf('===== DRNE-VI 复现自检 (N=%d, delta=%.2f, m=%d 场景) =====\n', params.N, delta, m);

%% 1. CVaR 模糊集正确性: 封顶单纯形 max == 解析 CVaR
fprintf('\n[1] CVaR 模糊集 max_{p∈P_α}Σp_j v_j == 解析 CVaR_α(v):\n');
rng(3); v = rand(m, 1);                               % 任取场景代价向量
max_gap = 0;
for a_dr = [0.0 0.5 0.8 0.95]
    cap = 1 / (m * (1 - a_dr));
    pmax = cvar_envelope_argmax(v, cap);             % 封顶单纯形上最大化 Σp_j v_j
    val_env = pmax' * v;
    val_cvar = cvar_upper(v, a_dr);                  % 解析上 CVaR
    max_gap = max(max_gap, abs(val_env - val_cvar));
    fprintf('    α=%.2f: cap=%.3f, envelope-max=%.5f, CVaR_α=%.5f, |Δ|=%.2e\n', ...
        a_dr, cap, val_env, val_cvar, abs(val_env - val_cvar));
end
fprintf('    max|envelope - CVaR| = %.3e (应≈0, 即模糊集 = CVaR 风险包络)\n', max_gap);

%% 2. GDA 遍历平均收敛 (gap 下降)
fprintf('\n[2] GDA 遍历平均收敛 (默认 α_dr=0.8):\n');
[pi_d, h_d] = solve_drne_vi(params, delta, theta, 1.0);
fprintf('    converged=%d, R=%d, 末 gap=%.3e\n', h_d.converged, h_d.iterations, h_d.residual(end));
idx = unique(round(linspace(1, numel(h_d.residual), 6)));
fprintf('    gap 轨迹: ');
fprintf('%.2e ', h_d.residual(idx)); fprintf('(应单调下降)\n');
fprintf('    DRNE 策略 π̄=[%.4f %.4f %.4f %.4f]\n', mean(pi_d, 1));

%% 3. 风险厌恶: α_dr↑ → 最坏场景价值上升
fprintf('\n[3] 风险厌恶 (均衡随 α_dr; worstV=min_j π̄''M^j π̄, avgV=mean_j):\n');
fprintf('    α_dr   | R     [SC     SP     DC     DP  ]  worstV   avgV\n');
for a_dr = [0.0 0.4 0.8 0.95]
    p1 = params; p1.drne_alpha = a_dr;
    [pq, hq] = solve_drne_vi(p1, delta, theta, 1.0);
    qd = mean(pq, 1)';
    Vj = zeros(m, 1); for j = 1:m; Vj(j) = qd' * Ms{j} * qd; end
    fprintf('    %.2f   | %-5d [%.3f  %.3f  %.3f  %.3f]  %.4f  %.4f\n', ...
        a_dr, hq.iterations, qd, min(Vj), mean(Vj));
end

%% 4. α 极限: 最坏分布 p̄ 结构
fprintf('\n[4] 最坏分布 p̄ 极限 (m=%d 场景, 索引1=U_lo 最坏 … 索引%d=U_hi 最好):\n', m, m);
for a_dr = [0.001 0.95]
    p1 = params; p1.drne_alpha = a_dr;
    % 取末轮 p̄: 重算一次拿 p_bar (solve 不外露 p̄, 这里复算其等价 CVaR 包络 argmax)
    [pq, ~] = solve_drne_vi(p1, delta, theta, 1.0);
    qd = mean(pq, 1)';
    Vj = zeros(m, 1); for j = 1:m; Vj(j) = qd' * Ms{j} * qd; end
    cap = 1 / (m * (1 - a_dr));
    pbar = cvar_envelope_argmax(-Vj, cap);           % 最坏=最小价值=最大代价(-V)
    fprintf('    α=%.3f: p̄(最坏3场景 idx1-3)=[%.3f %.3f %.3f], p̄(最好 idx%d)=%.3f\n', ...
        a_dr, pbar(1), pbar(2), pbar(3), m, pbar(m));
end
fprintf('    (α→0 应≈均匀≈%.3f; α→1 应集中在最坏场景 idx1)\n', 1/m);

%% 5. 合法 + 跨 seed/N
fprintf('\n[5] 合法策略剖面 + 跨 seed/N (α_dr=0.8):\n');
fprintf('    行和 max|Σ-1|=%.2e, min 元素=%.3e\n', ...
    max(abs(sum(pi_d, 2) - 1)), min(pi_d(:)));
fprintf('    N    seed | R     [SC     SP     DC     DP  ] conv\n');
for Ntest = [20 50 100]
    for stest = [42 44]
        p1 = params; p1.N = Ntest; p1.rng_seed = stest;
        [pq, hq] = solve_drne_vi(p1, delta, theta, 1.0);
        fprintf('    %-4d %-4d | %-5d [%.3f  %.3f  %.3f  %.3f] %d\n', ...
            Ntest, stest, hq.iterations, mean(pq, 1), hq.converged);
    end
end

fprintf('\n===== 自检完成 =====\n');

function p = cvar_envelope_argmax(v, cap)
% 在封顶单纯形 {p:Σp=1,0≤p≤cap} 上最大化 Σ p_j v_j: 贪心地给最大 v 分配 cap。
    [~, idx] = sort(v, 'descend');
    p = zeros(numel(v), 1); remain = 1;
    for k = 1:numel(v)
        take = min(cap, remain);
        p(idx(k)) = take; remain = remain - take;
        if remain <= 1e-15; break; end
    end
end

function c = cvar_upper(v, alpha)
% 上 CVaR_α(v): m 等概率场景, 对最差(代价最大)的 (1-α) 尾部质量做条件均值。
% **独立实现** (尾部质量参数化, 非 cap 封顶参数化), 与 cvar_envelope_argmax 交叉校验。
    m = numel(v);
    if alpha <= 0; c = mean(v); return; end
    vs = sort(v, 'descend');                        % 代价降序
    tail_mass = 1 - alpha; w = zeros(m, 1); remain = tail_mass;
    for i = 1:m
        take = min(1/m, remain);                    % 每场景质量 1/m
        w(i) = take; remain = remain - take;
        if remain <= 1e-15; break; end
    end
    c = (vs' * w) / tail_mass;                       % (1/(1-α)) Σ 尾部质量加权 v
end
