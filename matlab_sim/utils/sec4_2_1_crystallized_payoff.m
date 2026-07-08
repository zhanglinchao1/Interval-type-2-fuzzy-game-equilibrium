function [U_hat, rho] = sec4_2_1_crystallized_payoff(U_lower, U_upper)
%SEC4_2_1_CRYSTALLIZED_PAYOFF 论文 §4.2.1 公式 (4-10)~(4-11) type-reduced 中心收益与基础不确定半径
%     Û_i = (U_lower + U_upper) / 2
%     ρ_i = (U_upper - U_lower) / 2
%
%   注 (Route C 凹聚合, 见 sec4_1_2_it2_payoff.m):
%       当 U_lower=Σθg(μ-δ), U_upper=Σθg(μ+δ) 且 g(μ)=2μ-μ² 时, 闭式为
%           Û_i = Σθ_k g(μ_k) - Σθ_k δ_k²  = U_T1 - Σθδ²   (uniform FOU)
%           ρ_i = Σθ_k (1-μ_k) δ_k · 2 = Σθ_k 2(1-μ_k) δ_k
%       其中 Type-1 名义中心 U_T1 = Σθ_k g(μ_k) (凹聚合后的名义收益, 非 Σθμ),
%       Û 较 U_T1 下移 Σθδ² (曲率诱导的中心偏移), 这是 Type-1 ≠ IT2 的结构性
%       来源。本函数对聚合方式不可知, 公式 (4-10)~(4-11) 不变。
%
%   输入:
%       U_lower - N×1 向量
%       U_upper - N×1 向量
%   输出:
%       U_hat   - N×1 向量，type-reduced 中心收益
%       rho     - N×1 向量，基础不确定半径

    U_hat = (U_lower + U_upper) / 2;
    rho   = (U_upper - U_lower) / 2;
end
