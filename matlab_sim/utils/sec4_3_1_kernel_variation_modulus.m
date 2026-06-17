function [D_theta, info] = sec4_3_1_kernel_variation_modulus(params, theta)
%SEC4_3_1_KERNEL_VARIATION_MODULUS 论文 §4.3.2 命题 1 的核变差模量 D(θ)
%   对应公式 (4-Dtheta):
%       D(θ) = max_{j≠j'} (1/2) · range_l( Σ_k θ_k [M_k(j,l) - M_k(j',l)] )
%   该常数与定理 2 的收缩条件配合: κ = D(θ)/(2λ), q_th = (1-β) + β·κ。
%   仅依赖成对交互核矩阵与收益层权重, 完全可由公开参数复算 (结构化, 非采样估计)。
%
%   输入:
%       params - 参数结构体 (需含 trust_matrix / delay_matrix / res_matrix)
%       theta  - 3×1 收益层权重 (trust, delay, res), Σθ_k = 1
%   输出:
%       D_theta - 核变差模量 (标量)
%       info    - 诊断信息: 加权核 W、取得最大值的策略对 (j, j')

    % θ 加权后的合成核 W(j,l) = Σ_k θ_k M_k(j,l)
    W = theta(1) * params.trust_matrix ...
      + theta(2) * params.delay_matrix ...
      + theta(3) * params.res_matrix;

    num_s = size(W, 1);
    D_theta = 0;
    info.argmax_pair = [1, 1];

    % 遍历所有策略对 (j, j'), 取行差向量极差的一半的最大值
    for j = 1:num_s
        for jp = (j+1):num_s
            diff_row = W(j, :) - W(jp, :);
            half_range = 0.5 * (max(diff_row) - min(diff_row));
            if half_range > D_theta
                D_theta = half_range;
                info.argmax_pair = [j, jp];
            end
        end
    end

    info.W = W;
end
