% verify_rqe.m  —  RQE'24 (Mazumdar-Panaganti-Shi) 复现自检 (与 solve_rqe 同处论文文件夹)
%
% 校验目标 (Karpathy 准则 §4 目标驱动 + 用户"严格保证算法与论文一致性"):
%   1. 完整混合策略风险代价 = 论文对偶表示
%      sup_p[-x'Mp-(1/τ)KL(p,q)] 的精确解。
%   2. τ→0 极限退化为期望收益 (风险中性), τ→∞ 趋于对手支撑上最坏收益 (风险规避)。
%   3. 终点满足 Definition 5 的混合策略 KKT/固定点条件，而非纯动作 softmax 捷径。
%   4. solve_rqe 收敛 (converged=true), 输出合法策略剖面。
%   5. 跨 seed/N 鲁棒稳定。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));      % SOTA/RQE_2024
addpath(script_dir);                                 % 本文件夹: solve_rqe
addpath(fullfile(script_dir, '..', '..', 'utils'));  % 共享博弈模型 helper + config_params

params = config_params();
params.fou_modulation = true;
params.R_max = 300;
params.eps_tol = 1e-4;
params.N = 50;
params.rng_seed = 42;
theta = params.theta;
M = sota_reduced_matrix(theta, params);              % 4×4 归约收益矩阵
ns = params.num_strategies;

fprintf('===== RQE 复现自检 (N=%d, seed=%d) =====\n', params.N, params.rng_seed);
fprintf('归约收益矩阵 M(a,k) (行=本方纯策略, 列=种群纯策略):\n');
disp(M);

%% 1. 完整混合策略风险代价 == 论文对偶 sup (Example 1)
fprintf('[1] 混合策略 f(x,q) == sup_p[-x''Mp-(1/τ)KL(p,q)] 验证:\n');
rng(7);
q = rand(ns, 1); q = q / sum(q);
x = rand(ns, 1); x = x / sum(x);
tau = 5.0;
c = M' * x;
z = -tau * c; zmax = max(z);
f_closed = (zmax + log(sum(q .* exp(z - zmax)))) / tau;
pstar = q .* exp(z - zmax); pstar = pstar / sum(pstar);
obj = @(p) -x' * M * p - (1/tau) * ...
    sum(p .* log((p + 1e-300) ./ q));
f_gibbs = obj(pstar);
max_viol = -Inf;
for t = 1:200
    d = randn(ns, 1); d = d - mean(d);
    p2 = pstar + 0.02 * d;
    if all(p2 > 0)
        max_viol = max(max_viol, obj(p2) - f_gibbs);
    end
end
dual_gap = abs(f_gibbs - f_closed);
fprintf('    |f_closed - f(p*)| = %.3e (应≈0)\n', dual_gap);
fprintf('    max(obj(p_perturb) - obj(p*)) = %.3e (应≤0, 即 p* 为最优)\n', max_viol);
assert(dual_gap < 1e-10 && max_viol <= 1e-10, ...
    'RQE 混合策略熵风险对偶验证失败。');

%% 2. τ 极限: τ→0 期望收益; τ→∞ 对手支撑最坏收益
fprintf('\n[2] τ 极限行为 (固定 q, 策略 a=1=SC):\n');
a = 1; c = M(a, :)';
exp_payoff = q' * c;
worst = min(c(q > 1e-12));                            % 对手支撑上最坏收益
nu_of = @(t) -(1/t) * ( max(-t*c) + log(sum(q .* exp(-t*c - max(-t*c)))) );
fprintf('    期望收益 Σq_kM(1,k) = %.4f\n', exp_payoff);
fprintf('    ν(τ=0.01) = %.4f  (应≈期望收益)\n', nu_of(0.01));
fprintf('    ν(τ=5)    = %.4f\n', nu_of(5));
fprintf('    ν(τ=200)  = %.4f  (应≈最坏收益 %.4f)\n', nu_of(200), worst);

%% 3. Definition 5 终点 KKT/固定点验证
fprintf('\n[3] Definition 5 混合策略 KKT/固定点残差:\n');
params.rqe_tau = 5;
[pi_kkt, h_kkt] = solve_rqe(params, 0, theta, 1.0);
q_kkt = mean(pi_kkt, 1)';
r_kkt = M' * q_kkt;
z_kkt = -params.rqe_tau * r_kkt;
z_kkt = z_kkt - max(z_kkt);
p_kkt = q_kkt .* exp(z_kkt);
p_kkt = p_kkt / sum(p_kkt);
kkt_target = sec4_3_1_softmax_br(M * p_kkt, params.lambda);
kkt_residual = sum(abs(kkt_target - q_kkt));
fprintf('    ||softmax(Mp*/lambda)-q*||_1 = %.3e\n', kkt_residual);
assert(h_kkt.converged && kkt_residual <= 2 * params.eps_tol, ...
    'RQE 终点不满足混合策略 KKT/固定点条件。');

%% 4. 风险参数扫描（仅披露，不预设某个动作份额单调）
fprintf('\n[4] RQE 均衡随 τ 的经验变化 [SC SP DC DP]:\n');
fprintf('    τ      | R    [SC      SP      DC      DP   ] conv\n');
for tau = [0.01 1 5 20 100]
    q1 = params; q1.rqe_tau = tau;
    [pq, hq] = solve_rqe(q1, 0, theta, 1.0);
    d = mean(pq, 1);
    fprintf('    %-6g | %-4d [%.4f  %.4f  %.4f  %.4f] %d\n', ...
        tau, hq.iterations, d, hq.converged);
end

%% 5. 默认 solve_rqe 收敛 + 合法策略剖面
fprintf('\n[5] 默认 solve_rqe (τ=5) 收敛性 + 合法性:\n');
[pi_rqe, h_rqe] = solve_rqe(params, 0, theta, 1.0);
fprintf('    converged=%d, R=%d, 末残差=%.3e\n', ...
    h_rqe.converged, h_rqe.iterations, h_rqe.residual(end));
fprintf('    行和 max|Σ-1|=%.2e, min 元素=%.3e (应≥0)\n', ...
    max(abs(sum(pi_rqe, 2) - 1)), min(pi_rqe(:)));
fprintf('    终点分布=[%.4f %.4f %.4f %.4f]\n', mean(pi_rqe, 1));
assert(h_rqe.converged && all(isfinite(pi_rqe), 'all') && ...
    max(abs(sum(pi_rqe, 2) - 1)) < 1e-10 && min(pi_rqe(:)) >= 0, ...
    'RQE 默认求解器收敛/单纯形验证失败。');

%% 6. 跨 seed/N 鲁棒性
fprintf('\n[6] 跨 seed/N 鲁棒性 (τ=5):\n');
fprintf('    N    seed | R    [SC      SP      DC      DP   ] conv\n');
for Ntest = [20 50 100]
    for stest = [42 44 46]
        q1 = params; q1.N = Ntest; q1.rng_seed = stest;
        [pq, hq] = solve_rqe(q1, 0, theta, 1.0);
        d = mean(pq, 1);
        fprintf('    %-4d %-4d | %-4d [%.4f  %.4f  %.4f  %.4f] %d\n', ...
            Ntest, stest, hq.iterations, d, hq.converged);
    end
end

fprintf('\n===== 自检完成 =====\n');
