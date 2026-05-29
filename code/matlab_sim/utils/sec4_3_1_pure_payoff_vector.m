function nu_i = sec4_3_1_pure_payoff_vector(pi_profile, delta, theta, ...
    params, agent_idx)
%SEC4_3_1_PURE_PAYOFF_VECTOR 论文 §4.3.1 公式 (4-18) 智能体 i 的纯策略晶化收益向量
%     ν_{i,j}^(r) = Û_i(δ_j, π_{-i}^(r); θ)
%
%   输入:
%       pi_profile - N×4 矩阵
%       delta      - 不确定性半带宽
%       theta      - 3×1 收益层权重
%       params     - 参数结构体
%       agent_idx  - 智能体索引
%   输出:
%       nu_i       - 4×1 向量，纯策略晶化收益

    num_s = params.num_strategies;
    nu_i = zeros(num_s, 1);

    for j = 1:num_s
        pi_temp = pi_profile;
        pi_pure = zeros(1, num_s);
        pi_pure(j) = 1.0;
        pi_temp(agent_idx, :) = pi_pure;

        [mu_lower, mu_upper] = sec4_1_1_induced_membership(pi_temp, delta, params);
        [U_lower, U_upper] = sec4_1_2_it2_payoff(mu_lower, mu_upper, theta);
        [U_hat, ~] = sec4_2_1_crystallized_payoff(U_lower, U_upper);

        nu_i(j) = U_hat(agent_idx);
    end
end
