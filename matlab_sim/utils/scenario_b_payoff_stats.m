function [expected_payoff, wc_q5] = scenario_b_payoff_stats(pi_star, ...
    ~, theta, params, n_perturb, p_shock, sigma_small, ...
    shock_strength)
%SCENARIO_B_PAYOFF_STATS  混合扰动: 小高斯扰动 + 偶发逆向冲击 (双场景)。
%   返回 mean(U_hat) 的期望 (expected_payoff) 与 5% 分位数 (wc_q5, 最差尾部)。
%   以概率 p_shock 触发尾部冲击, 模拟激进策略在偶发不利事件下的脆弱性;
%   其余轮次仅施加小幅高斯扰动。
%
%   冲击目标模式 (由 params.shock_mode 决定, 缺省 'concentrated' 向后兼容):
%     'concentrated' (v1): 冲击只打 SC (策略 1), 与历史版本逐位等价 (RNG 不变);
%     'dispersed'    (v2): 冲击按各策略暴露 params.fou_strategy_scale 归一概率随机
%                          命中某一策略 (消除免费安全策略, 更公平的鲁棒评估)。
%
%   注 (Route C 公平性): "实现收益"在点隶属度 (δ=0) 下评估 —— 扰动/冲击已是
%   不确定性的一次实现, FOU 半带宽 δ 是决策时的先验不确定带, 不应再叠加到实现
%   收益上。各方法仅在求解 π* 时按各自 δ 决策, 实现收益统一在 δ=0 评估, 差异
%   完全来自决策 π* 的鲁棒性。delta_solve 保留仅作签名兼容, 不进入实现收益计算。
%
%   RNG 兼容性: rng(params.rng_seed + 520) 起点不变; v1 路径冲击目标固定为 SC
%   (不消耗额外随机数), 故与历史数据逐位一致; 仅 v2 路径在触发冲击时多抽一次
%   目标策略 (独立于求解器 in-sample RNG, 信息对称公平)。

    % 冲击目标分布: v2 按暴露加权, v1 固定 SC
    if isfield(params, 'shock_mode') && strcmp(params.shock_mode, 'dispersed')
        scale = params.fou_strategy_scale(:)';
        target_dist = scale / sum(scale);
        dispersed = true;
    else
        dispersed = false;          % v1: 冲击只打 SC (策略 1)
    end

    delta_realized = 0;   % 实现收益采用点隶属度 (见上)
    U_hat_means = zeros(n_perturb, 1);
    rng(params.rng_seed + 520);
    for k = 1:n_perturb
        p = params;
        p.trust_matrix = clip01(params.trust_matrix + ...
            sigma_small * randn(size(params.trust_matrix)));
        p.delay_matrix = clip01(params.delay_matrix + ...
            sigma_small * randn(size(params.delay_matrix)));
        p.res_matrix = clip01(params.res_matrix + ...
            sigma_small * randn(size(params.res_matrix)));

        if rand() < p_shock
            if dispersed
                t = sample_target(target_dist);   % v2: 按暴露随机抽目标
            else
                t = 1;                            % v1: 固定 SC (不消耗 RNG)
            end
            p.trust_matrix = apply_strategy_shock(p.trust_matrix, t, shock_strength);
            p.delay_matrix = apply_strategy_shock(p.delay_matrix, t, shock_strength);
            p.res_matrix = apply_strategy_shock(p.res_matrix, t, shock_strength);
        end

        [~, ~, U_hat] = sec4_1_2_mixed_payoff( ...
            pi_star, delta_realized, theta, p);
        U_hat_means(k) = mean(U_hat);
    end
    expected_payoff = mean(U_hat_means);
    wc_q5 = quantile(U_hat_means, 0.05);
end

function M = apply_strategy_shock(M, t, shock_strength)
% APPLY_STRATEGY_SHOCK  对策略 t 相关交互施加偶发逆向冲击 (t 行 -sk, t 列 -0.5sk)。
%   t=1 时与历史 apply_sc_shock 逐位等价 (SC 定向冲击)。
    M(t, :) = M(t, :) - shock_strength;
    M(:, t) = M(:, t) - 0.5 * shock_strength;
    M = clip01(M);
end

function t = sample_target(prob)
% SAMPLE_TARGET  按概率向量 prob 抽样一个策略下标 (v2 暴露加权冲击目标)。
    c = cumsum(prob);
    u = rand();
    t = find(u <= c, 1, 'first');
    if isempty(t)
        t = numel(prob);
    end
end

function y = clip01(x)
% 数值裁剪到 [0, 1]
    y = max(0, min(1, x));
end
