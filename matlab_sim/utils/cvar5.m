function c = cvar5(values, level)
%CVAR5 下尾条件风险价值 CVaR(相干风险测度), 默认 5% 水平
%
%   用途 (que.md §4.1 / stag.md:212): 作为收益的尾部风险指标, 替代裸 Q5 分位。
%   对收益(越大越好)取**下尾**: CVaR_level = 在最差 level 比例情形下的平均收益,
%   即 E[X | X ≤ VaR_level], 比单点分位更稳、更标准, 满足相干性(次可加)。
%
%   输入:
%       values - 向量, 同一策略在多次扰动 draw 下的实现收益
%       level  - (可选) 尾部比例, 默认 0.05
%   输出:
%       c      - 标量, 下尾 CVaR(最差 level 比例收益的均值)

    if nargin < 2 || isempty(level)
        level = 0.05;
    end
    v = sort(values(:), 'ascend');
    n = numel(v);
    if n == 0
        c = NaN;
        return;
    end
    % 至少取 1 个样本进入尾部, 保证小样本下也有定义
    k = max(1, floor(level * n));
    c = mean(v(1:k));
end
