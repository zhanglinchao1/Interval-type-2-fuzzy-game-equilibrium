function [pi_star, history] = sec4_3_2_coherent_solve( ...
    params, delta, theta, alpha, focus_s)
%SEC4_3_2_COHERENT_SOLVE Coherent-tail extension F(alpha,s,w) of Gamma_{alpha,s}.
%
%   决策目标 (混合策略层面的相干悲观标量化):
%       J_i(p) = (1-w) * <p, nu^{alpha,s}(q)> + w * CVaR_a( <p, U^k(q)> ),
%   其中 U^k = Uhat + s_k*rho (s_k in linspace(-1,1,K)) 是论文既有的 K-样本
%   区间离散化 (与 CVaR-game / DRNE-VI adapter 完全同源的 delta 信息, 无信息
%   优势); nu^{alpha,s} 为 Gamma_{alpha,s} 的逐动作悲观收益。
%
%   w=0 退化为逐动作标量族 Gamma_{alpha,s} (线性目标, 顶点最优响应);
%   w=1 且 alpha=1,s=0 时包含 CVaR-game 的相干效用为特例。
%   混合最优响应对固定对手是 LP (CVaR 对有限仿射样本分段仿射凹), 采用与全部
%   基线共享的阻尼固定点迭代 (params.beta) 与停止阈值 (params.eps_tol)。
%
%   归约口径与 solve_cvar_game 一致: 对称 mean-field 代表玩家, 公共实例由
%   build_reduced_interval_game 生成 (single source of truth)。
%
%   输入:
%       params  - 参数结构体; 可选字段:
%                 tail_w   in [0,1]  相干尾部权重 (默认 0.8)
%                 tail_acv in (0,1]  CVaR 尾部概率 (默认 0.2)
%                 tail_K             样本数 (默认 64)
%       delta   - FOU 半带宽
%       theta   - 3x1 收益层权重
%       alpha   - [0,1] 悲观参数 (作用于 nu^{alpha,s} 项)
%       focus_s - 聚焦指数 (作用于 nu^{alpha,s} 项), 默认 0
%   输出:
%       pi_star - N x num_strategies 收敛策略剖面 (对称)
%       history - residual / avg_payoff / converged / iterations / eps_ne
%
%   事后证书: history.eps_ne 为 F(alpha,s,w) 目标下的 exploitability
%   (精确 LP 最优响应值 - 现值), 可代入 Lemma 1 型预算转换。

    if nargin < 4 || isempty(alpha); alpha = 1; end
    if nargin < 5 || isempty(focus_s); focus_s = 0; end
    if isfield(params, 'tail_w');   w = params.tail_w;     else; w = 0.8; end
    if isfield(params, 'tail_acv'); a_cv = params.tail_acv; else; a_cv = 0.2; end
    if isfield(params, 'tail_K');   K = params.tail_K;      else; K = 64;  end
    if w < 0 || w > 1
        error('sec4_3_2_coherent_solve:badW', 'tail_w must lie in [0,1].');
    end

    ns = params.num_strategies;
    N = params.N;

    G = build_reduced_interval_game(params, delta);
    if K == 1; svec = 0; else; svec = linspace(-1, 1, K); end

    q = ones(ns, 1) / ns;
    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.converged = false;
    history.iterations = params.R_max;

    for r = 1:params.R_max
        [br, best_val, cur_val] = coherent_mixed_best_response( ...
            q, G, svec, alpha, focus_s, w, a_cv);
        residual = sum(abs(br - q));
        q = (1 - params.beta) * q + params.beta * br;
        history.residual(r) = residual;
        history.avg_payoff(r) = best_val;
        if residual <= params.eps_tol
            history.residual = history.residual(1:r);
            history.avg_payoff = history.avg_payoff(1:r);
            history.converged = true;
            history.iterations = r;
            break;
        end
    end

    % 事后 exploitability 证书 (F 目标下)
    [~, best_val, cur_val] = coherent_mixed_best_response( ...
        q, G, svec, alpha, focus_s, w, a_cv);
    history.eps_ne = best_val - cur_val;
    history.tail_w = w;
    history.tail_acv = a_cv;
    history.alpha = alpha;
    history.focus_s = focus_s;
    history.final_native_residual = history.residual(end);

    pi_star = repmat(q', N, 1);
end

function [x, best_val, cur_val] = coherent_mixed_best_response( ...
    q, G, svec, alpha, focus_s, w, a_cv)
%COHERENT_MIXED_BEST_RESPONSE Exact LP best response for F(alpha,s,w).
%   Variables [x; z; xi] with xi_k >= z - u_k(x), u_k(x) = x'*V(:,k),
%   objective max (1-w)*x'*nu + w*(z - (1/(a_cv*K))*sum_k xi_k).

    K = numel(svec);
    ns = numel(q);

    % Gamma_{alpha,s} per-action pessimistic payoff at population q
    center = G.U_hat * q;                       % ns x 1
    radius = G.rho * q;                         % ns x 1
    budget = (1 - alpha) * radius;
    if focus_s == 0
        penalty = budget;
    else
        rho_floor = 0.01;
        rho_peak = max(max(radius), rho_floor);
        penalty = budget .* (radius ./ rho_peak).^focus_s;
    end
    nu = center - penalty;                      % ns x 1

    % Interval sample payoffs (same discretization as CVaR-game/DRNE adapters)
    V = center + radius * svec;                 % ns x K, V(:,k)=Uhat+s_k*rho @ q

    if w == 0
        [best_val, j] = max(nu);
        x = zeros(ns, 1); x(j) = 1;
        cur_val = q' * nu;
        return;
    end

    num_variables = ns + 1 + K;
    objective = zeros(num_variables, 1);
    objective(1:ns) = -(1 - w) * nu;
    objective(ns + 1) = -w;
    objective((ns + 2):end) = w / (a_cv * K);

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
    [solution, fval, exitflag] = lp_linprog_compat( ...
        objective, A, b, Aeq, beq, lb, ub);
    if exitflag <= 0
        error('sec4_3_2_coherent_solve:lpFailed', ...
            'mixed-strategy coherent LP failed (exitflag=%d).', exitflag);
    end
    x = max(solution(1:ns), 0);
    x = x / sum(x);
    best_val = -fval;
    cur_val = coherent_value(q, nu, V, w, a_cv);
end

function val = coherent_value(p, nu, V, w, a_cv)
%COHERENT_VALUE Evaluate F objective at mixed strategy p (closed form CVaR).
    u = (p' * V)';                              % K x 1 sample payoffs
    K = numel(u);
    u_sorted = sort(u, 'ascend');
    m = a_cv * K;
    n_full = floor(m);
    cvar_sum = sum(u_sorted(1:n_full));
    if n_full < K && m > n_full
        cvar_sum = cvar_sum + (m - n_full) * u_sorted(n_full + 1);
    end
    cvar = cvar_sum / m;
    val = (1 - w) * (p' * nu) + w * cvar;
end
