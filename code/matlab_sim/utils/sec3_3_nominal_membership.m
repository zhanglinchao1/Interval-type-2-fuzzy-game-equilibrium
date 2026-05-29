function mu_nominal = sec3_3_nominal_membership(pi_profile, params)
%SEC3_3_NOMINAL_MEMBERSHIP 论文 §3.3 + §4.2 平均场近似：群体策略诱导的三类名义隶属度
%   对应公式 (3-9)~(3-13) 的实现版本
%   在平均场假设下，群体平均策略 x̄ 作为他人策略的紧凑代表
%
%   输入:
%       pi_profile - N×4 矩阵，每行为智能体 i 的混合策略
%       params     - 参数结构体
%   输出:
%       mu_nominal - N×3 矩阵，列对应 [trust, delay, res]

    % 群体策略统计量（平均场）
    x_bar = mean(pi_profile, 1);  % 1×4 群体平均策略分布

    mu_trust = pi_profile * (params.trust_matrix * x_bar');
    mu_delay = pi_profile * (params.delay_matrix * x_bar');
    mu_res   = pi_profile * (params.res_matrix * x_bar');

    mu_trust = max(0, min(1, mu_trust));
    mu_delay = max(0, min(1, mu_delay));
    mu_res   = max(0, min(1, mu_res));

    mu_nominal = [mu_trust, mu_delay, mu_res];
end
