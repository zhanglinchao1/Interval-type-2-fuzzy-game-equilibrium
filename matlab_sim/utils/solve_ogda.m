function [pi_star, history] = solve_ogda(params, delta, theta, alpha)
%SOLVE_OGDA  Optimistic Gradient Descent-Ascent (现代 last-iterate 收敛 SOTA)。
%
%   参考: Popov 1980; Rakhlin & Sridharan 2013; Cai, Oikonomou & Zheng 2022。
%   角色 (收敛赛道 / 支柱 I 对照): 在 mean-field 决策面上做乐观梯度上升 + 单纯形投影
%       π^{(r+1)} = Proj_Δ( π^{(r)} + η (2 g^{(r)} - g^{(r-1)}) ),
%   其中 g = sota_grad_vector(·, δ, θ, α)。OGDA 的 last-iterate 收敛理论建立在固定、
%   光滑 (单调/双线性) 收益上, 不覆盖 α-cut 非光滑鲁棒决策, 也不建模 FOU 与治理。
%   本文令其 δ=0、α=1 (FOU-agnostic), 以诚实呈现"快但不鲁棒、无认证鲁棒收敛"。
%
%   输入:
%     params - 参数结构体 (N, num_strategies, R_max, eps_tol, rng_seed; 可选 ogda_eta)
%     delta  - 决策侧 FOU 半带宽 (收敛赛道取 0)
%     theta  - 收益层权重
%     alpha  - α-cut 置信水平 (收敛赛道取 1)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面
%     history - 残差/收敛轮数/收敛标志 (口径同 Proposed, 供 CI/收敛图复用)

    if isfield(params, 'ogda_eta'); eta = params.ogda_eta; else; eta = 2.0; end
    [pi_profile, history] = sota_init(params);
    g_prev = sota_grad_vector(pi_profile, delta, theta, alpha, params);
    for r = 1:params.R_max
        g = sota_grad_vector(pi_profile, delta, theta, alpha, params);
        pi_new = proj_simplex_rows(pi_profile + eta * (2 * g - g_prev));
        g_prev = g;
        [pi_profile, history, stop] = sota_record(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end
