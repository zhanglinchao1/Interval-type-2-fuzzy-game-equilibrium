function [pi_star, history] = solve_rqe(params, delta, theta, alpha)
%SOLVE_RQE  Risk-averse Quantal Response Equilibrium (鲁棒赛道 SOTA, 熵风险/KL 忠实版)。
%
%   参考: Mazumdar, Panaganti & Shi 2024, "Tractable Equilibrium Computation in
%         Markov Games through Risk Aversion" (arXiv:2406.14156, 2024)。
%
%   复现要点:
%     (1) 风险针对**对手随机性**(非自身随机性): 论文 §2.1 明确"risk averse only to
%         the randomness introduced by their opponents"。本归约博弈中"对手"即种群
%         分布 q, 风险作用于代表 agent 对种群混合 q 的收益分布。
%     (2) 风险测度取**熵风险 (Entropic Risk = KL 罚函数)**: 论文 Table 1 / Example 1
%         的规范实例, 也是其实验 (§4.3 "KL penalty with log-barrier") 所用。其凸罚
%         D(p,q)=(1/τ)KL(p,q) 联合凸且连续, 满足可计算性定理 (Theorem 3) 前提 ——
%         CVaR 的指示罚不连续, 不满足该前提, 故此处不用 CVaR。
%         对任意本方混合策略 x 和对手分布 q, Example 1 的代价为
%           f(x,q) = sup_p[-x'Mp-(1/τ)KL(p,q)]
%                  = (1/τ)log Σ_k q_k exp[-τ(M'x)_k]。
%         τ→0 退化为期望收益 (风险中性), τ→∞ 趋于对手支撑上的最坏收益 (风险规避)。
%     (3) 有限理性 (bounded rationality, Def 4-5): 负熵正则 ν_i(π)=Σπlogπ 诱导
%         正则化最优响应。本码取 ε=params.lambda。必须直接求解
%           BR(q)=argmin_{x∈Δ}{f(x,q)+εΣ_a x_a log x_a}；
%         因 f 对 x 非线性，不能把各纯动作 f(e_a,q) softmax 后冒充该最优响应。
%     (4) 计算: 每轮用带解析梯度的凸优化求 BR(q)，再执行阻尼固定点迭代
%         q←(1-β)q+β·BR(q)。报告未阻尼固定点残差 ||BR(q)-q||_1。
%
%   与 Proposed 的差距 (诚实标注): RQE 风险来自对手分布 (非 IT2 FOU δ), 无
%   family-uniform 收敛证书、无 α-cut 鲁棒预算 (引理1)、无治理耦合 θ=P_pay·ω。
%   信息源为博弈收益结构, 不偷看环境冲击, 与 Proposed 信息对称。
%
%   输入:
%     params - 参数结构体 (需含 N, num_strategies, lambda, beta, R_max, eps_tol;
%              可选 rqe_tau 熵风险厌恶强度 τ, 默认 5.0)
%     delta  - 统一签名占位 (RQE 经 δ=0 归约矩阵决策, 风险由 τ 控制, 不使用 delta)
%     theta  - 收益层权重
%     alpha  - 统一签名占位 (不使用; 风险水平由 τ 控制)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面 (各 agent 同分布 q)
%     history - 残差/收敛轮数/收敛标志 (口径同 Proposed, 供 CI/收敛图复用)

    if isfield(params, 'rqe_tau'); tau = params.rqe_tau; else; tau = 5.0; end
    ns = params.num_strategies;
    N = params.N;
    M = sota_reduced_matrix(theta, params);     % M(a,k)=代表 agent 取 a、种群取纯 k 的晶化收益
    q = ones(ns, 1) / ns;
    x_warm = q;

    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.inner_exitflag = zeros(params.R_max, 1);
    history.converged = false;
    history.iterations = params.R_max;
    for r = 1:params.R_max
        [br, risk_utility, exitflag] = regularized_rqe_best_response( ...
            q, x_warm, M, tau, params.lambda);
        fixed_point_residual = sum(abs(br - q));
        q_new = (1 - params.beta) * q + params.beta * br;
        history.residual(r) = fixed_point_residual;
        history.avg_payoff(r) = risk_utility;
        history.inner_exitflag(r) = exitflag;
        q = q_new;
        x_warm = br;
        if fixed_point_residual <= params.eps_tol
            history.residual = history.residual(1:r);
            history.avg_payoff = history.avg_payoff(1:r);
            history.inner_exitflag = history.inner_exitflag(1:r);
            history.converged = true;
            history.iterations = r;
            break;
        end
    end
    if ~history.converged
        history.inner_exitflag = history.inner_exitflag(1:params.R_max);
    end
    history.final_native_residual = history.residual(end);
    pi_star = repmat(q', N, 1);
end

function [x, risk_utility, exitflag] = regularized_rqe_best_response( ...
    q, x0, M, tau, epsilon)
%REGULARIZED_RQE_BEST_RESPONSE Solve Definition 5 on the full simplex.
% The floor only protects log(x); it is far below the reported tolerance.
    ns = numel(q);
    floor_x = 1e-12;
    x0 = max(x0(:), floor_x);
    x0 = x0 / sum(x0);
    Aeq = ones(1, ns);
    beq = 1;
    objective = @(candidate) rqe_objective(candidate, q, M, tau, epsilon);
    % fmincon_simplex_compat: 有 Optimization Toolbox 时用与原实现逐字相同的
    % fmincon interior-point 配置; 否则回落熵镜像下降 (同一凸问题, 同容差)。
    [x, ~, exitflag, output] = fmincon_simplex_compat( ...
        objective, x0, floor_x);
    if exitflag <= 0 && (~isfield(output, 'firstorderopt') || ...
            output.firstorderopt > 1e-7)
        error('solve_rqe: inner convex best response failed (exitflag=%d).', ...
            exitflag);
    end
    x = max(x, floor_x);
    x = x / sum(x);
    objective_value = rqe_objective(x, q, M, tau, epsilon);
    entropy = sum(x .* log(x));
    risk_utility = -(objective_value - epsilon * entropy);
end

function [value, gradient] = rqe_objective(x, q, M, tau, epsilon)
%RQE_OBJECTIVE f(x,q)+epsilon*negative_entropy and its exact gradient.
    realized_payoff = M' * x;
    if abs(tau) < 1e-10
        value_risk = -q' * realized_payoff;
        adversary = q;
    else
        z = -tau * realized_payoff;
        z_max = max(z);
        weighted = q .* exp(z - z_max);
        normalizer = sum(weighted);
        value_risk = (z_max + log(normalizer)) / tau;
        adversary = weighted / normalizer;
    end
    value = value_risk + epsilon * sum(x .* log(x));
    if nargout > 1
        gradient = -M * adversary + epsilon * (log(x) + 1);
    end
end
