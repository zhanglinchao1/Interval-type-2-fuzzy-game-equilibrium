function [pi_profile, history] = sota_init(params)
%SOTA_INIT  统一初始化 mean-field SOTA solver 的策略剖面与 history 记录结构。
%
%   功能:
%     为外部 SOTA 学习/鲁棒求解器 (OGDA/OMWU/EG/RQE/CVaR-game) 提供与论文
%     Proposed 求解器一致的初始化与历史记录容器, 保证收敛轮数 R、残差曲线、
%     收敛证书判定在所有方法间口径统一 (供 exp_5_1_6 的 CI/配对差异/收敛图复用)。
%
%   输入:
%     params - 参数结构体, 需含 N, num_strategies, R_max, rng_seed
%   输出:
%     pi_profile - N×num_strategies 初始策略剖面 (近均匀 + 小随机扰动, 行归一)
%     history    - 结构体, 预分配 residual/avg_payoff/strategy_dist 及收敛标志
%
%   注: rng(params.rng_seed) 与 Proposed 求解器同种子起点, 保证公平对比。

    rng(params.rng_seed);
    ns = params.num_strategies;
    pi_profile = ones(params.N, ns) / ns + 0.01 * rand(params.N, ns);
    pi_profile = pi_profile ./ sum(pi_profile, 2);

    history.residual = zeros(params.R_max, 1);
    history.avg_payoff = zeros(params.R_max, 1);
    history.strategy_dist = zeros(params.R_max, ns);
    history.converged = false;
    history.iterations = params.R_max;
end
