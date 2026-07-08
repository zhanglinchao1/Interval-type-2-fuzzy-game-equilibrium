function M = sota_reduced_matrix(theta, params)
%SOTA_REDUCED_MATRIX  归约 agent-vs-群体纯策略收益矩阵 M(j,k)。
%
%   功能:
%     在点隶属度 (δ=0) 下计算 M(j,k) = Û( 代表 agent 取纯策略 j | 群体全取纯策略 k ),
%     把 mean-field 交互压缩为一个 ns×ns 双矩阵博弈视图, 供需要"对手分布"的鲁棒
%     SOTA (如 RQE 对 M 的列分布取 CVaR) 使用。
%
%   输入:
%     theta  - 收益层权重
%     params - 参数结构体 (需含 N, num_strategies)
%   输出:
%     M      - ns×ns 归约收益矩阵, M(j,k)=代表 agent 取 j、群体取 k 时的晶化收益

    ns = params.num_strategies;
    N = params.N;
    M = zeros(ns, ns);
    for k = 1:ns
        pop = zeros(N, ns);
        pop(:, k) = 1;
        [~, ~, U_hat] = sec4_1_2_pure_interval_payoff_vector( ...
            pop, 0, theta, params, 1);
        M(:, k) = U_hat;
    end
end
