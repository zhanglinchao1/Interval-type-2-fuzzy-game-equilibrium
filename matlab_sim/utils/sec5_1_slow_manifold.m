function x_star = sec5_1_slow_manifold(omega, params, x_init)
%SEC5_1_SLOW_MANIFOLD 论文 §5.1 实验三 慢流形 x*(ω): 固定 ω 下快子系统稳态
%
%   计算复制动态 (4-31) 在固定 ω (即固定 θ = P_pay·ω) 下的稳态:
%       x*(ω) = lim_{t→∞} x(t),    ẋ_j = x_j[U_j(x,θ) - Ū(x,θ)]
%
%   这是论文定理 4 中慢流形 M_s = {(x*(ω), ω) : g(x*(ω), ω) = 0} 的快子系统部分。
%   实验三用 d_slow(T) = ||x(T) - x*(ω(T))||_2 量化 (4-43) 的 O(ε_g) 邻域。
%
%   实现: Euler 前向迭代直到 max|Δx| < eps_tol 或达到 T_max。
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
