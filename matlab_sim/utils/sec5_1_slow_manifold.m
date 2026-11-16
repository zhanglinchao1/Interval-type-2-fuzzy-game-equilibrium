function x_star = sec5_1_slow_manifold(omega, params, x_init)
%SEC5_1_SLOW_MANIFOLD 论文 §5.1 实验三 慢流形 x*(ω): 固定 ω 下快子系统稳态
%
%   计算复制动态 (4-31) 在固定 ω (即固定 θ = P_pay·ω) 下的稳态:
%       x*(ω) = lim_{t→∞} x(t),    ẋ_j = x_j[U_j(x,θ) - Ū(x,θ)]
%
%   平衡图为 {(x*(ω), ω)}；联合均衡还要求 g(x*(ω), ω) = 0。
%   d_slow(T) = ||x(T) - x*(ω(T))||_2 度量快状态跟踪误差。
%
%   稳定内点由等收益方程直接求解；其他分支保留原 Euler 求解路径。
%
%   输入:
%       omega  - K×1 治理权重 (慢时标参数, 视为常数)
%       params - 参数结构体
%       x_init - (可选) 4×1 复制动态初值, 默认 [0.35; 0.25; 0.25; 0.15]
%   输出:
%       x_star - 4×1 快子系统稳态群体分布
%
%   论文公式对应: §4.4 (4-31), §5.1 实验三 d_slow 指标

    if nargin < 3 || isempty(x_init)
        x_init = [0.35; 0.25; 0.25; 0.15];
    end

    theta = params.P_pay * omega(:);
    theta = max(theta, 0);
    s = sum(theta);
    if s > 0
        theta = theta / s;
    else
        theta = ones(3, 1) / 3;
    end

    A = theta(1) * params.trust_matrix + ...
        theta(2) * params.delay_matrix + theta(3) * params.res_matrix;
    num_s = size(A, 1);
    Q = null(ones(1, num_s));
    tangent = Q' * ((A + A') / 2) * Q;
    bordered = [A, -ones(num_s, 1); ones(1, num_s), 0];
    if max(eig(tangent)) < -1e-12 && rcond(bordered) > 1e-12
        candidate = bordered \ [zeros(num_s, 1); 1];
        if all(candidate(1:num_s) > 0)
            x_star = candidate(1:num_s);
            return;
        end
    end

    x = x_init(:);
    x = max(x, 1e-10);
    x = x / sum(x);

    dt = params.dt_evo;
    T_max = 10 * params.T_evo;
    eps_tol = 1e-10;

    for t = 1:T_max
        U_j = sec4_4_1_population_payoff(x, theta, params);
        U_bar = x' * U_j;
        dx = x .* (U_j - U_bar);
        x_next = x + dt * dx;
        x_next = max(x_next, 1e-10);
        x_next = x_next / sum(x_next);
        if max(abs(x_next - x)) < eps_tol
            x = x_next;
            break;
        end
        x = x_next;
    end

    x_star = x;
end
