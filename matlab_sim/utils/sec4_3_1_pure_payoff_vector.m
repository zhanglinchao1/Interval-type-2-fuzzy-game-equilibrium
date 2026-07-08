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

    [~, ~, nu_i] = sec4_1_2_pure_interval_payoff_vector( ...
        pi_profile, delta, theta, params, agent_idx);
end
