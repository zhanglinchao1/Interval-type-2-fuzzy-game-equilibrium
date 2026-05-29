function report = sec4_2_2_robust_alpha_fne(pi_star, delta, theta, alpha, ...
    params, num_deviations)
%SEC4_2_2_ROBUST_ALPHA_FNE 论文 §4.2.2 公式 (4-15) 鲁棒 α-FNE 不等式验证
%   对每个智能体 i，随机采样若干单边偏移 π_i'，检查:
%     U_upper_alpha(π_i', π_{-i}^*; θ) <= U_lower_alpha(π_i^*, π_{-i}^*; θ) + ε
%   并报告最小所需 ε（即 ε_α-鲁棒判定下的"偏离量"）
%
%   输入:
%       pi_star        - N×4 矩阵，待检验的均衡策略
%       delta          - 不确定性半带宽
%       theta          - 3×1 收益层权重
%       alpha          - 置信水平
%       params         - 参数结构体
%       num_deviations - 每个智能体随机采样的偏移策略数
%
%   输出 report 结构体字段:
%       eps_required - 标量，使所有智能体所有偏移都满足(4-15)所需的最小 ε
%       violation_count - 满足 eps_required=0 时的违反次数
%       max_deviation_gap - U_upper_alpha(π') - U_lower_alpha(π*) 的最大值
%       per_agent_gap - N×1 向量，每个智能体的最大 gap
%       theoretical_bound - 引理1 预算 2(1-α)ρ̄

    N = size(pi_star, 1);
    num_s = params.num_strategies;

    if nargin < 6
        num_deviations = 20;
    end

    rng(params.rng_seed + 7);  % 不同随机流，避免污染主求解器随机性

    % 当前策略下的 α-cut 下界（保守自身收益）
    [mu_l_star, mu_u_star] = sec4_1_1_induced_membership(pi_star, delta, params);
    [U_l_star, U_u_star] = sec4_1_2_it2_payoff(mu_l_star, mu_u_star, theta);
    [U_hat_star, rho_star] = sec4_2_1_crystallized_payoff(U_l_star, U_u_star);
    U_alpha_lower_star = U_hat_star - (1 - alpha) * rho_star;  % (4-13)

    per_agent_gap = zeros(N, 1);
    violation_count = 0;
    total_checks = 0;

    for i = 1:N
        gap_i = -inf;
        for d = 1:num_deviations
            if d == 1
                pi_dev = ones(1, num_s) / num_s;
            elseif d <= num_s + 1
                pi_dev = zeros(1, num_s);
                pi_dev(d - 1) = 1.0;
            else
                tmp = rand(1, num_s);
                pi_dev = tmp / sum(tmp);
            end

            pi_profile_dev = pi_star;
            pi_profile_dev(i, :) = pi_dev;

            [mu_l, mu_u] = sec4_1_1_induced_membership(pi_profile_dev, delta, params);
            [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
            [U_hat, rho] = sec4_2_1_crystallized_payoff(U_l, U_u);
            U_alpha_upper_dev = U_hat(i) + (1 - alpha) * rho(i);  % 乐观偏移收益上界

            % (4-15): U_upper_alpha(π') <= U_lower_alpha(π*) + ε
            gap = U_alpha_upper_dev - U_alpha_lower_star(i);
            if gap > gap_i
                gap_i = gap;
            end

            total_checks = total_checks + 1;
            if gap > 1e-6
                violation_count = violation_count + 1;
            end
        end
        per_agent_gap(i) = gap_i;
    end

    report.eps_required = max(0, max(per_agent_gap));
    report.violation_count = violation_count;
    report.total_checks = total_checks;
    report.max_deviation_gap = max(per_agent_gap);
    report.per_agent_gap = per_agent_gap;
    report.alpha = alpha;
    report.theoretical_bound = 2 * (1 - alpha) * max(rho_star);  % 引理1预算
end
