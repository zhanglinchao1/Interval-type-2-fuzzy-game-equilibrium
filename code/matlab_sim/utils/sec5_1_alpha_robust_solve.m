function [pi_star, history] = sec5_1_alpha_robust_solve(params, delta, theta, alpha)
%SEC5_1_ALPHA_ROBUST_SOLVE α-cut 鲁棒-悲观下界决策的 W-FBRI 求解器
%
%   功能 (论文 §5.1 实验二新版 Proposed 方法):
%   与 sec4_3_1_wfbri_solve 类似, 但纯策略收益向量用 α-cut 下界 (公式 4-13):
%       ν_{i,j}^(r) = U_lower^α_i(δ_j, π_{-i}^(r); θ)
%                   = Û_i - (1-α)·ρ_i      其中 ρ_i 为基础不确定半径 (4-11)
%   这使得 α 真正进入算法决策路径, 而非仅做事后鲁棒判定。
%
%   当 α=1 时该函数退化为 sec4_3_1_wfbri_solve (Û 决策)。
%   当 α<1, δ>0 时, 该函数实现真正的鲁棒-悲观决策, 表现出更低的扰动响应方差。
%
%   输入:
%       params - 参数结构体 (含 N, num_strategies, lambda, beta, R_max, eps_tol, rng_seed)
%       delta  - IT2 不确定性半带宽
%       theta  - 3×1 收益层权重
%       alpha  - α-cut 置信水平 (0, 1]
%   输出:
%       pi_star - N×4 矩阵, 收敛后的均衡策略
%       history - 结构体, 记录 residual / avg_payoff / strategy_dist / iterations

    N = params.N;
    num_s = params.num_strategies;
    lambda = params.lambda;
    beta = params.beta;
    R_max = params.R_max;
    eps_tol = params.eps_tol;

    rng(params.rng_seed);
    pi_profile = ones(N, num_s) / num_s;
    pi_profile = pi_profile + 0.01 * rand(N, num_s);
    pi_profile = pi_profile ./ sum(pi_profile, 2);

    history.residual = zeros(R_max, 1);
    history.avg_payoff = zeros(R_max, 1);
    history.strategy_dist = zeros(R_max, num_s);

    for r = 1:R_max
        pi_new = zeros(N, num_s);

        for i = 1:N
            % α-cut 鲁棒下界决策: ν_{i,j} = Û_i - (1-α)·ρ_i
            nu_i = compute_alpha_lower_payoff(pi_profile, delta, theta, ...
                params, i, alpha);
            br_i = sec4_3_1_softmax_br(nu_i, lambda);
            pi_new(i, :) = (1 - beta) * pi_profile(i, :) + beta * br_i';
        end

        residuals = sum(abs(pi_new - pi_profile), 2);
        e_pi = max(residuals);

        [mu_l, mu_u] = sec4_1_1_induced_membership(pi_new, delta, params);
        [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
        [U_hat, ~] = sec4_2_1_crystallized_payoff(U_l, U_u);

        history.residual(r) = e_pi;
        history.avg_payoff(r) = mean(U_hat);
        history.strategy_dist(r, :) = mean(pi_new, 1);

        pi_profile = pi_new;

        if e_pi <= eps_tol
            history.residual = history.residual(1:r);
            history.avg_payoff = history.avg_payoff(1:r);
            history.strategy_dist = history.strategy_dist(1:r, :);
            history.converged = true;
            history.iterations = r;
            break;
        end
        if r == R_max
            history.converged = false;
            history.iterations = R_max;
        end
    end

    pi_star = pi_profile;
end

function nu_i = compute_alpha_lower_payoff(pi_profile, delta, theta, ...
    params, agent_idx, alpha)
% α-cut 鲁棒-悲观下界的纯策略收益向量 (公式 4-13):
%   ν_{i,j} = U^α_lower_i = Û_i - (1-α)·ρ_i
    num_s = params.num_strategies;
    nu_i = zeros(num_s, 1);

    for j = 1:num_s
        pi_temp = pi_profile;
        pi_pure = zeros(1, num_s);
        pi_pure(j) = 1.0;
        pi_temp(agent_idx, :) = pi_pure;

        [mu_l, mu_u] = sec4_1_1_induced_membership(pi_temp, delta, params);
        [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
        [U_hat, rho] = sec4_2_1_crystallized_payoff(U_l, U_u);

        nu_i(j) = U_hat(agent_idx) - (1 - alpha) * rho(agent_idx);
    end
end
