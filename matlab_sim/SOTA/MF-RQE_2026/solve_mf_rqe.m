function [pi_star, history] = solve_mf_rqe(params, delta, theta, alpha)
%SOLVE_MF_RQE  Mean-Field Risk-Averse Quantal Response Equilibrium (鲁棒赛道 SOTA)。
%
%   参考: Jeloka, Guan & Tsiotras 2026, "Robust Mean-Field Games with Risk
%         Aversion and Bounded Rationality" (arXiv:2602.13353)。
%
%   忠实复现要点 (严格对照原文, 作为对手论文独立实现, 不受本文设定影响):
%     (1) 风险针对**初始种群分布的不确定性** (论文 §4.2): 存在有限初始分布集合
%         𝕄={μ₀¹,…,μ₀^|𝕄|}, 先验 Γ*∈P(𝕄), 每个初始分布诱导不同 mean-field 流 μ^k;
%         策略为 open-loop (不见实时 MF), 须对"哪个分布/流实现"对冲。**这与 RQE
%         (对手随机性) 与本文 IT2-FOU (区间隶属) 是不同的风险来源** —— 忠实保留。
%     (2) 风险测度取**熵风险 (KL 罚)** (论文 §4.2 末, 实验所用): 对偶表示闭式 (eq 6-7)
%           c_t^π(x) = ρ_{Γ*}(V_{μ,t}^π(x)) = (1/τ) log Σ_k Γ*(k) exp(-τ π_t^T Q_{μ^k,t}^π(x,·)),
%         即对 |𝕄| 个场景的策略价值 V^k=π^TQ^k 做 log-sum-exp 聚合。τ→0 退化为对 𝕄
%         取期望 (风险中性), τ→∞ 趋于 𝕄 上最坏场景 (最坏情形鲁棒)。
%     (3) 有限理性 (论文 §4.3, eq 8): 一般凸正则 ν(π) + 温度 α; 实验用熵正则 → softmax
%         quantal response。本码取 ν=负熵、α=params.lambda (与 RQE/Proposed 同级对齐)。
%     (4) 计算 (论文 §6 Fixed-Point Iteration + Theorem 3): 定点迭代 ——
%         给定策略传播得各场景流 → B_opt 解完整混合策略的风险厌恶正则化凸问题
%         → mean-field 一致 → 迭代。不能只在当前策略处计算风险倾斜权重后做一步
%         softmax，并把该步冒充 B_opt。
%
%   归约映射 (单状态对称 mean-field, H=1; 公平且忠实):
%     MF-RQE 需"有限初始分布/环境场景集合"作输入。本代码库环境不确定性由 δ 参数化
%     (所有鲁棒方法共享、不偷看冲击)。故把 δ 区间离散为 K 个环境场景:
%         M^s = Û + β_s·ρ,  β_s ∈ linspace(-1,1,K)  (即 {U_lo, U_hat, U_hi} 当 K=3),
%     由 build_reduced_interval_game(params,δ) 的 IT2 端点给出 (U_lo=Û-ρ, U_hi=Û+ρ)。
%     场景 s 下纯策略 a 对种群 q 的价值 Q^s(a)=M^s(a,·)q; 策略价值 V^s=q^T M^s q。
%     这是"跨初始分布诱导流对冲"在 T=1 下的忠实一次性化, 用与 Proposed/CVaR-game
%     同源的 δ 信息 (信息对称, plan §6)。
%
%   与 Proposed 的差距 (诚实标注): MF-RQE 无 family-uniform 收敛证书、无 α-cut 鲁棒
%   预算 (引理1)、无治理耦合 θ=P_pay·ω; 风险来自初始分布集合而非 IT2-FOU 区间。
%
%   输入:
%     params - 参数结构体 (需含 N, num_strategies, lambda, beta, R_max, eps_tol,
%              trust/delay/res_matrix, theta; 可选 mfrqe_tau 熵风险强度 τ 默认 5.0,
%              mfrqe_K 场景数默认 3, mfrqe_gamma 场景先验 Γ* 默认均匀)
%     delta  - FOU 半带宽 (界定环境场景集合的离散区间; 鲁棒赛道取真实 δ, 如 0.20)
%     theta  - 收益层权重
%     alpha  - 统一签名占位 (不使用; 风险水平由 τ 控制, 有限理性由 lambda 控制)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面 (各 agent 同分布 q)
%     history - 残差/收敛轮数/收敛标志 (口径同 Proposed, 供 CI/收敛图复用)

    if isfield(params, 'mfrqe_tau'); tau = params.mfrqe_tau; else; tau = 5.0; end
    if isfield(params, 'mfrqe_K');   K = params.mfrqe_K;     else; K = 3;   end
    ns = params.num_strategies;
    N = params.N;

    % --- 构造 K 个环境场景的归约收益矩阵 M^s = Û + β_s·ρ (𝕄 离散化, 见注) ---
    G = build_reduced_interval_game(params, delta);
    if K == 1
        betas = 0;
    else
        betas = linspace(-1, 1, K);
    end
    Ms = cell(K, 1);
    for s = 1:K
        Ms{s} = G.U_hat + betas(s) * G.rho;       % U_lo/U_hat/U_hi 为 β=-1/0/1 特例
    end

    % --- 场景先验 Γ* (默认均匀, 中性) ---
    if isfield(params, 'mfrqe_gamma') && ~isempty(params.mfrqe_gamma)
        gam = params.mfrqe_gamma(:);
        gam = gam / sum(gam);
    else
        gam = ones(K, 1) / K;
    end
    alpha_br = params.lambda;                      % 有限理性温度 α (= bounded rationality)

    q = ones(ns, 1) / ns;
    x_warm = q;
    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.inner_exitflag = zeros(params.R_max, 1);
    history.converged = false;
    history.iterations = params.R_max;
    for r = 1:params.R_max
        [br, risk_utility, exitflag] = regularized_mfrqe_best_response( ...
            q, x_warm, Ms, gam, tau, alpha_br);
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

function [x, risk_utility, exitflag] = regularized_mfrqe_best_response( ...
    q, x0, Ms, scenario_prior, tau, epsilon)
%REGULARIZED_MFRQE_BEST_RESPONSE Exact B_opt for the one-stage reduction.
    ns = numel(q);
    K = numel(Ms);
    Q = zeros(ns, K);
    for k = 1:K
        Q(:, k) = Ms{k} * q;
    end
    floor_x = 1e-12;
    x0 = max(x0(:), floor_x);
    x0 = x0 / sum(x0);
    objective = @(candidate) mfrqe_objective( ...
        candidate, Q, scenario_prior, tau, epsilon);
    % fmincon_simplex_compat: 有 Optimization Toolbox 时用与原实现逐字相同的
    % fmincon interior-point 配置; 否则回落熵镜像下降 (同一凸问题, 同容差)。
    [x, ~, exitflag, output] = fmincon_simplex_compat( ...
        objective, x0, floor_x);
    if exitflag <= 0 && (~isfield(output, 'firstorderopt') || ...
            output.firstorderopt > 1e-7)
        error('solve_mf_rqe: inner convex best response failed (exitflag=%d).', ...
            exitflag);
    end
    x = max(x, floor_x);
    x = x / sum(x);
    objective_value = mfrqe_objective( ...
        x, Q, scenario_prior, tau, epsilon);
    entropy = sum(x .* log(x));
    risk_utility = -(objective_value - epsilon * entropy);
end

function [value, gradient] = mfrqe_objective( ...
    x, Q, scenario_prior, tau, epsilon)
%MFRQE_OBJECTIVE Entropic scenario risk plus negative-entropy regularizer.
    scenario_value = Q' * x;
    if abs(tau) < 1e-10
        value_risk = -scenario_prior' * scenario_value;
        tilted = scenario_prior;
    else
        z = -tau * scenario_value;
        z_max = max(z);
        weighted = scenario_prior .* exp(z - z_max);
        normalizer = sum(weighted);
        value_risk = (z_max + log(normalizer)) / tau;
        tilted = weighted / normalizer;
    end
    value = value_risk + epsilon * sum(x .* log(x));
    if nargout > 1
        gradient = -Q * tilted + epsilon * (log(x) + 1);
    end
end
