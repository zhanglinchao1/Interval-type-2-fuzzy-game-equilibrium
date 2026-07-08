function [D_theta, info] = sec4_3_1_kernel_variation_modulus(params, theta)
%SEC4_3_1_KERNEL_VARIATION_MODULUS 论文 §4.3.2 命题 1 的核变差模量 D_ν(θ)
%   控制定理 2 收缩条件: κ = D_ν(θ)/(2λ), q_th = (1-β) + β·κ。
%   完全由成对交互核矩阵 + 收益层权重 + 聚合方式闭式/确定性给出 (非采样估计)。
%
%   收益向量 (平均场) ν_j(x̄) = Σ_k θ_k g(μ_k(j)), μ_k(j) = (M_k x̄)_j = Σ_l M_k(j,l) x̄_l。
%   模量定义为相邻纯策略收益差 gap_{jj'}(x̄)=ν_j(x̄)-ν_{j'}(x̄) 关于群体态 x̄ 的
%   Lipschitz 半极差上界:
%       D_ν(θ) = max_{j≠j'} (1/2) · sup_{x̄∈Δ} range_l( ∂ gap_{jj'} / ∂ x̄_l )。
%
%   (a) 'linear' (g(μ)=μ, g'=1): ∂gap/∂x̄_l = W(j,l)-W(j',l) 与 x̄ 无关,
%       退化为闭式 D = max_{j≠j'} (1/2) range_l(W(j,l)-W(j',l)), W=Σθ_k M_k。
%   (b) 'concave_quadratic' (g(μ)=2μ-μ², g'(μ)=2-2μ):
%       ∂gap/∂x̄_l = Σ_k θ_k [g'(μ_k(j)) M_k(j,l) - g'(μ_k(j')) M_k(j',l)]。
%       D_ν(θ) 取其在群体单纯形 Δ 上的上确界, 在确定性单纯形网格 (步长 1/G_GRID)
%       上逐点求值取最大 (非随机采样; gap 梯度半极差在紧集 Δ 上连续, 网格密则逼近真值)。
%       同时给出闭式解析包络: D_ν(θ) ≤ L_g·D_linear(θ), L_g=sup_{μ∈[0,1]}|g'(μ)|=2,
%       以及更保守的盒松弛上界 (见 info.D_box), 供认证窗的鲁棒性核验。
%
%   输入:
%       params - 参数结构体 (含 trust_matrix/delay_matrix/res_matrix;
%                可选 payoff_aggregation, 默认 'concave_quadratic')
%       theta  - 3×1 收益层权重 (trust, delay, res), Σθ_k = 1
%   输出:
%       D_theta - 核变差模量 D_ν(θ) (标量; 凹聚合下为确定性严格上界)
%       info    - 诊断: W 合成核、argmax 策略对、D_kernel(线性闭式)、L_g、聚合方式

    if isfield(params, 'payoff_aggregation') && ~isempty(params.payoff_aggregation)
        aggregation = lower(params.payoff_aggregation);
    else
        aggregation = 'concave_quadratic';
    end

    M = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    K = numel(M);
    num_s = size(M{1}, 1);
    theta = theta(:);

    % θ 加权合成核 W(j,l) = Σ_k θ_k M_k(j,l) (用于线性闭式与诊断)
    W = theta(1) * M{1} + theta(2) * M{2} + theta(3) * M{3};

    % ---- 线性闭式 D_kernel (同时作为诊断基准) ----
    D_kernel = 0;
    argmax_pair = [1, 1];
    for j = 1:num_s
        for jp = (j+1):num_s
            d_row = W(j, :) - W(jp, :);
            hr = 0.5 * (max(d_row) - min(d_row));
            if hr > D_kernel
                D_kernel = hr;
                argmax_pair = [j, jp];
            end
        end
    end

    switch aggregation
        case 'linear'
            L_g = 1;
            D_theta = D_kernel;
            info_extra_box = D_kernel;   % 线性下盒上界即闭式值
        case {'concave_quadratic', 'concave'}
            L_g = 2;   % sup_{μ∈[0,1]} |g'(μ)| = |2-2·0| = 2

            % --- (b1) 确定性单纯形网格上的真实 sup (向量化) ---
            G_GRID = 24;                       % 步长 1/24, C(27,3)=2925 个网格点
            grid = local_compositions(G_GRID, num_s) / G_GRID;   % P×num_s
            P = size(grid, 1);
            D_theta = 0;
            for j = 1:num_s
                for jp = 1:num_s
                    if j == jp; continue; end
                    grad = zeros(P, num_s);    % 每点每坐标 l 的 ∂gap/∂x̄_l
                    for l = 1:num_s
                        acc = zeros(P, 1);
                        for k = 1:K
                            muj  = grid * M{k}(j, :)';     % P×1
                            mujp = grid * M{k}(jp, :)';
                            gpj  = 2 - 2 * muj;            % g'(μ_k(j))
                            gpjp = 2 - 2 * mujp;
                            acc = acc + theta(k) * ...
                                (gpj * M{k}(j, l) - gpjp * M{k}(jp, l));
                        end
                        grad(:, l) = acc;
                    end
                    half_range = 0.5 * (max(grad, [], 2) - min(grad, [], 2));
                    hr = max(half_range);
                    if hr > D_theta
                        D_theta = hr;
                        argmax_pair = [j, jp];
                    end
                end
            end

            % --- (b2) 盒松弛严格上界 (诊断用, 见 info.D_box) ---
            D_box = local_box_relaxation(M, theta, K, num_s);
            info_extra_box = D_box;
        otherwise
            error('sec4_3_1_kernel_variation_modulus:badAggregation', ...
                '未知聚合模式 "%s"', aggregation);
    end

    info.W = W;
    info.argmax_pair = argmax_pair;
    info.D_kernel = D_kernel;             % 线性闭式模量 (基准)
    info.L_g = L_g;                       % g 的全局 Lipschitz 常数
    info.D_Lg_bound = L_g * D_kernel;     % 解析包络 L_g·D(θ)
    info.D_box = info_extra_box;          % 盒松弛严格上界 (诊断)
    info.aggregation = aggregation;
end

% ===== 本地辅助函数 =====
function C = local_compositions(G, parts)
% LOCAL_COMPOSITIONS  所有非负整数组合 sum=G、长度=parts (单纯形整点网格)
    if parts == 1
        C = G;
        return;
    end
    C = [];
    for a = 0:G
        sub = local_compositions(G - a, parts - 1);
        C = [C; a * ones(size(sub, 1), 1), sub]; %#ok<AGROW>
    end
end

function D_box = local_box_relaxation(M, theta, K, num_s)
% LOCAL_BOX_RELAXATION  对 (a_k,b_k)=g'(μ) 区间盒做顶点枚举, 给 D_ν 的严格上界
    gprime_lo = zeros(K, num_s); gprime_hi = zeros(K, num_s);
    for k = 1:K
        mu_min = min(M{k}, [], 2); mu_max = max(M{k}, [], 2);
        gprime_lo(k, :) = (2 - 2 * mu_max)';   % g'=2-2μ 关于 μ 单调减
        gprime_hi(k, :) = (2 - 2 * mu_min)';
    end
    num_vertices = 2^(2 * K);
    D_box = 0;
    for j = 1:num_s
        for jp = 1:num_s
            if j == jp; continue; end
            Mj = zeros(K, num_s); Mjp = zeros(K, num_s);
            aLo = gprime_lo(:, j);  aHi = gprime_hi(:, j);
            bLo = gprime_lo(:, jp); bHi = gprime_hi(:, jp);
            for k = 1:K
                Mj(k, :) = M{k}(j, :); Mjp(k, :) = M{k}(jp, :);
            end
            for v = 0:(num_vertices - 1)
                bits = bitget(v, 1:(2 * K));
                a_vec = aLo + bits(1:K)'      .* (aHi - aLo);
                b_vec = bLo + bits(K+1:2*K)'  .* (bHi - bLo);
                grad = ((theta .* a_vec)' * Mj) - ((theta .* b_vec)' * Mjp);
                hr = 0.5 * (max(grad) - min(grad));
                if hr > D_box; D_box = hr; end
            end
        end
    end
end
