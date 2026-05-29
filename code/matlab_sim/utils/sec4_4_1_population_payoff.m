function U_j = sec4_4_1_population_payoff(x, theta, params)
%SEC4_4_1_POPULATION_PAYOFF 论文 §4.4.1 公式 (4-29) 群体同质假设下各策略的晶化收益
%   U_j(x,θ) = Û(δ_j, x; θ)
%
%   输入:
%       x      - 4×1 向量，群体策略分布 [x_SC; x_SP; x_DC; x_DP]
%       theta  - 3×1 向量，收益层权重
%       params - 参数结构体
%   输出:
%       U_j    - 4×1 向量，各策略的群体晶化收益

    num_s = 4;
    U_j = zeros(num_s, 1);

    for j = 1:num_s
        mu_trust_j = params.trust_matrix(j, :) * x;
        mu_delay_j = params.delay_matrix(j, :) * x;
        mu_res_j   = params.res_matrix(j, :) * x;

        mu_vec = [mu_trust_j; mu_delay_j; mu_res_j];
        U_j(j) = theta' * mu_vec;
    end
end
