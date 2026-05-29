function Delta_h = sec4_4_3_governance_performance(x, omega, P_pay, params)
%SEC4_4_3_GOVERNANCE_PERFORMANCE 论文 §4.4.3 公式 (4-36) 规则绩效增益向量 Δ(x,ω)
%   论文 (3-7) 与 (4-36) 要求 Δ 显式依赖 (x, ω):
%       绩效信号 = 当前权重下系统状态的"可观察改善方向"
%   实现思路:
%       1. 由当前 ω 计算收益层权重 θ = P_pay ω，并归一化
%       2. 计算群体在该 θ 下各类策略的晶化收益 U_j(x,θ)
%       3. 群体可达加权收益 U_pop = x' U_j 代表当前"治理表现"
%       4. 每条规则 ℓ 的绩效信号 = 边际增益 - ω_ℓ * U_pop（惯性抑制项保证显式依赖 ω）
%
%   输入:
%       x      - 4×1 群体策略分布
%       omega  - K×1 当前治理权重
%       P_pay  - 3×K 投影矩阵
%       params - 参数结构体
%
%   输出:
%       Delta_h - K×1 规则绩效增益向量

    K = length(omega);

    % 步骤1: 当前 ω 诱导的收益层权重
    theta = P_pay * omega;
    s = sum(theta);
    if s > 0
        theta = theta / s;
    else
        theta = ones(3, 1) / 3;
    end

    % 步骤2: 在当前 θ 下，群体各策略的晶化收益
    U_j = sec4_4_1_population_payoff(x, theta, params);

    % 步骤3: 群体加权收益（"当前治理表现"标量）
    U_pop = x' * U_j;

    % 步骤4: 群体加权三类隶属度
    mu_bar = zeros(3, 1);
    for j = 1:4
        mu_bar(1) = mu_bar(1) + x(j) * params.trust_matrix(j, :) * x;
        mu_bar(2) = mu_bar(2) + x(j) * params.delay_matrix(j, :) * x;
        mu_bar(3) = mu_bar(3) + x(j) * params.res_matrix(j, :) * x;
    end

    Delta_h = zeros(K, 1);
    for ell = 1:K
        col_ell = P_pay(:, ell);             % 3×1
        marginal_gain = col_ell' * mu_bar;
        % 当前权重对该规则的"惯性抑制"项 -> 显式依赖 ω
        omega_penalty = omega(ell) * U_pop;
        Delta_h(ell) = marginal_gain - omega_penalty;
    end

    % 轻微噪声模拟观测扰动（保持有界 Lipschitz）
    Delta_h = Delta_h + 0.005 * randn(K, 1);
end
