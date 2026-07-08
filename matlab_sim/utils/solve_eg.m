function [pi_star, history] = solve_eg(params, delta, theta, alpha)
%SOLVE_EG  Extragradient method (收敛赛道 SOTA)。
%
%   参考: Korpelevich 1976; Cai, Oikonomou & Zheng 2022 (tight last-iterate)。
%   角色 (收敛赛道 / 支柱 I 对照): 两步外梯度
%       π^{(r+1/2)} = Proj_Δ( π^{(r)} + η g(π^{(r)}) ),
%       π^{(r+1)}   = Proj_Δ( π^{(r)} + η g(π^{(r+1/2)}) ),
%   其中 g = sota_grad_vector(·, δ, θ, α)。benign 核收敛快, 但 FOU-agnostic、
%   无 α-cut 鲁棒决策、无收敛证书、无治理耦合。
%
%   输入:
%     params - 参数结构体 (可选 eg_eta)
%     delta  - 决策侧 FOU 半带宽 (收敛赛道取 0)
%     theta  - 收益层权重
%     alpha  - α-cut 置信水平 (收敛赛道取 1)
%   输出:
%     pi_star - N×num_strategies 收敛策略剖面
%     history - 残差/收敛轮数/收敛标志

    if isfield(params, 'eg_eta'); eta = params.eg_eta; else; eta = 2.0; end
    [pi_profile, history] = sota_init(params);
    for r = 1:params.R_max
        g1 = sota_grad_vector(pi_profile, delta, theta, alpha, params);
        pi_half = proj_simplex_rows(pi_profile + eta * g1);
        g2 = sota_grad_vector(pi_half, delta, theta, alpha, params);
        pi_new = proj_simplex_rows(pi_profile + eta * g2);
        [pi_profile, history, stop] = sota_record(pi_profile, pi_new, ...
            history, r, delta, theta, params);
        if stop; break; end
    end
    pi_star = pi_profile;
end
