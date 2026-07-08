function [pi_star, history] = solve_drne_vi(params, delta, theta, alpha)
%SOLVE_DRNE_VI  Distributionally Robust Nash Equilibrium via Variational Inequality (鲁棒赛道 SOTA)。
%
%   参考: Alizadeh, Farsi & Jalilzadeh 2025, "Distributionally Robust Nash
%         Equilibria via Variational Inequalities" (arXiv:2510.17024)。
%
%   忠实复现要点 (严格对照原文, 作为对手论文独立实现, 不受本文设定影响):
%     (1) DRNE 问题 (论文 §1): 每个玩家对**模糊集 P 内最坏分布**最小化代价
%           min_{x∈K} max_{p∈P} Σ_j p_j f(x, x_{-i}, ξ_j),
%         ξ_j 为采样场景, f 为凸 (可非光滑) 代价, P 为分布的模糊集 (ambiguity set)。
%     (2) VI 重构 + GDA 算法 (论文 §2/§4 Algorithm 1): 投影梯度**下降-上升**——
%           x ← P_K( x - λ_t · Σ_j p_j ∂_x f_j ),   p ← P_P( p - γ_t · [-f_j] ),
%         步长 λ_t=γ_t=c/√t (论文实验 0.01/√t), **遍历平均** x̄=Σλ_t x^t/Σλ_t (Thm 5 保证)。
%         复杂度 O(1/ε²·log²(1/ε)); 收敛到 DRNE 解 (Thm 7 almost-sure)。
%     (3) 模糊集取 **CVaR 风险包络** (论文 §5 实验 RaNE-CVaR): P_α={p∈Δ_m: 0≤p_j≤1/(m(1-α))},
%         此时 max_{p∈P_α}Σ p_j f_j = CVaR_α(f)。α→0 退化为期望 (p 被迫均匀, 风险中性),
%         α→1 趋于最坏场景 (worst-case)。投影用 capped-simplex 二分 (见 local 函数)。
%
%   归约映射 (单状态对称 mean-field, H=1; 公平且忠实):
%     与 MF-RQE 同源, 从 δ 区间离散出 m 个环境场景 M^j=Û+β_j·ρ (β_j∈linspace(-1,1,m)),
%     用与 Proposed/CVaR-game 同源 δ 信息 (信息对称, 不偷看冲击)。代表 agent 代价
%     f_j(π,q)=-π^T M^j q (负收益, 玩家最小化代价); 对称 mean-field 取种群 q=π (当前迭代)。
%     报告遍历平均 π̄ (论文 Thm 5 保证收敛的对象)。
%
%   与 Proposed 的差距 (诚实标注): DRNE-VI 为 O(1/ε²) 遍历 GDA, **无 family-uniform
%   收敛证书** (鞍点 GDA 单点振荡, 仅遍历平均收敛, 慢)、无 α-cut 鲁棒预算 (引理1)、
%   无治理耦合; 风险来自分布模糊集 (CVaR) 而非 IT2-FOU 区间。
%
%   输入:
%     params - 参数结构体 (需含 N, num_strategies, R_max, eps_tol;
%              trust/delay/res_matrix, theta; 可选 drne_m 场景数默认 11,
%              drne_alpha CVaR 置信默认 0.8, drne_eta 步长系数 c 默认 2.0)
%     delta  - FOU 半带宽 (界定环境场景集合; 鲁棒赛道取真实 δ, 如 0.20)
%     theta  - 收益层权重
%     alpha  - 统一签名占位 (不使用; 风险水平由 drne_alpha 控制)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面 (遍历平均 π̄, 各 agent 同分布)
%     history - 残差(可利用性 gap)/收敛轮数/收敛标志
%
%   说明: 残差口径为最坏分布下 π̄ 的可利用性 gap = max_a(M̄π̄)_a - π̄'M̄π̄ (M̄=Σp̄_j M^j),
%   即 DRNE 解的质量度量 (→0 即 DRNE); 与梯度法 ||Δπ|| 口径不同, 因 GDA 遍历平均
%   的逐步变化由递减步长主导, 不反映真实收敛 (此即 DRNE 无快速收敛证书的体现)。

    if isfield(params, 'drne_m');     m = params.drne_m;          else; m = 11;  end
    if isfield(params, 'drne_alpha'); a_dr = params.drne_alpha;   else; a_dr = 0.8; end
    if isfield(params, 'drne_eta');   c = params.drne_eta;        else; c = 2.0; end
    ns = params.num_strategies;
    N = params.N;

    % --- m 个环境场景 M^j = Û + β_j·ρ (与 MF-RQE 同源 δ 离散化) ---
    G = build_reduced_interval_game(params, delta);
    if m == 1; betas = 0; else; betas = linspace(-1, 1, m); end
    Ms = cell(m, 1);
    for j = 1:m; Ms{j} = G.U_hat + betas(j) * G.rho; end
    cap = 1 / (m * (1 - a_dr));                  % CVaR 风险包络上界 (α→1 时 cap→∞=worst-case)

    pi = ones(ns, 1) / ns;                       % 策略迭代 x
    p = ones(m, 1) / m;                          % 最坏分布迭代 (init 均匀)
    sum_pi = zeros(ns, 1); sum_p = zeros(m, 1); sum_w = 0;   % 遍历平均累加器 (λ_t 加权)

    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.converged = false;
    history.iterations = params.R_max;
    for t = 1:params.R_max
        step = c / sqrt(t);                      % λ_t=γ_t=c/√t (论文实验步长形式)
        q = pi;                                  % 对称 mean-field: 种群 = 当前策略
        % p 加权场景矩阵 M̄ = Σ_j p_j M^j
        Mbar = zeros(ns, ns);
        for j = 1:m; Mbar = Mbar + p(j) * Ms{j}; end
        % x 下降 (= 收益上升): π ← P_Δ(π - λ ∂_π f) = P_Δ(π + λ M̄ q)
        pi = proj_simplex(pi + step * (Mbar * q));
        % p 上升 (worst-case): 各场景代理收益 payoff_j=π'M^j q; p ← P_{P_α}(p - γ·payoff)
        payoff = zeros(m, 1);
        for j = 1:m; payoff(j) = pi' * Ms{j} * q; end
        p = proj_capped_simplex(p - step * payoff, cap);

        % 遍历平均 (λ_t 加权, 论文 Thm 5)
        sum_pi = sum_pi + step * pi; sum_p = sum_p + step * p; sum_w = sum_w + step;
        pi_bar = sum_pi / sum_w; p_bar = sum_p / sum_w;

        % 可利用性 gap (最坏分布 p̄ 下 π̄ 的最优偏离)
        Mbar_b = zeros(ns, ns);
        for j = 1:m; Mbar_b = Mbar_b + p_bar(j) * Ms{j}; end
        val_bar = pi_bar' * (Mbar_b * pi_bar);
        gap = max(Mbar_b * pi_bar) - val_bar;
        history.residual(t) = gap;
        history.avg_payoff(t) = val_bar;
        if gap <= params.eps_tol
            history.residual = history.residual(1:t);
            history.avg_payoff = history.avg_payoff(1:t);
            history.converged = true;
            history.iterations = t;
            break;
        end
    end
    pi_star = repmat(pi_bar', N, 1);
end

function w = proj_simplex(v)
%PROJ_SIMPLEX 欧氏投影到概率单纯形 (Duchi et al. 2008)。
    v = v(:); n = numel(v);
    u = sort(v, 'descend'); css = cumsum(u);
    rho = find(u + (1 - css) ./ (1:n)' > 0, 1, 'last');
    tau = (css(rho) - 1) / rho;
    w = max(v - tau, 0);
end

function p = proj_capped_simplex(y, cap)
%PROJ_CAPPED_SIMPLEX 欧氏投影到封顶单纯形 {p: Σp=1, 0≤p_j≤cap} (θ 二分法)。
%   p_j(θ)=min(cap,max(0,y_j-θ)), S(θ)=Σp_j(θ) 关于 θ 单调递减; 二分求 S(θ)=1。
    y = y(:);
    if cap >= 1                              % cap≥1: 上界不起作用, 退化为普通单纯形投影
        p = proj_simplex(y); return;
    end
    lo = min(y) - 1; hi = max(y);
    for it = 1:100
        th = (lo + hi) / 2;
        s = sum(min(cap, max(0, y - th)));
        if s > 1; lo = th; else; hi = th; end
    end
    th = (lo + hi) / 2;
    p = min(cap, max(0, y - th));
    p = p / sum(p);                          % 数值兜底归一
end
