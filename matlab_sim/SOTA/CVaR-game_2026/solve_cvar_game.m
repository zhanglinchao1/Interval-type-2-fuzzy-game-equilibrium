function [pi_star, history] = solve_cvar_game(params, delta, theta, alpha)
%SOLVE_CVAR_GAME  Distributionally Robust Game via Coherent (CVaR) Risk Measure (鲁棒赛道 SOTA)。
%
%   参考: Gangwani & Sinha 2026, "Distributionally Robust Games via Coherent
%         Risk Measures" (arXiv:2605.19302)。
%
%   忠实复现要点 (严格对照原文, 作为对手论文独立实现, 不受本文设定影响):
%     (1) 数据驱动博弈 (DRG, 论文 §2): 玩家面对来自 K 个样本的收益分布不确定性,
%         经验分布 P 为名义。风险经**相干效用测度 (coherent utility measure)** 刻画。
%     (2) 玩家最大化**相干 CVaR 效用** (论文 Example 1 / eq 17):
%           ρ_CVaR(u) = (1-γ_c)·E_P[u] + γ_c·CVaR_α(u),
%         CVaR_α(X)=max_z[z+(1/α)E_P·min(0,X-z)] 为收益**下尾** CVaR (α=尾部概率,
%         小α=更极端尾部); γ_c∈[0,1]=风险厌恶强度。利用 CVaR 的标准辅助变量表示，
%         对固定对手策略，混合策略的 coherent utility 可写成线性规划，
%         无需对模糊集做内层梯度迭代。
%     (3) DRE = 该风险调整博弈的 Nash 均衡 (论文 Def DRE / §4.2 MLCP): **完全理性,
%         无有限理性/softmax** (区别于 RQE/MF-RQE)。论文经多线性互补 (MLCP) 或"等化
%         对手动作价值"求解, 常得**混合**均衡 (Fig 4 内部 y*∈(0,0.5))。本归约每轮
%         用精确 LP 求完整混合策略最优响应，再做阻尼固定点迭代；不能先对每个纯动作
%         分别计算 CVaR 后取 argmax，因为 CVaR 对混合策略一般不是线性的。
%
%   归约映射 (单状态对称 mean-field, H=1; 公平且忠实):
%     与 MF-RQE/DRNE 同源, 从 δ 区间取 K 个收益样本 M^k=Û+s_k·ρ (s_k∈linspace(-1,1,K),
%     经验分布均匀), 用与 Proposed/DRNE 同源 δ 信息 (信息对称, 不偷看冲击)。代表 agent
%     纯策略 a 对种群 q 的随机收益样本 U^k(a)=M^k(a,·)q; 相干 CVaR 效用 ν_a 闭式给出。
%
%   与 Proposed 的差距 (诚实标注): CVaR-game 无 family-uniform 收敛证书、无 α-cut 鲁棒
%   预算 (引理1)、无治理耦合; 完全理性 (无有限理性); 一般 PPAD-complete (论文 Thm 8)。
%
%   输入:
%     params - 参数结构体 (需含 N, num_strategies, beta, R_max, eps_tol;
%              trust/delay/res_matrix, theta; 可选 cvar_gamma 风险强度 γ_c 默认 1.0,
%              cvar_alpha 尾部置信 α 默认 0.2, cvar_K 样本数默认 64)
%     delta  - FOU 半带宽 (界定收益样本区间; 鲁棒赛道取真实 δ, 如 0.20)
%     theta  - 收益层权重
%     alpha  - 统一签名占位 (不使用; 风险水平由 cvar_alpha/cvar_gamma 控制)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面 (对称 DRE 遍历平均, 各 agent 同分布)
%     history - 残差(策略变化)/收敛轮数/收敛标志

    if isfield(params, 'cvar_gamma'); gam_c = params.cvar_gamma; else; gam_c = 1.0; end
    if isfield(params, 'cvar_alpha'); a_cv = params.cvar_alpha;  else; a_cv = 0.2; end
    if isfield(params, 'cvar_K');     K = params.cvar_K;         else; K = 64;  end
    ns = params.num_strategies;
    N = params.N;

    % --- K 个收益样本 M^k = Û + s_k·ρ (与 MF-RQE/DRNE 同源 δ 离散化, 经验分布均匀) ---
    G = build_reduced_interval_game(params, delta);
    if K == 1; svec = 0; else; svec = linspace(-1, 1, K); end
    Ms = cell(K, 1);
    for k = 1:K; Ms{k} = G.U_hat + svec(k) * G.rho; end
    q = ones(ns, 1) / ns;
    sum_q = zeros(ns, 1); cnt = 0;               % 遍历平均累加 (处理混合 DRE 的 BR 振荡)
    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.converged = false;
    history.iterations = params.R_max;
    for r = 1:params.R_max
        % 对固定种群 q，在完整策略单纯形上精确求 mean-CVaR 混合最优响应。
        [br, best_utility] = cvar_mixed_best_response( ...
            q, Ms, gam_c, a_cv);
        fixed_point_residual = sum(abs(br - q));
        q_new = (1 - params.beta) * q + params.beta * br;
        q = q_new;
        sum_q = sum_q + q; cnt = cnt + 1;
        history.residual(r) = fixed_point_residual;
        history.avg_payoff(r) = best_utility;
        if fixed_point_residual <= params.eps_tol
            history.residual = history.residual(1:r);
            history.avg_payoff = history.avg_payoff(1:r);
            history.converged = true;
            history.iterations = r;
            break;
        end
    end
    % 收敛(纯 DRE 不动点)→报末迭代(=均衡顶点/不动点); 未收敛(混合 DRE 下 BR 振荡)→
    % 报遍历平均(逼近混合均衡)。避免对纯顶点均衡用遍历平均引入瞬态污染。
    if history.converged
        q_out = q;
    else
        q_out = sum_q / cnt;
    end
    history.final_native_residual = history.residual(end);
    pi_star = repmat(q_out', N, 1);
end

function [x, best_utility] = cvar_mixed_best_response(q, Ms, gamma_c, alpha_cvar)
%CVAR_MIXED_BEST_RESPONSE Exact lower-tail mean-CVaR best response by LP.
% Variables are [x; z; xi], with xi_k >= z-u_k(x) and
% CVaR_alpha(u)=max_z z-(1/(alpha*K))*sum_k xi_k.
    K = numel(Ms);
    ns = numel(q);
    if alpha_cvar <= 0 || alpha_cvar > 1
        error('solve_cvar_game: cvar_alpha must lie in (0,1].');
    end
    if gamma_c < 0 || gamma_c > 1
        error('solve_cvar_game: cvar_gamma must lie in [0,1].');
    end

    V = zeros(ns, K);
    for k = 1:K
        V(:, k) = Ms{k} * q;
    end
    mean_value = mean(V, 2);
    num_variables = ns + 1 + K;
    objective = zeros(num_variables, 1);
    objective(1:ns) = -(1 - gamma_c) * mean_value;
    objective(ns + 1) = -gamma_c;
    objective((ns + 2):end) = gamma_c / (alpha_cvar * K);

    A = zeros(K, num_variables);
    b = zeros(K, 1);
    for k = 1:K
        A(k, 1:ns) = -V(:, k)';
        A(k, ns + 1) = 1;
        A(k, ns + 1 + k) = -1;
    end
    Aeq = zeros(1, num_variables);
    Aeq(1:ns) = 1;
    beq = 1;
    lb = [zeros(ns, 1); -Inf; zeros(K, 1)];
    ub = [ones(ns, 1); Inf; Inf(K, 1)];
    % lp_linprog_compat: 有 Optimization Toolbox 时用原生 linprog (同容差),
    % 否则回落 scipy HiGHS; 两路径最优值一致 (见 utils/lp_linprog_compat.m)。
    [solution, fval, exitflag] = lp_linprog_compat( ...
        objective, A, b, Aeq, beq, lb, ub);
    if exitflag <= 0
        error('solve_cvar_game: mixed-strategy CVaR LP failed (exitflag=%d).', ...
            exitflag);
    end
    x = max(solution(1:ns), 0);
    x = x / sum(x);
    best_utility = -fval;
end
