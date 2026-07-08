function g = sota_grad_vector(pi_profile, delta, theta, alpha, params)
%SOTA_GRAD_VECTOR  各 agent 各纯策略的 α-cut 鲁棒决策值 (作为博弈梯度)。
%
%   功能:
%     计算 g_{i,j} = Û_{i,j} - (1-α)·ρ_{i,j}, 即 agent i 单方偏移到纯策略 j 时的
%     α-cut 鲁棒-悲观决策值 (论文公式 4-13 的标量 α 形式)。供基于梯度/乘性更新的
%     收敛赛道 SOTA (OGDA/OMWU/Extragradient) 作为"收益梯度"使用。
%
%   FOU 处理:
%     - α=1, δ=0 时退化为期望晶化收益 Û (FOU-agnostic 梯度), 即收敛 SOTA 的默认口径;
%     - α<1 或 δ>0 时为 FOU-aware 鲁棒决策值。本文收敛赛道令这些方法 δ=0、α=1,
%       以诚实呈现"它们不建模 FOU"——这是支柱 I (鲁棒决策面认证收敛) 的对照前提。
%
%   输入:
%     pi_profile - N×num_strategies 当前策略剖面
%     delta      - FOU 半带宽 (FOU-agnostic 取 0)
%     theta      - 收益层权重
%     alpha      - α-cut 置信水平 (FOU-agnostic 取 1)
%     params     - 参数结构体 (需含 N, num_strategies)
%   输出:
%     g          - N×num_strategies 决策值矩阵

    N = params.N;
    ns = params.num_strategies;
    [~, ~, U_hat, rho] = sec4_1_2_pure_interval_payoff_matrix( ...
        pi_profile, delta, theta, params);
    g = U_hat - (1 - alpha) * rho;
end
