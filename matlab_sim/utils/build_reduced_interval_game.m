function G = build_reduced_interval_game(params, delta)
%BUILD_REDUCED_INTERVAL_GAME 构造 Module A 公平对比的"公共两人对称区间收益实例"
%
%   用途 (que.md §2.1 / §A4 单一数据来源):
%       由 params 的同一套状态核矩阵 M_k (trust/delay/res)、同一收益层权重 θ、
%       同一 FOU 半带宽 δ 与同一曲率感知凹聚合 g(μ)=2μ−μ²(论文 §4.1.2 Route C),
%       生成一个 4×4 的区间收益矩阵, 作为三篇 fuzzy-game SOTA 求解器的**统一矩阵博弈输入**。
%       所有方法消费逐格相同的 [U_lo,U_hi], 把比较聚焦于"决策/求解规则"。
%
%   风险耦合口径 (与 scenario_b_env / scenario_b_payoff_stats 完全一致):
%       本实例应传入 scenario_b_env 产出的 params(中段隶属度核 + bell FOU + 策略暴露),
%       使 SC 等激进策略名义收益略高但 FOU 暴露最大、在偶发 SC 定向冲击下脆弱 ——
%       这是 α-悲观鲁棒决策"应当生效"的工况(详见 scenario_b_env)。
%
%   归约 + FOU 口径 (与 sec4_1_1_induced_membership 逐格对齐):
%       本方纯策略 j(行)对对手纯策略 l(列)时, 状态 k 名义隶属度 μ_k(j,l)=M_k(j,l);
%       FOU 半宽 δ_eff(j,l,k) = δ·φ(μ)·s_j, 其中
%         φ(μ)=4μ(1−μ) (bell 调制, params.fou_modulation=true 时启用; 否则 φ≡1),
%         s_j = params.fou_strategy_scale(j) (本方策略暴露; 缺省为 1)。
%       端点凹聚合得区间收益 U_lo=Σθg(μ−δ_eff), U_hi=Σθg(μ+δ_eff)。
%
%   输入:
%       params - 参数结构体, 需含 trust_matrix/delay_matrix/res_matrix(4×4)、theta(3×1);
%                可选 fou_modulation(逻辑) 与 fou_strategy_scale(1×4 策略暴露)
%       delta  - 标量, IT2 不确定性半带宽基准
%   输出:
%       G - 结构体, 公共实例(SOTA 矩阵博弈输入, single source of truth):
%           .S/.theta/.delta/.exposure/.fou_modulation
%           .M(1×3 cell 状态核) .U_lo/.U_hi/.U_hat/.rho/.U_T1 (各 4×4)

    theta = params.theta(:);
    M = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    num_s = params.num_strategies;

    use_bell = isfield(params, 'fou_modulation') && params.fou_modulation;
    if isfield(params, 'fou_strategy_scale') && ~isempty(params.fou_strategy_scale)
        exposure = params.fou_strategy_scale(:);     % 4×1 本方策略暴露
    else
        exposure = ones(num_s, 1);
    end

    U_lo = zeros(num_s, num_s);
    U_hi = zeros(num_s, num_s);
    U_T1 = zeros(num_s, num_s);
    for k = 1:3
        mu = M{k};                                   % 4×4 名义隶属度
        if use_bell
            delta_eff = delta * (4 * mu .* (1 - mu)) .* exposure;   % bell·暴露(按行)
        else
            delta_eff = delta * exposure .* ones(num_s, num_s);     % uniform·暴露(按行)
        end
        mu_lo = max(0, mu - delta_eff);
        mu_hi = min(1, mu + delta_eff);
        U_lo = U_lo + theta(k) * (2 * mu_lo - mu_lo.^2);
        U_hi = U_hi + theta(k) * (2 * mu_hi - mu_hi.^2);
        U_T1 = U_T1 + theta(k) * (2 * mu    - mu.^2);
    end

    G.S              = params.S;
    G.theta          = theta;
    G.delta          = delta;
    G.exposure       = exposure(:)';
    G.fou_modulation = use_bell;
    G.M              = M;
    G.U_lo           = U_lo;
    G.U_hi           = U_hi;
    G.U_hat          = (U_lo + U_hi) / 2;
    G.rho            = (U_hi - U_lo) / 2;
    G.U_T1           = U_T1;
end
