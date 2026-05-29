function sigma_val = sec3_2_bounded_sigma(Delta)
%SEC3_2_BOUNDED_SIGMA 论文 §3.2 公式 (3-7) / (4-36) 中的有界 Lipschitz 映射 σ(·)
%   把规则绩效增益 Δ 映射到 K 维单纯形 Δ^K
%   使用数值稳定的 softmax，自动满足有界（输出在单纯形上）和 Lipschitz 连续
%
%   输入:
%       Delta - K×1 向量
%   输出:
%       sigma_val - K×1 向量，∈ Δ^K

    Delta_shifted = Delta - max(Delta);
    exp_D = exp(Delta_shifted);
    sigma_val = exp_D / sum(exp_D);
end
