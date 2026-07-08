function c = sota_cvar_lower(values, weights, tau)
%SOTA_CVAR_LOWER  下尾条件风险价值 CVaR_τ (风险规避者关注低收益尾部)。
%
%   功能:
%     计算加权样本在置信水平 τ 下的下尾条件均值 (lower-tail CVaR), 即把概率质量
%     按收益升序累积到 τ 为止的条件期望。供 RQE / CVaR-game 等鲁棒 SOTA 把收益
%     分布的左尾压缩为一个标量决策值。τ→0 趋于最坏样本, τ→1 趋于全样本均值。
%
%   输入:
%     values  - 样本收益向量
%     weights - 样本权重向量 (内部归一化; 等权传 ones(numel(values),1))
%     tau     - 下尾置信水平 ∈ (0,1]
%   输出:
%     c       - 下尾 CVaR_τ 标量

    values = values(:);
    weights = weights(:);
    weights = weights / sum(weights);
    [v, idx] = sort(values, 'ascend');
    w = weights(idx);
    c = 0;
    acc = 0;
    for k = 1:numel(v)
        take = min(w(k), tau - acc);
        if take <= 0
            break;
        end
        c = c + take * v(k);
        acc = acc + take;
    end
    c = c / tau;
end
