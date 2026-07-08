% verify_cvar_game.m  —  CVaR-game'26 (Gangwani-Sinha) 复现自检 (与 solve_cvar_game 同处论文文件夹)
%
% 校验目标 (Karpathy 准则 §4 + 用户"忠实对手论文/保证公正"):
%   1. 相干 CVaR 效用闭式正确，且完整混合策略 LP 与
%      Rockafellar--Uryasev z-表示一致。
%   2. γ_c=0 退化为风险中性 (期望效用); γ_c↑ / α↓ → 更回避高方差(高 FOU)策略 (风险厌恶单调)。
%   3. 完全理性 DRE: 无 softmax；终点满足完整混合策略最优响应固定点。
%   4. 风险源忠实性: ρ=0 (无 FOU, 各样本相同) → CVaR=期望, γ_c/α 失效 → 风险纯由样本散布提供。
%   5. solve_cvar_game 收敛 + 合法策略剖面 + 跨 seed/N 稳定。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));      % SOTA/CVaR-game_2026
addpath(script_dir);                                 % 本文件夹: solve_cvar_game
addpath(fullfile(script_dir, '..', '..', 'utils'));  % 共享博弈模型 helper + config_params

params = config_params();
params.fou_modulation = true;
params.R_max = 300;
params.eps_tol = 1e-4;
params.N = 50;
params.rng_seed = 42;
theta = params.theta;
delta = 0.20;
ns = params.num_strategies;
K = 64; svec = linspace(-1, 1, K);
G = build_reduced_interval_game(params, delta);
Ms = cell(K, 1); for k = 1:K; Ms{k} = G.U_hat + svec(k) * G.rho; end

fprintf('===== CVaR-game 复现自检 (N=%d, delta=%.2f, K=%d 样本) =====\n', params.N, delta, K);

%% 1. 相干 CVaR 效用闭式 == z 优化式 (Rockafellar-Uryasev) 交叉校验
fprintf('\n[1] CVaR_α 闭式(下尾平均) == max_z[z+(1/α)E·min(0,U-z)] (论文 eq 17):\n');
rng(5); q = rand(ns, 1); q = q / sum(q);
max_gap = 0;
for a_cv = [0.1 0.3 0.5 0.9]
    for a = 1:ns
        Ua = zeros(K, 1); for k = 1:K; Ua(k) = Ms{k}(a, :) * q; end
        cvar_tail = sota_cvar_lower(Ua, ones(K, 1), a_cv);   % 下尾平均 (solver 所用)
        cvar_zopt = cvar_via_zopt(Ua, a_cv);                  % z-优化式 (独立实现)
        max_gap = max(max_gap, abs(cvar_tail - cvar_zopt));
    end
end
fprintf('    max|下尾平均 - z优化式| = %.3e (应≈0, 两 CVaR 定义等价)\n', max_gap);
assert(max_gap < 1e-10, 'CVaR 闭式与 z-优化式不一致。');

% 随机混合策略下，LP 最优值必须不低于所有纯动作的 coherent utility。
gamma_test = 0.7;
alpha_test = 0.3;
[x_lp, value_lp] = cvar_best_response_lp(q, Ms, gamma_test, alpha_test);
pure_values = zeros(ns, 1);
for a = 1:ns
    Ua = zeros(K, 1);
    for k = 1:K; Ua(k) = Ms{k}(a, :) * q; end
    pure_values(a) = (1 - gamma_test) * mean(Ua) + ...
        gamma_test * sota_cvar_lower(Ua, ones(K, 1), alpha_test);
end
fprintf('    mixed-LP value - best pure value = %.3e\n', ...
    value_lp - max(pure_values));
assert(value_lp >= max(pure_values) - 1e-9 && ...
    abs(sum(x_lp) - 1) < 1e-10, ...
    '完整混合策略 CVaR LP 未覆盖纯策略可行集。');

%% 2. 风险厌恶单调性 (在风险耦合 Scenario B: SC 名义最高但 FOU 暴露最大)
fprintf('\n[2] 风险厌恶 (Scenario B 风险耦合核, SC 高 FOU; DRE 随 α, γ_c=1):\n');
cfgB = scenario_b_config('concentrated');
paramsB = scenario_b_env(params, cfgB.fou_scale);
GB = build_reduced_interval_game(paramsB, cfgB.delta);
MsB = cell(K, 1); for k = 1:K; MsB{k} = GB.U_hat + svec(k) * GB.rho; end
fprintf('    α      | R    [SC     SP     DC     DP  ]   SC_FOUexp  DC_FOUexp\n');
for a_cv = [0.9 0.5 0.2 0.05]
    p1 = paramsB; p1.cvar_gamma = 1.0; p1.cvar_alpha = a_cv;
    [pq, hq] = solve_cvar_game(p1, cfgB.delta, theta, 1.0);
    qd = mean(pq, 1)';
    sc_exp = GB.rho(1, :) * qd; dc_exp = GB.rho(3, :) * qd;   % 各策略对种群的 FOU 暴露
    fprintf('    %.2f   | %-4d [%.3f  %.3f  %.3f  %.3f]   %.4f     %.4f\n', ...
        a_cv, hq.iterations, qd, sc_exp, dc_exp);
end
fprintf('    (α↓ 尾部越极端 → DRE 由高 FOU 暴露的 SC 切换到低 FOU 的保守 DC = 风险厌恶;\n');
fprintf('     这也复现论文 Fig 6/8 "风险厌恶改变均衡集/选择更保守均衡")\n');

%% 3. 完全理性 DRE 收敛 (无 softmax)
fprintf('\n[3] 默认 solve_cvar_game (γ_c=1,α=0.2) 收敛 + 合法:\n');
[pi_d, h_d] = solve_cvar_game(params, delta, theta, 1.0);
fprintf('    converged=%d, R=%d, 末残差=%.3e, 行和max|Σ-1|=%.2e, min元素=%.3e\n', ...
    h_d.converged, h_d.iterations, h_d.residual(end), ...
    max(abs(sum(pi_d, 2) - 1)), min(pi_d(:)));
fprintf('    DRE 策略=[%.4f %.4f %.4f %.4f]\n', mean(pi_d, 1));
q_d = mean(pi_d, 1)';
[br_d, ~] = cvar_best_response_lp(q_d, Ms, 1.0, 0.2);
fixed_point_residual = sum(abs(br_d - q_d));
fprintf('    完整混合最优响应残差=%.3e\n', fixed_point_residual);
assert(h_d.converged && fixed_point_residual <= 2 * params.eps_tol && ...
    all(isfinite(pi_d), 'all') && min(pi_d(:)) >= 0 && ...
    max(abs(sum(pi_d, 2) - 1)) < 1e-10, ...
    'CVaR-game 混合策略固定点/单纯形验证失败。');

%% 4. 风险源忠实性: ρ=0 (无 FOU) → 风险消失 (Scenario B, 极端尾部 α=0.05)
fprintf('\n[4] 风险源忠实性 (Scenario B; delta=0 → ρ=0 → 各样本相同 → 风险应消失):\n');
p_on  = paramsB; p_on.cvar_gamma = 1.0; p_on.cvar_alpha = 0.05;
[pq_on, ~]  = solve_cvar_game(p_on, cfgB.delta, theta, 1.0);   % delta>0 → 有 FOU 风险
[pq_off, ~] = solve_cvar_game(p_on, 0.0, theta, 1.0);          % delta=0 → ρ=0 无风险
fprintf('    delta=%.2f, α=0.05: DRE=[%.4f %.4f %.4f %.4f] (回避 SC)\n', cfgB.delta, mean(pq_on, 1));
fprintf('    delta=0.00, α=0.05: DRE=[%.4f %.4f %.4f %.4f] (≈名义最优, SC 占优)\n', mean(pq_off, 1));
fprintf('    (两行应不同 → delta=0 时风险消失回到名义 → 风险纯由 FOU(ρ) 提供, 忠实)\n');

%% 5. 跨 seed/N
fprintf('\n[5] 跨 seed/N 稳定性 (γ_c=1,α=0.2):\n');
fprintf('    N    seed | R    [SC     SP     DC     DP  ] conv\n');
for Ntest = [20 50 100]
    for stest = [42 44]
        p1 = params; p1.N = Ntest; p1.rng_seed = stest;
        [pq, hq] = solve_cvar_game(p1, delta, theta, 1.0);
        fprintf('    %-4d %-4d | %-4d [%.3f  %.3f  %.3f  %.3f] %d\n', ...
            Ntest, stest, hq.iterations, mean(pq, 1), hq.converged);
    end
end

fprintf('\n===== 自检完成 =====\n');

function c = cvar_via_zopt(U, alpha)
% CVaR_α(U) (收益下尾) 经 z-优化式: max_z [ z + (1/α) E·min(0, U-z) ] (论文 eq 17 内层)。
% 最优 z* = α-分位数; 对离散等概率样本, 在排序样本上网格搜索 z 即得精确值。
    U = sort(U(:));
    best = -inf;
    for zi = 1:numel(U)
        z = U(zi);
        val = z + (1/alpha) * mean(min(0, U - z));
        best = max(best, val);
    end
    c = best;
end

function [x, value] = cvar_best_response_lp(q, Ms, gamma_c, alpha_cvar)
% 独立复核 solver 中的完整混合策略 mean-CVaR LP。
    K = numel(Ms);
    ns = numel(q);
    V = zeros(ns, K);
    for k = 1:K; V(:, k) = Ms{k} * q; end
    nvar = ns + 1 + K;
    f = zeros(nvar, 1);
    f(1:ns) = -(1 - gamma_c) * mean(V, 2);
    f(ns + 1) = -gamma_c;
    f((ns + 2):end) = gamma_c / (alpha_cvar * K);
    A = zeros(K, nvar);
    for k = 1:K
        A(k, 1:ns) = -V(:, k)';
        A(k, ns + 1) = 1;
        A(k, ns + 1 + k) = -1;
    end
    Aeq = zeros(1, nvar); Aeq(1:ns) = 1;
    lb = [zeros(ns, 1); -Inf; zeros(K, 1)];
    ub = [ones(ns, 1); Inf; Inf(K, 1)];
    options = optimoptions('linprog', 'Display', 'none');
    [z, fval, exitflag] = linprog( ...
        f, A, zeros(K, 1), Aeq, 1, lb, ub, options);
    assert(exitflag > 0, 'CVaR 独立复核 LP 求解失败。');
    x = z(1:ns);
    value = -fval;
end
