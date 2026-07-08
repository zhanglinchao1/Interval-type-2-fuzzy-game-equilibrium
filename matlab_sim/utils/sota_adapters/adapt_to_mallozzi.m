function out = adapt_to_mallozzi(U_lo, U_hi, eta)
%ADAPT_TO_MALLOZZI 把公共区间收益适配为 Mallozzi & Vidal-Puga (2023) 的固定 Hurwicz 实例
%
%   用途 (que.md §2.2 适配器口径 + §9 诚信边界): 用其原始构造子 interval_payoff
%   生成区间博弈表示, 并按其固定 Hurwicz 态度算子(原文 hurwicz_matrix)给出标量化
%   crisp 收益矩阵 M_eta = (1−η)U_lo + η·U_hi。其闭式求解器仅支持 2×2; 4 策略归约实例
%   的混合 Nash 由调用方在 M_eta 上求解(implemented from the published formulation),
%   并可在 2×2 子实例上调用其 fixed_hurwicz_2x2 作交叉校验。
%
%   输入:
%       U_lo, U_hi - m×n, 区间收益下/上界
%       eta        - 标量∈[0,1], 固定 Hurwicz 乐观系数(η=0.5 中性; η=0 最坏端点)
%   输出:
%       out.interval - Mallozzi 区间博弈 payoff 结构体(其 interval_payoff 构造)
%       out.M_eta    - m×n, 固定 Hurwicz 标量化 crisp 收益矩阵
%       out.eta      - 标量, 所用 η

    if nargin < 3 || isempty(eta)
        eta = 0.5;
    end
    out.interval = mallozzi_vidalpuga_2023_solver('interval_payoff', U_lo, U_hi);
    out.M_eta = (1 - eta) * U_lo + eta * U_hi;   % 原文 hurwicz_matrix 在区间(lo1=hi1=0)下的化简
    out.eta = eta;
end
