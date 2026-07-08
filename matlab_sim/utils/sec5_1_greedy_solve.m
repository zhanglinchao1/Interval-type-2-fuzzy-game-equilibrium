function [pi_star, history] = sec5_1_greedy_solve(params, delta, theta)
%SEC5_1_GREEDY_SOLVE 论文 §5.1 实验一对照方法: 贪心算法
%   每轮每个智能体选择当前最大即时收益策略（确定性最好响应）
%
%   输入:
%       params - 参数结构体
%       delta  - 不确定性半带宽
%       theta  - 3×1 收益层权重
%   输出:
%       pi_star - N×4 矩阵
%       history - 收敛历史结构体

    N = params.N;
    num_s = params.num_strategies;
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
            nu_i = sec4_3_1_pure_payoff_vector(pi_profile, delta, theta, ...
                params, i);
            [~, best_j] = max(nu_i);
            pi_new(i, best_j) = 1.0;
        end

        residuals = sum(abs(pi_new - pi_profile), 2);
        e_pi = max(residuals);

        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_new, delta, theta, params);

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
