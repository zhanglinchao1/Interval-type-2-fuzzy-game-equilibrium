function lambda_max_T = sec5_1_jacobian_lambda_max(x_star, theta, params)
%SEC5_1_JACOBIAN_LAMBDA_MAX 论文 §5.1 实验三 定理 3 (4-34) 切空间最大对称特征值
%
%   计算复制动态 f_j(x) = x_j[U_j(x,θ) - Ū(x,θ)] 在 x_star 处的 Jacobian J,
%   取对称部分 J_sym = (J + J')/2, 投影到单纯形切空间
%       T = { v ∈ R^4 : sum(v) = 0 }
%   并返回切空间内的最大特征值 λ_max^T。
%
%   定理 3 切空间负定条件 (4-34): λ_max^T < 0 在 Fuzzy-ESS 处必须严格成立。
%
%   实现:
%       1. 用中心差分数值估计 J = ∂f/∂x (4×4)
%       2. J_sym = (J + J') / 2 (对称化)
%       3. 取切空间正交基 B = null(ones(1,4)) (4×3)
%       4. 计算 J_T = B' * J_sym * B (3×3, 切空间限制)
%       5. λ_max^T = max(eig(J_T))
%
%   输入:
%       x_star - 4×1 评估点 (通常为快子系统稳态)
%       theta  - 3×1 收益层权重
%       params - 参数结构体
%   输出:
%       lambda_max_T - 标量, 切空间最大对称特征值
%
%   论文公式对应: §4.4.2 (4-32)~(4-34)

    n = length(x_star);
    h = 1e-6;

    J = zeros(n, n);
    for k = 1:n
        ek = zeros(n, 1); ek(k) = 1;
        xp = x_star + h * ek;
        xm = x_star - h * ek;
        J(:, k) = (replicator_rhs(xp, theta, params) ...
                 - replicator_rhs(xm, theta, params)) / (2 * h);
    end

    J_sym = (J + J') / 2;

    B = null(ones(1, n));        % n × (n-1), 切空间正交基
    J_T = B' * J_sym * B;        % (n-1) × (n-1), 切空间限制
    eigs_T = eig(J_T);
    lambda_max_T = max(real(eigs_T));
end

function dxdt = replicator_rhs(x, theta, params)
%REPLICATOR_RHS  复制动态右端 f_j(x) = x_j[U_j(x,θ) - Ū(x,θ)]
    U_j = sec4_4_1_population_payoff(x, theta, params);
    U_bar = x' * U_j;
    dxdt = x .* (U_j - U_bar);
end
