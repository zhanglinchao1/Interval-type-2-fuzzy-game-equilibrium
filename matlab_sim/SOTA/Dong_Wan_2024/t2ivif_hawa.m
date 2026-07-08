function out = t2ivif_hawa(items, weights, gamma)
%T2IVIF_HAWA Type-2 interval-valued intuitionistic fuzzy Hamacher weighted
%   averaging (T2IVIFHAWA) aggregation operator of Dong and Wan (2024).
%
%   OUT = T2IVIF_HAWA(ITEMS, WEIGHTS, GAMMA) aggregates a collection of
%   T2IVIFSs with the Hamacher t-(co)norm of order GAMMA (Eq.(3) in the
%   paper). Special cases: GAMMA = 1 gives the algebraic operator
%   (T2IVIFWA, Eq.(4)); GAMMA = 2 gives the Einstein operator
%   (T2IVIFEWA, Eq.(5)).
%
%   Inputs
%     ITEMS   : numeric array reshapeable to [N, 8], each row a T2IVIFS with
%               component order [muL, muU, fL, fU, vL, vU, gL, gU], i.e.
%               IVPMF = [muL, muU], IVSMF = [fL, fU],
%               IVPNMF = [vL, vU], IVSNMF = [gL, gU].
%     WEIGHTS : length-N nonnegative weight vector (auto-normalised to sum 1).
%     GAMMA   : Hamacher parameter (GAMMA >= 1).
%
%   Output
%     OUT     : 1-by-8 aggregated T2IVIFS in the same component order.
%
%   The four membership-type components (1-4) use the Hamacher averaging
%   form for the "good" direction; the four non-membership-type components
%   (5-8) use the dual Hamacher form. The implementation reproduces the
%   worked Example 2 of the paper bit-for-bit (see
%   test_dong_wan_2024_reproduction.m).

    data = reshape(items, [], 8);
    w = weights(:);
    w = w / sum(w);

    out = zeros(1, 8);
    out(1) = hamacher_membership(data(:, 1), w, gamma);
    out(2) = hamacher_membership(data(:, 2), w, gamma);
    out(3) = hamacher_membership(data(:, 3), w, gamma);
    out(4) = hamacher_membership(data(:, 4), w, gamma);
    out(5) = hamacher_nonmembership(data(:, 5), w, gamma);
    out(6) = hamacher_nonmembership(data(:, 6), w, gamma);
    out(7) = hamacher_nonmembership(data(:, 7), w, gamma);
    out(8) = hamacher_nonmembership(data(:, 8), w, gamma);
end

function y = hamacher_membership(x, w, gamma)
% 隶属型分量的 Hamacher 加权平均(原文 Eq.(3) 上半部分)。
    a = weighted_prod(1 + (gamma - 1) * x, w);
    b = weighted_prod(1 - x, w);
    y = (a - b) / (a + (gamma - 1) * b);
end

function y = hamacher_nonmembership(x, w, gamma)
% 非隶属型分量的 Hamacher 加权平均(原文 Eq.(3) 下半部分)。
% 注意 gamma-(gamma-1)x = 1+(gamma-1)(1-x), 与原文一致。
    a = weighted_prod(x, w);
    b = weighted_prod(gamma - (gamma - 1) * x, w);
    y = gamma * a / (b + (gamma - 1) * a);
end

function p = weighted_prod(x, w)
% 加权几何积 prod(x.^w), 用 log-sum-exp 形式保证数值稳定。
    p = exp(sum(w .* log(max(x(:), realmin))));
end
