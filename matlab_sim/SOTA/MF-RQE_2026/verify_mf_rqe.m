% verify_mf_rqe.m  —  MF-RQE'26 (Jeloka-Guan-Tsiotras) 复现自检 (与 solve_mf_rqe 同处论文文件夹)
%
% 校验目标 (Karpathy 准则 §4 + 用户"忠实对手论文/保证公正"):
%   1. 熵风险对偶表示精确性: c=(1/τ)logΣ_k Γ*(k)e^{-τV^k} == sup_Γ̂[-E_Γ̂[V]-(1/τ)KL(Γ̂,Γ*)]
%      (论文 eq 6-7), 用 Gibbs 最优 Γ̂* 回代 + 随机扰动确认最优。
%   2. τ 极限: τ→0 对场景集 𝕄 取期望 (风险中性); τ→∞ 趋于 𝕄 上最坏场景 (最坏鲁棒)。
%   3. 风险厌恶: τ 增大 → 均衡更对冲初始分布不确定性 → **最坏场景价值上升** (以均值换鲁棒)。
%   4. 风险源忠实性: K=1 (无分布不确定性) → 退化为风险中性 QRE, 证明风险**仅**来自场景集 𝕄。
%   5. solve_mf_rqe 收敛 + 合法策略剖面 + 跨 seed/N 稳定。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));      % SOTA/MF-RQE_2026
addpath(script_dir);                                 % 本文件夹: solve_mf_rqe
addpath(fullfile(script_dir, '..', '..', 'utils'));  % 共享博弈模型 helper + config_params

params = config_params();
params.fou_modulation = true;
params.R_max = 300;
params.eps_tol = 1e-4;
params.N = 50;
params.rng_seed = 42;
theta = params.theta;
delta = 0.20;                                        % 鲁棒赛道真实 FOU (界定场景集合)
ns = params.num_strategies;

G = build_reduced_interval_game(params, delta);
K = 3; betas = linspace(-1, 1, K);
Ms = cell(K, 1);
for s = 1:K; Ms{s} = G.U_hat + betas(s) * G.rho; end

fprintf('===== MF-RQE 复现自检 (N=%d, delta=%.2f, K=%d 场景) =====\n', params.N, delta, K);
fprintf('场景收益矩阵端点: U_lo(β=-1) / U_hat(β=0) / U_hi(β=+1) 由 IT2 FOU 区间给出\n');

%% 1. 熵风险对偶表示精确性
fprintf('\n[1] 熵风险对偶 c=(1/τ)logΣΓ*(k)e^{-τV^k} == sup_Γ̂[-E[V]-(1/τ)KL] 验证:\n');
rng(11); q = rand(ns, 1); q = q / sum(q);
gam = ones(K, 1) / K; tau = 5.0;
V = zeros(K, 1);
for s = 1:K; V(s) = q' * Ms{s} * q; end          % 各场景策略价值 V^s
z = -tau * V; zmax = max(z);
c_closed = (1/tau) * (zmax + log(sum(gam .* exp(z - zmax))));
% Gibbs 最优对抗分布 Γ̂*_s ∝ Γ*_s exp(-τ V^s)
Ghat = gam .* exp(-tau * V); Ghat = Ghat / sum(Ghat);
obj = @(G_) -G_' * V - (1/tau) * sum(G_ .* log((G_ + 1e-300) ./ gam));
c_gibbs = obj(Ghat);
max_viol = 0;
for t = 1:300
    d = randn(K, 1); d = d - mean(d); G2 = Ghat + 0.02 * d;
    if all(G2 > 0); max_viol = max(max_viol, obj(G2) - c_gibbs); end
end
fprintf('    |c_closed - c(Γ̂*)| = %.3e (应≈0)\n', abs(c_closed - c_gibbs));
fprintf('    max(obj(Γ̂_perturb) - obj(Γ̂*)) = %.3e (应≤0, 即 Γ̂* 为最优)\n', max_viol);
assert(abs(c_closed - c_gibbs) < 1e-10 && max_viol <= 1e-10, ...
    'MF-RQE 场景风险对偶验证失败。');

%% 2. τ 极限行为 (固定 q)
fprintf('\n[2] τ 极限 (风险倾斜场景权重 w 与风险调整价值):\n');
avgV = gam' * V; worstV = min(V);
wfun = @(t) softmaxw(gam, -t * V);
fprintf('    场景价值 V = [%.4f %.4f %.4f], 均值=%.4f, 最坏=%.4f\n', V, avgV, worstV);
w0 = wfun(0.01); winf = wfun(500);
fprintf('    τ=0.01: w=[%.3f %.3f %.3f] (应≈均匀 Γ*)\n', w0);
fprintf('    τ=500 : w=[%.3f %.3f %.3f] (应≈最坏场景 one-hot)\n', winf);

%% 3. 风险厌恶: τ↑ → 最坏场景价值上升 (以均值换鲁棒)
fprintf('\n[3] 风险厌恶 (均衡随 τ; worstV=min_s q''M^s q, avgV=Σγ_s q''M^s q):\n');
fprintf('    τ      | R    [SC     SP     DC     DP  ]  worstV   avgV\n');
prev_worst = -inf;
for tau = [0.01 1 5 20 100]
    p1 = params; p1.mfrqe_tau = tau;
    [pq, hq] = solve_mf_rqe(p1, delta, theta, 1.0);
    qd = mean(pq, 1)';
    Vk = zeros(K, 1); for s = 1:K; Vk(s) = qd' * Ms{s} * qd; end
    fprintf('    %-6g | %-4d [%.3f  %.3f  %.3f  %.3f]  %.4f  %.4f\n', ...
        tau, hq.iterations, qd, min(Vk), gam' * Vk);
end

%% 4. 风险源忠实性: K=1 (无分布不确定性) → 风险中性 QRE
fprintf('\n[4] 风险源忠实性 (K=1 单场景 → 风险应消失, 与 τ 无关):\n');
single_scene_profiles = zeros(2, ns);
tau_values = [1 100];
for idx = 1:numel(tau_values)
    tau = tau_values(idx);
    p1 = params; p1.mfrqe_K = 1; p1.mfrqe_tau = tau;
    [pq, ~] = solve_mf_rqe(p1, delta, theta, 1.0);
    single_scene_profiles(idx, :) = mean(pq, 1);
    fprintf('    K=1, τ=%-4g: 终点=[%.4f %.4f %.4f %.4f]\n', tau, mean(pq, 1));
end
fprintf('    (两行应几乎相同 → 单场景下 τ 无效 → 风险纯由场景集 𝕄 提供, 忠实)\n');
assert(norm(single_scene_profiles(1, :) - single_scene_profiles(2, :), 1) ...
    <= 2 * params.eps_tol, 'MF-RQE 单场景退化性质失败。');

%% 5. 默认收敛 + 合法 + 跨 seed/N
fprintf('\n[5] 默认 solve_mf_rqe (τ=5,K=3) 收敛 + 合法 + 跨 seed/N:\n');
[pi_d, h_d] = solve_mf_rqe(params, delta, theta, 1.0);
fprintf('    converged=%d, R=%d, 末残差=%.3e, 行和max|Σ-1|=%.2e, min元素=%.3e\n', ...
    h_d.converged, h_d.iterations, h_d.residual(end), ...
    max(abs(sum(pi_d, 2) - 1)), min(pi_d(:)));
q_d = mean(pi_d, 1)';
Q_d = zeros(ns, K);
for s = 1:K; Q_d(:, s) = Ms{s} * q_d; end
V_d = Q_d' * q_d;
w_d = softmaxw(gam, -5.0 * V_d);
kkt_target = sec4_3_1_softmax_br(Q_d * w_d, params.lambda);
kkt_residual = sum(abs(kkt_target - q_d));
fprintf('    完整混合 B_opt KKT 残差=%.3e\n', kkt_residual);
assert(h_d.converged && kkt_residual <= 2 * params.eps_tol && ...
    all(isfinite(pi_d), 'all') && min(pi_d(:)) >= 0 && ...
    max(abs(sum(pi_d, 2) - 1)) < 1e-10, ...
    'MF-RQE 完整混合策略固定点/单纯形验证失败。');
fprintf('    N    seed | R    [SC     SP     DC     DP  ] conv\n');
for Ntest = [20 50 100]
    for stest = [42 44 46]
        p1 = params; p1.N = Ntest; p1.rng_seed = stest;
        [pq, hq] = solve_mf_rqe(p1, delta, theta, 1.0);
        fprintf('    %-4d %-4d | %-4d [%.3f  %.3f  %.3f  %.3f] %d\n', ...
            Ntest, stest, hq.iterations, mean(pq, 1), hq.converged);
    end
end

fprintf('\n===== 自检完成 =====\n');

function w = softmaxw(gam, z)
    zmax = max(z); w = gam .* exp(z - zmax); w = w / sum(w);
end
