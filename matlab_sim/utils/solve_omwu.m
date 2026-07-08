function [pi_star, history] = solve_omwu(params, delta, theta, alpha)
%SOLVE_OMWU  Optimistic Multiplicative Weights Update / Optimistic Hedge (收敛 SOTA)。
%
%   参考: Rakhlin & Sridharan 2013; Syrgkanis et al. 2015; Daskalakis, Fishelson
%         & Golowich 2021。角色 (收敛赛道 / 支柱 I 对照): 乘性乐观更新
%       π^{(r+1)} ∝ π^{(r)} ⊙ exp( η (2 g^{(r)} - g^{(r-1)}) ), 行归一,
%   其中 g = sota_grad_vector(·, δ, θ, α)。在 benign 核享 O(1/T) 平均收敛, 但同样
%   FOU-agnostic、不做 α-cut 鲁棒决策、无 family-uniform 收敛证书、无治理耦合。
%
%   输入:
%     params - 参数结构体 (含 lambda/beta 等; 可选 omwu_eta)
%     delta  - 决策侧 FOU 半带宽 (收敛赛道取 0)
%     theta  - 收益层权重
%     alpha  - α-cut 置信水平 (收敛赛道取 1)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面
%     history - 残差/收敛轮数/收敛标志

    if isfield(params, 'omwu_eta'); eta = params.omwu_eta; else; eta = 6.0; end
    [pi_profile, history] = sota_init(params);
    g_prev = sota_grad_vector(pi_profile, delta, theta, alpha, params);
    for r = 1:params.R_max
        g = sota_grad_vector(pi_profile, delta, theta, alpha, params);
        w = pi_profile .* exp(eta * (2 * g - g_prev));
        pi_new = w ./ sum(w, 2);
        g_prev = g;
        [pi_profile, history, stop] = sota_record(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end
