function [x_hist, omega_hist, theta_hist, V_hist] = sec4_4_4_dual_timescale(...
    x0, omega0, params)
%SEC4_4_4_DUAL_TIMESCALE 论文 §4.4.4 公式 (4-38a)~(4-38b) 双时间尺度系统仿真
%     ẋ_j = x_j[U_j(x,θ) - Ū(x,θ)]      (快时标: 复制动态)
%     ω̇_ℓ = ε_g * g_ℓ(x,ω)               (慢时标: 治理更新)
%   其中 g_ℓ(x,ω) = σ_ℓ(Δ_ℓ(x,ω)) - ω_ℓ，Δ 显式依赖 (x,ω)
%
%   离散化方式: Euler 前向，dt 为时间步
%   说明: 真实公式(4-31)是连续 ODE。此处采用 Euler 前向作为一阶近似，
%         以保留对论文符号的逐项对应，便于读者比对。
%
%   输入:
%       x0     - 4×1 初始群体策略分布
%       omega0 - K×1 初始治理权重
%       params - 参数结构体
%
%   输出:
%       x_hist     - T×4 矩阵，策略分布演化
%       omega_hist - T×K 矩阵，治理权重演化
%       theta_hist - T×3 矩阵，收益层权重演化
%       V_hist     - T×1 向量，联合 Lyapunov 势函数序列
%                   V(x,ω) = V_x(x; θ(ω)) + c_Φ * Φ(ω)
%                   用于第五章实验三验证 (4-42) 下降性

    T = params.T_evo;
    dt = params.dt_evo;
    varepsilon_g = params.varepsilon_g;
    K = length(omega0);
    P_pay = params.P_pay;
    c_Phi = 1.0;  % Lyapunov 联合系数 c_Φ (论文 4-42)

    x_hist = zeros(T, 4);
    omega_hist = zeros(T, K);
    theta_hist = zeros(T, 3);
    V_hist = zeros(T, 1);

    x = x0(:);
    omega = omega0(:);

    x_ref = x;
    omega_ref = omega;

    for t = 1:T
        theta = P_pay * omega;
        theta = max(theta, 0);
        s = sum(theta);
        if s > 0
            theta = theta / s;
        else
            theta = ones(3, 1) / 3;
        end

        x_hist(t, :) = x';
        omega_hist(t, :) = omega';
        theta_hist(t, :) = theta';

        % --- 快时标: 复制动态 (公式4-31) ---
        U_j = sec4_4_1_population_payoff(x, theta, params);
        U_bar = x' * U_j;
        dx = x .* (U_j - U_bar);
        x_next = x + dt * dx;
        x_next = max(x_next, 1e-10);
        x_next = x_next / sum(x_next);

        % --- 慢时标: 治理更新 (公式4-36, Δ 显式依赖 ω) ---
        Delta_h = sec4_4_3_governance_performance(x_next, omega, P_pay, params);
        sigma_Delta = sec3_2_bounded_sigma(Delta_h);
        g = sigma_Delta - omega;

        omega_next = omega + varepsilon_g * dt * g;
        omega_next = sec3_2_project_simplex(omega_next);

        % --- Lyapunov 势函数(4-42) ---
        V_x = local_kl_divergence(x_ref, x);
        Phi = 0.5 * sum((omega - omega_ref).^2);
        V_hist(t) = V_x + c_Phi * Phi;

        x = x_next;
        omega = omega_next;
    end

    % 以最终状态作为参考点重算 V_hist，便于检验下降性
    x_final = x_hist(end, :)';
    omega_final = omega_hist(end, :)';
    for t = 1:T
        xt = x_hist(t, :)';
        ot = omega_hist(t, :)';
        V_hist(t) = local_kl_divergence(x_final, xt) + ...
                    c_Phi * 0.5 * sum((ot - omega_final).^2);
    end
end

function v = local_kl_divergence(p, q)
%LOCAL_KL_DIVERGENCE 计算 KL(p || q)，对应论文(4-32)势函数形式
    p = p(:);
    q = max(q(:), 1e-10);
    mask = p > 1e-12;
    v = sum(p(mask) .* log(p(mask) ./ q(mask)));
end
