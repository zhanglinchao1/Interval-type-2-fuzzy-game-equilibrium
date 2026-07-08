function W = proj_simplex_rows(X)
%PROJ_SIMPLEX_ROWS  将矩阵每行欧氏投影到概率单纯形 (Duchi et al. 2008 排序法)。
%
%   功能:
%     供基于投影的对偶平均型 SOTA (OGDA / Extragradient) 在每轮把梯度上升后的
%     未归一化策略行投影回 Δ^{ns-1}。逐行调用 O(ns log ns) 排序投影, 数值稳定。
%
%   输入:
%     X - N×ns 实矩阵 (梯度步之后的未约束策略)
%   输出:
%     W - N×ns 矩阵, 每行为 X 对应行在概率单纯形上的投影

    W = zeros(size(X));
    for i = 1:size(X, 1)
        W(i, :) = project_one(X(i, :));
    end
end

function w = project_one(v)
% 单行欧氏投影到概率单纯形 (Duchi et al. 2008, Fig.1 算法)
    v = v(:)';
    n = numel(v);
    u = sort(v, 'descend');
    css = cumsum(u);
    rho = find(u + (1 - css) ./ (1:n) > 0, 1, 'last');
    tau = (css(rho) - 1) / rho;
    w = max(v - tau, 0);
end
