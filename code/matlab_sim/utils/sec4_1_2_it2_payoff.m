function [U_lower, U_upper] = sec4_1_2_it2_payoff(mu_lower, mu_upper, theta)
%SEC4_1_2_IT2_PAYOFF 论文 §4.1.2 公式 (4-5)~(4-6) 区间二型模糊收益上下界
%     U_lower_i(π;θ) = Σ_k θ_k * μ_lower_k_i(π)
%     U_upper_i(π;θ) = Σ_k θ_k * μ_upper_k_i(π)
%
%   输入:
%       mu_lower - N×3 矩阵，隶属度下界 [trust, delay, res]
%       mu_upper - N×3 矩阵，隶属度上界
%       theta    - 3×1 向量，收益层权重
%   输出:
%       U_lower  - N×1 向量，收益下界
%       U_upper  - N×1 向量，收益上界

    U_lower = mu_lower * theta;
    U_upper = mu_upper * theta;
end
