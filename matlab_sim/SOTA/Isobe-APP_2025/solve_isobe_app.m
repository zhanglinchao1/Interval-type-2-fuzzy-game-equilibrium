function [pi_star, history] = solve_isobe_app(params, delta, theta, alpha)
%SOLVE_ISOBE_APP  Last-iterate-convergent 正则化 mean-field 学习 (收敛 SOTA / W-FBRI 孪生)。
%
%   参考: Isobe, Abe & Ariu 2025, "Last Iterate Convergence in Monotone Mean
%         Field Games" (arXiv:2410.05127, NeurIPS 2025); 其内层 RMD 即
%         Abe, Ariu, Sakamoto & Iwasaki 2024 "Adaptively Perturbed Mirror
%         Descent" (ICML 2024) 的 mean-field 版。
%
%   角色 (收敛赛道 / 支柱 I 对照):
%     本文 mean-field 设定的**最近邻**——近端点 (PP) 外循环 + 正则化镜像下降 (RMD)
%     内循环, 在单调 MFG 上有 last-iterate 收敛保证 (Theorem 3.1/4.3) 与 O(log(1/ε))
%     速率。它与本文 W-FBRI 同属"熵/KL 正则软响应 + 收敛到混合/认证均衡"家族, 故是
%     W-FBRI 的孪生对照: 同样收敛、同样软响应, 但 (a) 其收敛保证依赖步长 η≤η* 与
%     单调性前提 (非本文 family-uniform 解析证书), (b) FOU-agnostic、不做 α-cut 鲁棒
%     决策、无治理耦合 θ=P_pay·ω。本文令其 δ=0、α=1, 诚实呈现"现代 mean-field
%     last-iterate 方法也收敛, 但缺统一证书 + 鲁棒均衡类型 + 治理"。
%
%   算法 (论文 Algorithm 2, 双层结构):
%     外层 PP (k):  σ^{k+1} = RMD(MFG, σ^k, λ, η, σ^k, τ),  μ^{k+1} = m[σ^{k+1}]
%     内层 RMD (t): 自锚点热启 π^0 ← σ^k, 固定锚点 σ=σ^k, 迭代 τ 步, 闭式更新 (line 11)
%       π^{t+1}(a|s) ∝ σ(a|s)^{λη} · π^t(a|s)^{1-λη} · exp( η Q^{λ,σ}(s,a,π^t,μ^t) )。
%     **外层 PP 把锚点反复自适应扰动 σ←π 是 last-iterate 收敛、收敛到正确顶点均衡的
%     关键**: 单纯 RMD (锚点不更新) 会偏到单纯形内部 (论文 §5 实测), 外层 PP 驱动
%     σ^k → Π*。收敛判据取外层 last-iterate 残差 ‖σ^{k+1}-σ^k‖ ≤ eps_tol (定理 3.1
%     即此量趋零)。输出 σ^k (last iterate, 非时间平均)。
%
%   归约映射 (单状态对称 mean-field, H=1):
%     - 平凡单状态 + 单步, 故种群 μ^t = m[π^t] = π^t (对称一次性人口博弈);
%     - 动作价值 Q^{λ,σ}(a) = r(a, μ^t) = 纯策略 a 对当前种群的晶化收益,
%       即 sota_grad_vector(·, δ, θ, α) (δ=0,α=1 时为名义 Û, FOU-agnostic);
%     - 锚点正则 -λ D_KL(π,σ) 仅经几何均值先验项进更新 (末步 V_{H+1}=0, 不进 Q)。
%     残差流记录每个内层步 (与 OGDA/OMWU 同定义 e_π=max_i‖Δπ_i‖_1), R=总内层步数,
%     仅作"与现代 SOTA 同量级"佐证 (R 不加粗, 见 plan §4.3)。
%
%   输入:
%     params - 参数结构体 (N, num_strategies, R_max, eps_tol, rng_seed;
%              可选 isobe_eta 学习率 η, isobe_lambda 锚点强度 λ (需 λη<1),
%              isobe_T 内层 RMD 步数 τ)
%     delta  - 决策侧 FOU 半带宽 (收敛赛道取 0)
%     theta  - 收益层权重
%     alpha  - α-cut 置信水平 (收敛赛道取 1)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面 (σ^k, last-iterate)
%     history - 残差/收敛轮数/收敛标志 (口径同 Proposed, 供 CI/收敛图复用)

    if isfield(params, 'isobe_eta');    eta = params.isobe_eta;    else; eta = 8.0; end
    if isfield(params, 'isobe_lambda'); lambda = params.isobe_lambda; else; lambda = 0.05; end
    if isfield(params, 'isobe_T');      tau = params.isobe_T;      else; tau = 3; end

    w_anchor = lambda * eta;            % 几何均值中锚点 σ 的权重 (论文 λη, 需 <1)
    if w_anchor >= 1
        error(['solve_isobe_app: lambda*eta = %.3f >= 1, 违反 RMD 闭式更新前提 ', ...
            '(1-λη>0); 请减小 isobe_eta 或 isobe_lambda。'], w_anchor);
    end

    [pi_init, history] = sota_init(params);
    sigma = pi_init;                   % σ^0 = π^0 (满支撑, 论文 Assumption 4.1)
    log_floor = 1e-300;                % 防 log(0): 乘性更新理论恒正, 仅护浮点下溢
    r = 0;                             % 全局内层步计数 (= 报告的 R)
    converged = false;

    for k = 1:params.R_max             % 外层 PP 循环 (上界亦取 R_max)
        pi_profile = sigma;            % 内层热启于锚点 (Algorithm 2: π^0 ← σ^k)
        for t = 1:tau                  % 内层 RMD: 固定锚点 σ, 迭代 τ 步
            r = r + 1;
            g = sota_grad_vector(pi_profile, delta, theta, alpha, params);
            log_pi = w_anchor * log(max(sigma, log_floor)) ...
                + (1 - w_anchor) * log(max(pi_profile, log_floor)) + eta * g;
            log_pi = log_pi - max(log_pi, [], 2);
            pi_new = exp(log_pi);
            pi_new = pi_new ./ sum(pi_new, 2);

            history.residual(r) = max(sum(abs(pi_new - pi_profile), 2));
            [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
                pi_new, delta, theta, params);
            history.avg_payoff(r) = mean(U_hat);
            history.strategy_dist(r, :) = mean(pi_new, 1);

            pi_profile = pi_new;
            if r >= params.R_max; break; end
        end

        outer_res = max(sum(abs(pi_profile - sigma), 2));   % 外层 last-iterate 残差
        sigma = pi_profile;                                  % σ^{k+1} = RMD 结果
        if outer_res <= params.eps_tol
            converged = true;
            break;
        end
        if r >= params.R_max; break; end
    end

    history.residual = history.residual(1:r);
    history.avg_payoff = history.avg_payoff(1:r);
    history.strategy_dist = history.strategy_dist(1:r, :);
    history.converged = converged;
    history.iterations = r;
    history.final_native_residual = outer_res;
    pi_star = sigma;
end
