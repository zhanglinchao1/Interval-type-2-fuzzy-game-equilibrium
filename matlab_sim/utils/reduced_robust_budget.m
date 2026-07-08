function [floor_val, budget, center, radius] = reduced_robust_budget(G, pi, alpha)
%REDUCED_ROBUST_BUDGET 归约实例上的 α-cut 鲁棒决策下界 floor 与 Lemma 1 先验预算
%
%   用途 (que.md §4.4 统一 floor 口径 + §4.2.3 certified budget):
%       对**任意**策略 π(无论由哪种方法产出), 在同一 δ-区间博弈 G 上以**同一评价 α**
%       计算其 α-cut 鲁棒决策下界(论文 (4-13)):
%           center = π'·Û·π,  radius = π'·ρ·π
%           floor  = ν_α(π) = center − (1−α)·radius
%       并给出 Lemma 1(公式 (4-15)) 的先验鲁棒预算 budget = 2(1−α)·radius。
%       该 floor 即 ex-post violation 的统一判据(对所有方法用同一 α, 见 que.md §4.4)。
%
%   输入:
%       G     - build_reduced_interval_game 产出的公共实例(含 U_hat/rho)
%       pi    - 4×1(或行) 混合策略
%       alpha - 评价用 α-cut 置信水平(对所有方法一致, 默认调用方传 0.5)
%   输出:
%       floor_val - 标量, α-cut 鲁棒决策下界 ν_α(π)
%       budget    - 标量, Lemma 1 先验鲁棒预算 2(1−α)·radius
%       center    - 标量, type-reduced 中心 π'·Û·π
%       radius    - 标量, FOU 半径 π'·ρ·π

    p = pi(:);
    center = p' * G.U_hat * p;
    radius = p' * G.rho   * p;
    floor_val = center - (1 - alpha) * radius;
    budget    = 2 * (1 - alpha) * radius;
end
