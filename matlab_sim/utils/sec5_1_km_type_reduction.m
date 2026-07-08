function [c_l, c_r, n_iter] = sec5_1_km_type_reduction(U_lower, U_upper, m, use_ekm)
%SEC5_1_KM_TYPE_REDUCTION 迭代式 KM/EKM 质心 type-reduction（外部基线，论文 §5.1 实验五）
%   把收益区间 [U_lower, U_upper] 视为矩形 FOU 的区间二型模糊集
%   （UMF ≡ 1、LMF ≡ 0，见论文附录 A 的 Lemma 1 设定），在离散论域上
%   执行标准 Karnik–Mendel (KM) 或增强 KM (EKM) 切换点迭代，数值计算
%   质心型 type-reduced 区间 [c_l, c_r]。
%
%   Lemma 1 预言：对矩形 FOU，KM/EKM 迭代应精确终止于
%       [c_l, c_r] = [U_lower, U_upper]
%   本函数用于实证该预言并测量迭代开销（与闭式 O(1) 路径对照）。
%
%   输入:
%       U_lower, U_upper - 收益区间端点 (标量)
%       m                - 论域离散点数 (默认 101)
%       use_ekm          - true 用 EKM 初始化 (k=round(m/2.4))，false 用标准 KM
%   输出:
%       c_l, c_r - type-reduced 质心区间端点
%       n_iter   - 两端点切换点迭代的总轮数（开销度量）
%
%   参考: Karnik & Mendel (2001); Wu & Mendel (EKM)。

    if nargin < 3, m = 101; end
    if nargin < 4, use_ekm = false; end

    % 退化区间直接返回（KM 对零宽 FOU 无需迭代）
    if U_upper - U_lower <= eps
        c_l = U_lower; c_r = U_upper; n_iter = 0;
        return;
    end

    % 离散论域与矩形 FOU 的上下隶属度
    u = linspace(U_lower, U_upper, m);   % 论域网格 u_1 <= ... <= u_m
    umf = ones(1, m);                    % UMF ≡ 1
    lmf = zeros(1, m);                   % LMF ≡ 0

    % EKM 与 KM 的差别仅在切换点初始化
    if use_ekm
        k0_l = round(m / 2.4);
        k0_r = round(m / 1.7);
    else
        k0_l = -1;  % 标记: KM 用全 UMF 平均初始化
        k0_r = -1;
    end

    [c_l, it_l] = km_endpoint(u, umf, lmf, 'left',  k0_l);
    [c_r, it_r] = km_endpoint(u, umf, lmf, 'right', k0_r);
    n_iter = it_l + it_r;
end

function [c, n_iter] = km_endpoint(u, umf, lmf, side, k0)
%KM_ENDPOINT 单侧 KM 切换点迭代
%   side='left':  p<=k 取 UMF、p>k 取 LMF（压低质心 -> c_l）
%   side='right': p<=k 取 LMF、p>k 取 UMF（抬高质心 -> c_r）
    m = length(u);
    max_iter = 100;

    % 初始切换点
    if k0 > 0
        k = min(max(k0, 1), m - 1);
    else
        % 标准 KM: 用全 UMF 质心定位初始 k
        c0 = sum(umf .* u) / max(sum(umf), eps);
        k = locate_switch(u, c0);
    end

    n_iter = 0;
    while true
        n_iter = n_iter + 1;
        if strcmp(side, 'left')
            w = [umf(1:k), lmf(k+1:end)];
        else
            w = [lmf(1:k), umf(k+1:end)];
        end
        sw = sum(w);
        if sw <= eps
            % 矩形 FOU 下 LMF≡0 可能导致一侧权重全零:
            % 按 KM 约定将切换点向有效方向收缩一格后重试
            if strcmp(side, 'left'); k = max(k - 1, 1); else; k = min(k + 1, m - 1); end
            if n_iter >= max_iter
                c = u(1); return;
            end
            continue;
        end
        c_new = sum(w .* u) / sw;
        k_new = locate_switch(u, c_new);
        if k_new == k || n_iter >= max_iter
            c = c_new;
            return;
        end
        k = k_new;
    end
end

function k = locate_switch(u, c)
%LOCATE_SWITCH 找切换点 k 使 u_k <= c <= u_{k+1}
    m = length(u);
    k = find(u <= c, 1, 'last');
    if isempty(k), k = 1; end
    k = min(max(k, 1), m - 1);
end
