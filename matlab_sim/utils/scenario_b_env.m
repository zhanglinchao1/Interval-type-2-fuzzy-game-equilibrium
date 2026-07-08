function params_B = scenario_b_env(base_params, fou_scale)
%SCENARIO_B_ENV  风险-收益耦合 Scenario B 环境 (kernels + 策略暴露)。
%   SC (激进共享) 名义收益最高, 但其隶属度落在中段, 此处 4μ(1-μ) 最大,
%   FOU 半宽最大; 配合 fou_strategy_scale 的策略暴露权重, 使过度押注 SC
%   在偶发 SC 定向逆向冲击下变得脆弱。该环境是 α-悲观决策"应当生效"的
%   风险-收益耦合工况, 区别于 config_params 的良性核 (SC 在三维度均干净占优)。
%
%   共享来源: 原为 exp_5_1_2_robustness.m 的局部构造 (Step 8b),
%   抽取为共享工具供 exp_5_1_2 与 exp_5_1_6_sota_algorithm_baselines 共用,
%   保证两处 Scenario B 使用同一份核与暴露定义 (single source of truth)。
%
%   输入:
%       base_params - 基础参数结构体 (config_params 输出, 含 rng_seed/N/...)
%       fou_scale   - 1×4 或 4×1 策略暴露权重 [SC, SP, DC, DP]
%   输出:
%       params_B    - 启用 bell-shaped FOU + 策略暴露 + 耦合核的参数结构体

    params_B = base_params;
    params_B.fou_modulation = true;
    params_B.fou_strategy_scale = fou_scale;

    % Risk-return coupled kernels: SC has the highest nominal payoff, but
    % its memberships stay in the middle range where 4*mu*(1-mu) is large.
    % The strategy exposure scale then makes aggressive sharing fragile.
    params_B.trust_matrix = [0.66, 0.64, 0.61, 0.58;
                             0.60, 0.57, 0.54, 0.50;
                             0.55, 0.52, 0.49, 0.46;
                             0.50, 0.47, 0.44, 0.41];
    params_B.delay_matrix = [0.67, 0.65, 0.62, 0.59;
                             0.61, 0.58, 0.55, 0.51;
                             0.56, 0.53, 0.50, 0.47;
                             0.51, 0.48, 0.45, 0.42];
    params_B.res_matrix = [0.65, 0.63, 0.60, 0.57;
                           0.59, 0.56, 0.53, 0.50;
                           0.54, 0.51, 0.48, 0.45;
                           0.49, 0.46, 0.43, 0.40];
end
