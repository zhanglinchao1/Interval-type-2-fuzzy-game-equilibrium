function [pi_star, history] = sec4_3_1_wfbri_solve(params, delta, theta)
%SEC4_3_1_WFBRI_SOLVE 论文 §4.3.1 算法 1 W-FBRI 均衡求解主函数
%   对应公式 (4-18)(4-20)(4-21): 加权模糊最好响应迭代
%
%   输入:
%       params - 参数结构体 (来自 config_params)
%       delta  - 不确定性半带宽
%       theta  - 3×1 收益层权重
%   输出:
%       pi_star - N×4 矩阵，收敛后的均衡策略
%       history - 结构体，记录收敛过程

    N = params.N;
    num_s = params.num_strategies;
    lambda = params.lambda;
    beta = params.beta;
    R_max = params.R_max;
    eps_tol = params.eps_tol;

    % 步骤1: 初始化混合策略
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
            % 步骤2: 纯策略晶化收益向量 (公式4-18)
            nu_i = sec4_3_1_pure_payoff_vector(pi_profile, delta, theta, ...
                params, i);

            % 步骤3: 软最好响应 (公式4-20)
            br_i = sec4_3_1_softmax_br(nu_i, lambda);

            % 步骤4: 阻尼更新 (公式4-21)
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
