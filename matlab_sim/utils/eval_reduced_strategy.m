function m = eval_reduced_strategy(pi, G, protocol)
%EVAL_REDUCED_STRATEGY Module A 统一评估函数: 同一实例/同一协议下计算各方法策略的全部指标
%
%   用途 (que.md §3 F2/F3 + §4.4 公平违约口径 + §A4 单一评估口径):
%       把任意方法产出的 4×1 混合策略 π 放入**同一公共实例 G** 与**同一扰动协议**下评估,
%       杜绝各算各的口径漂移。所有实现收益在点隶属度 δ_realized=0 评估(FOU 只进决策不进
%       实现收益, 与 scenario_b_payoff_stats 完全一致); 自博弈收益取 π'·R·π (多重线性混合
%       扩展, R 为名义收益矩阵 G.U_T1)。
%
%   指标定义:
%       E[U]           - 风险耦合扰动下实现收益均值(效率指标, 诚信并报)。
%       Equilibrium err- **单种群(行玩家/agent)单边偏离** exploitability:
%                        max_j(R·π)_j − π'·R·π。说明: 本模块把各方法导出的行玩家/agent
%                        policy 部署到同一对称归约实例上评估, 这是 symmetric population-game
%                        口径; 它**不是**两人零和的 saddle-point 值比较(Dong-Wan/Kumar-Garg
%                        原方法会另给列策略, 此处不纳入)。该口径在主文 Module A 段落说明。
%       Violation      - **仅 FOU 尺度噪声**下 realized < floor 的比例;
%                        floor=ν_α(π)=center−(1−α)radius, α 对所有方法一致。
%                        注(辅证, 非主指标): 此处 σ_ξ=δ/2 为高斯(无界)噪声, 是经验性
%                        stress test, 少量样本会越过 Lemma 1 的有界 FOU 预算覆盖范围,
%                        故 0 vs 0.002 量级差异仅作一致性辅证, 主优势见 CVaR5 与能力证书。
%       CVaR5          - **风险耦合扰动**(benign 高斯 + 偶发 SC 定向冲击 apply_sc_shock)下
%                        实现收益的下尾 CVaR(5%); 与 scenario_b_payoff_stats 同口径。
%       Q5             - 同上扰动下的 5% 分位(与既有图表兼容)。
%       MeanRealized   - 风险耦合扰动下实现收益均值(=E_U)。
%
%   口径说明 (que.md §4.4): violation 与 tail 用**不同**扰动集——
%       violation 只用 FOU 尺度的 kernel 噪声(经验逼近 Lemma 1 先验预算覆盖范围);
%       SC 定向冲击是超出 FOU 模型的系统性尾部事件, 仅计入 CVaR5/Q5, 不混入 budget 违约判据。
%
%   输入:
%       pi       - 4×1(或行) 混合策略
%       G        - build_reduced_interval_game 产出的公共实例
%       protocol - 结构体, 扰动与评价协议, 字段:
%                  .sigma_xi(FOU 噪声std, 违约用) .sigma_small(benign 高斯std, 尾部用)
%                  .p_shock(冲击概率) .shock_strength(SC 定向冲击强度)
%                  .n_perturb(扰动次数) .seed(随机种子) .alpha_eval(统一评价 α)
%   输出:
%       m - 结构体, 字段: E_U, exploitability, CVaR5, Q5, violation, mean_realized,
%           floor, budget, center, radius

    p = pi(:);
    R = G.U_T1;                                   % 名义实现收益矩阵(δ=0, 多重线性)

    % --- 单种群(行玩家/agent)单边偏离 exploitability(确定性) ---
    nominal_value = p' * R * p;
    dev_gain = R * p;                             % 各纯策略对 π 的单边偏离收益(行玩家口径)
    m.exploitability = max(dev_gain) - nominal_value;

    % --- 统一 α-cut 鲁棒 floor(同一评价 α 适用于所有方法) ---
    [m.floor, m.budget, m.center, m.radius] = ...
        reduced_robust_budget(G, p, protocol.alpha_eval);

    % --- (1) ex-post violation: 仅 FOU 噪声(Lemma 1 预算覆盖范围, 无系统性冲击) ---
    realized_fou = local_perturbed_payoffs(p, G, protocol.sigma_xi, ...
        protocol.n_perturb, protocol.seed, 0, 0);
    m.violation = mean(realized_fou < m.floor);

    % --- (2) 尾部风险: benign 高斯 + 偶发 SC 定向冲击(与 scenario_b_payoff_stats 一致) ---
    realized_risk = local_perturbed_payoffs(p, G, protocol.sigma_small, ...
        protocol.n_perturb, protocol.seed + 777, protocol.p_shock, ...
        protocol.shock_strength);
    m.E_U           = mean(realized_risk);
    m.mean_realized = m.E_U;
    m.CVaR5         = cvar5(realized_risk, 0.05);
    m.Q5            = quantile(realized_risk, 0.05);
end

function vals = local_perturbed_payoffs(p, G, sigma, n, seed, p_shock, shock_strength)
%LOCAL_PERTURBED_PAYOFFS 在 kernel 噪声(±可选 SC 定向冲击)下重算自博弈实现收益序列
%   每次 draw: 对三类状态核加 N(0,σ) 噪声并截断[0,1]; 若触发冲击则按 apply_sc_shock
%   惩罚 SC 行(自身激进共享)与 SC 列(对手激进共享)。凹聚合重算名义收益矩阵后取 p'·R'·p。
    theta = G.theta(:);
    vals = zeros(n, 1);
    rng(seed);
    for t = 1:n
        Mp = G.M;
        for k = 1:3
            Mp{k} = min(1, max(0, G.M{k} + sigma * randn(size(G.M{k}))));
        end
        if p_shock > 0 && rand < p_shock
            for k = 1:3
                Mp{k} = apply_sc_shock(Mp{k}, shock_strength);
            end
        end
        Rp = zeros(size(G.U_T1));
        for k = 1:3
            Rp = Rp + theta(k) * (2 * Mp{k} - Mp{k}.^2);
        end
        vals(t) = p' * Rp * p;
    end
end

function Mk = apply_sc_shock(Mk, shock_strength)
%APPLY_SC_SHOCK 对 SC 相关交互施加偶发逆向冲击(与 scenario_b_payoff_stats 同口径)
%   SC 作为本方策略(第 1 行)受全额冲击, 作为对手策略(第 1 列)受半额冲击。
    Mk(1, :) = Mk(1, :) - shock_strength;
    Mk(:, 1) = Mk(:, 1) - 0.5 * shock_strength;
    Mk = min(1, max(0, Mk));
end
