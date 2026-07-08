function [U_lower, U_upper] = sec4_1_2_it2_payoff(mu_lower, mu_upper, theta, aggregation)
%SEC4_1_2_IT2_PAYOFF 论文 §4.1.2 公式 (4-5)~(4-6) 区间二型模糊收益上下界
%   曲率感知单调凹聚合 (Route C, 默认):
%       U_lower_i(π;θ) = Σ_k θ_k · g(μ_lower_k_i(π))
%       U_upper_i(π;θ) = Σ_k θ_k · g(μ_upper_k_i(π))
%   其中 g(μ) = 2μ - μ²  (单调增 g'=2-2μ≥0; 严格凹 g''=-2; g(0)=0, g(1)=1; L_g=2)
%
%   线性回归对照 (aggregation = 'linear'):
%       U_lower_i(π;θ) = Σ_k θ_k · μ_lower_k_i(π)
%       U_upper_i(π;θ) = Σ_k θ_k · μ_upper_k_i(π)
%
%   设计动机 (TFS Route C):
%       在线性聚合下, type-reduced center Û=(U̲+Ū)/2 退化为 Type-1 名义收益
%       Û = Σθ_k μ_k (δ 完全不进 Û, 仅进半径 ρ)。改用单调凹 g 后:
%           Û_IT2 = ½[g(μ-δ)+g(μ+δ)]·θ = U_T1 - Σθ_k δ_k²   (uniform FOU)
%       即 FOU 端点不确定性通过聚合曲率的二阶项进入 type-reduced 决策中心,
%       使 Type-1 ≠ IT2 成为结构性、可证、可测的差异。g 单调保证
%       g(μ_lo) ≤ g(μ_hi), 区间有效, 闭式 O(1) type reduction 仍成立。
%
%   输入:
%       mu_lower    - N×3 矩阵, 隶属度下界 [trust, delay, res]
%       mu_upper    - N×3 矩阵, 隶属度上界
%       theta       - 3×1 向量, 收益层权重
%       aggregation - (可选) 字符串, 'concave_quadratic'(默认) | 'linear'
%   输出:
%       U_lower     - N×1 向量, 收益下界
%       U_upper     - N×1 向量, 收益上界

    if nargin < 4 || isempty(aggregation)
        aggregation = 'concave_quadratic';   % Route C 默认: 曲率感知凹聚合
    end

    switch lower(aggregation)
        case 'linear'
            % 线性聚合 (旧版/回归对照): Û 与 δ 解析无关, Type-1 = IT2-midpoint
            U_lower = mu_lower * theta;
            U_upper = mu_upper * theta;
        case {'concave_quadratic', 'concave'}
            % 凹聚合: 先逐元素施加 g(μ)=2μ-μ², 再按 θ 加权
            g_lower = 2 * mu_lower - mu_lower.^2;
            g_upper = 2 * mu_upper - mu_upper.^2;
            U_lower = g_lower * theta;
            U_upper = g_upper * theta;
        otherwise
            error('sec4_1_2_it2_payoff:badAggregation', ...
                '未知聚合模式 "%s" (应为 concave_quadratic 或 linear)', aggregation);
    end
end
