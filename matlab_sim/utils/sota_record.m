function [pi_profile, history, stop] = sota_record(pi_old, pi_new, ...
    history, r, delta, theta, params)
%SOTA_RECORD  记录一轮迭代的残差/平均收益/策略分布, 并按 eps_tol 判定收敛。
%
%   功能:
%     统一所有 mean-field SOTA solver 的每轮记账逻辑, 使残差 e_π=max_i ||Δπ_i||_1、
%     平均晶化收益、策略分布、收敛轮数在各方法间口径一致 (与论文 Proposed 求解器
%     的收敛判定完全相同), 供 exp_5_1_6 的收敛证书统计与 fig5_16 收敛图复用。
%
%   输入:
%     pi_old/pi_new - 本轮更新前/后的 N×num_strategies 策略剖面
%     history       - sota_init 产生的历史结构体
%     r             - 当前轮次
%     delta         - 决策侧 FOU 半带宽 (仅用于记录平均收益, 不改变收敛判定)
%     theta         - 收益层权重
%     params        - 参数结构体 (需含 eps_tol, R_max)
%   输出:
%     pi_profile - 更新后的策略剖面 (= pi_new)
%     history    - 追加本轮记录后的历史结构体 (收敛时截断到 r 并置 converged)
%     stop       - 是否达到收敛阈值 (e_π <= eps_tol)

    e_pi = max(sum(abs(pi_new - pi_old), 2));
    [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
        pi_new, delta, theta, params);

    history.residual(r) = e_pi;
    history.avg_payoff(r) = mean(U_hat);
    history.strategy_dist(r, :) = mean(pi_new, 1);
    pi_profile = pi_new;

    stop = e_pi <= params.eps_tol;
    if stop
        history.residual = history.residual(1:r);
        history.avg_payoff = history.avg_payoff(1:r);
        history.strategy_dist = history.strategy_dist(1:r, :);
        history.converged = true;
        history.iterations = r;
    elseif r == params.R_max
        history.converged = false;
        history.iterations = params.R_max;
    end
end
