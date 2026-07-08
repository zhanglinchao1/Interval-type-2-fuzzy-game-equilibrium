function [Dt_rho, info] = sec4_3_1_radius_profile_modulus(params, theta, delta)
%SEC4_3_1_RADIUS_PROFILE_MODULUS 推论 2 (C-28) 的半径剖面模量 D̃_ρ (均匀 FOU 闭式)
%   均匀 FOU + 二次凹聚合下, ρ_j(x̄) = Σ_k θ_k·2(1−M_k(j,:)x̄)·δ_k 对 x̄ 仿射
%   (g''≡−2 使 g'(μ±δ) 展开精确), 故模量为闭式严格上界:
%       D̃_ρ = max_j (1/2)·range_l( 2·Σ_k θ_k δ_k M_k(j,l) )。
%   聚焦族认证条件 (C-29): κ^(s) = [D_ν + 2(1−α)(1+2s)·D̃_ρ]/(2λ) < 1。
%
%   输入:
%       params - 参数结构体 (含 trust_matrix/delay_matrix/res_matrix)
%       theta  - 3×1 收益层权重, Σθ_k = 1
%       delta  - 均匀 FOU 半带宽 δ (标量, 各维共用)
%   输出:
%       Dt_rho - 半径剖面模量 D̃_ρ (闭式)
%       info   - 诊断: 合成核 W、argmax 策略 j_star、κ^(s) 求值句柄

    M = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    theta = theta(:);
    W = theta(1) * M{1} + theta(2) * M{2} + theta(3) * M{3};

    grad_rows = 2 * delta * W;   % |∂ρ_j/∂x̄_l| 行 (符号不影响极差)
    row_range = max(grad_rows, [], 2) - min(grad_rows, [], 2);
    [Dt_rho, j_star] = max(0.5 * row_range);

    info.W = W;
    info.j_star = j_star;
    info.kappa_s = @(D_nu, alpha, s, lambda) ...
        (D_nu + 2 * (1 - alpha) * (1 + 2 * s) * Dt_rho) / (2 * lambda);
end
