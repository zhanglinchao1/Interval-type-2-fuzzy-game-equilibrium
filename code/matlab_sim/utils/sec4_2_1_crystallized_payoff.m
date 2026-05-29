function [U_hat, rho] = sec4_2_1_crystallized_payoff(U_lower, U_upper)
%SEC4_2_1_CRYSTALLIZED_PAYOFF 论文 §4.2.1 公式 (4-10)~(4-11) 晶化中心收益和基础不确定半径
%     Û_i = (U_lower + U_upper) / 2
%     ρ_i = (U_upper - U_lower) / 2
%
%   输入:
%       U_lower - N×1 向量
%       U_upper - N×1 向量
%   输出:
%       U_hat   - N×1 向量，晶化中心收益
%       rho     - N×1 向量，基础不确定半径

    U_hat = (U_lower + U_upper) / 2;
    rho   = (U_upper - U_lower) / 2;
end
