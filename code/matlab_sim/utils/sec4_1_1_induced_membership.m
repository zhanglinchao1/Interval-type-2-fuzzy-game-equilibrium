function [mu_lower_pi, mu_upper_pi] = sec4_1_1_induced_membership(...
    pi_profile, delta, params)
%SEC4_1_1_INDUCED_MEMBERSHIP 论文 §4.1.1 公式 (4-2)~(4-4) 策略诱导的区间二型隶属度
%
%   默认实现 (均匀 FOU): μ_lower = max(0, μ_nominal - δ), μ_upper = min(1, μ_nominal + δ)
%
%   可选扩展 (bell-shaped FOU, 论文 §3.3 公式 (3-14) 的位置依赖式 FOU):
%       δ_eff(μ) = δ × g(μ), g(μ) = 4μ(1-μ)
%       这是 IT2 模糊集合的标准 FOU 设计 (Mendel 2017), 满足:
%         - μ → 0 或 1 时 FOU → 0 (隶属度饱和处不确定性收窄)
%         - μ = 0.5 时 FOU 最大 (中部不确定性最大)
%       该模式让 ρ_i 随策略 j 异质化, 使得 α<1 的 α-cut 决策真正区别于 α=1。
%       通过 params.fou_modulation = true 启用; 默认为 false (兼容实验一/三)。
%
%   输入:
%       pi_profile - N×4 矩阵
%       delta      - 不确定性半带宽
%       params     - 参数结构体 (可选字段 fou_modulation, 默认 false)
%   输出:
%       mu_lower_pi - N×3 矩阵, 下界
%       mu_upper_pi - N×3 矩阵, 上界

    mu_nominal = sec3_3_nominal_membership(pi_profile, params);

    use_bell_fou = isfield(params, 'fou_modulation') && params.fou_modulation;
    if use_bell_fou
        % bell-shaped FOU: g(μ) = 4μ(1-μ) ∈ [0, 1]
        g = 4 * mu_nominal .* (1 - mu_nominal);
        delta_eff = delta * g;                                  % N×3 异质半宽
        mu_lower_pi = max(0, mu_nominal - delta_eff);
        mu_upper_pi = min(1, mu_nominal + delta_eff);
    else
        mu_lower_pi = max(0, mu_nominal - delta);
        mu_upper_pi = min(1, mu_nominal + delta);
    end
end
