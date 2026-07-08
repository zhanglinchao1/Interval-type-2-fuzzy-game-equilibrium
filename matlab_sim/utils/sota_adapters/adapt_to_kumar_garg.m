function tfn = adapt_to_kumar_garg(U_lo, U_hat, U_hi)
%ADAPT_TO_KUMAR_GARG 把公共区间收益适配为 Kumar & Garg (2025) 的 m×n×3 三角模糊张量
%
%   用途 (que.md §2.2 适配器口径): 将本文 IT2 区间收益映射为三角模糊数
%   [lower, modal, upper], 交给 kumar_garg_2025_solver('solve_somg', ·) 的两层 LP 求解。
%   modal 取 IT2 type-reduced 中心 Û(= ½(U_lo+U_hi)), 这是区间最忠实的单点摘要。
%
%   合法性: 由 build_reduced_interval_game 保证 U_lo ≤ Û ≤ U_hi(三角数有效)。
%
%   输入:
%       U_lo, U_hat, U_hi - m×n, 区间下界 / type-reduced 中心 / 上界(同尺寸)
%   输出:
%       tfn               - m×n×3 三角模糊张量 [lower, modal, upper]

    [m, n] = size(U_lo);
    tfn = zeros(m, n, 3);
    tfn(:, :, 1) = U_lo;     % lower
    tfn(:, :, 2) = U_hat;    % modal (type-reduced center)
    tfn(:, :, 3) = U_hi;     % upper
end
