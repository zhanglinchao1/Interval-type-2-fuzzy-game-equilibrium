% exp_5_1_8_fuzzy_game_sota.m - 论文 §5.1 实验八: Fuzzy / Interval-Game SOTA 对比 (Module A)
%
% 目标 (que.md Module A / stag.md:188-199):
%   在**同一公共两人对称区间收益实例**上, 把本文 Proposed (IT2-W-FBRI on Γ_α) 与三篇
%   可代码化 fuzzy-game SOTA 求解器对比, 用结构性强指标突出本文在 fuzzy systems 轴的贡献:
%     - A1 Dong & Wan 2024 : T2IVIF 矩阵博弈, 目标规划 (SOTA/Dong_Wan_2024)
%     - A3 Kumar & Garg 2025: 两层模糊集 / Yager 两层 LP (SOTA/Kumar_Garg_2025)
%     - A2 Mallozzi & Vidal-Puga 2023: 固定 Hurwicz 态度 fuzzy game (SOTA/Mallozzi_VidalPuga_2023)
%
% 公平性 (que.md §3 固定变量):
%   (F1) 同一核矩阵/θ/δ/凹聚合 → 所有方法消费逐格相同的区间 [U_lo,U_hi] (build_reduced_interval_game)。
%   (F2) 实现收益统一在 δ_realized=0 评估; 尾部/违约用同一扰动协议 (eval_reduced_strategy)。
%   (F3) 同一风险权重不在主表; 尾部统一用 CVaR₅, 与 E[U] 并报。
%   (F4) 一次性法记 R=1; 迭代法同 R_max/eps_tol; runtime 同一 tic/toc 口径。
%   (F5) Proposed 报 α=0.5(鲁棒)与 α=1(≈精确, 诚信并列, 见 α 前沿表); 对手用各自原口径。
%   ex-post violation 用统一 α-FNE 评价函数(同一 α 对所有方法), 见 que.md §4.4。
%
% 输出:
%   table/table5_8_fuzzy_game_sota.csv   - 能力矩阵 + 归约实例数值 合一主表 (tab:fuzzy-sota)
%   table/table5_8c_alpha_frontier.csv   - Proposed α 扫描的 mean-tail 前沿数据(并入 Module B 图)
%
% 注: 按 stag.md, Module A 主文不出单独图(前沿并入 Module B 双面板), 本脚本只产表。

clear; clc; close all;

%% 路径与输出目录
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
addpath(fullfile(script_dir, 'utils', 'sota_adapters'));
addpath(fullfile(script_dir, 'SOTA', 'Dong_Wan_2024'));
addpath(fullfile(script_dir, 'SOTA', 'Kumar_Garg_2025'));
addpath(fullfile(script_dir, 'SOTA', 'Mallozzi_VidalPuga_2023'));
tbl_dir = fullfile(script_dir, 'table');
if ~exist(tbl_dir, 'dir'); mkdir(tbl_dir); end

%% 参数与公共实例
params = config_params();
delta = 0.20;                          % 主报 FOU 半宽(与 Scenario B 一致)
alpha_proposed = 0.5;                  % Proposed 鲁棒工作点 (与 tab:sota-scenb v1 主表一致)
focus_s_proposed = 40;                 % FOU 自适应聚焦指数 (与 tab:sota-scenb v1 主表一致)
lambda_path_proposed = [0.15, 0.002];  % 声明深退火调度 (主文 Remark 3, 与主表一致)
gamma_ce = 0.55;                       % 风险调整权重 (CE_γ, 与 tab:sota-scenb 一致)
alpha_eval = 0.5;                      % 统一 ex-post 违约评价 α(对所有方法一致)
scen = scenario_b_config();            % 风险耦合环境参数(单一来源)
params_B = scenario_b_env(params, scen.fou_scale);   % 中段风险耦合核 + bell FOU + 策略暴露

G = build_reduced_interval_game(params_B, delta);    % SOTA 矩阵博弈统一输入

% n_perturb 取 5000 使 E[U]/CVaR5/violation 的蒙特卡洛估计稳定(仅评估阶段, 不计入 solver 计时)
protocol = struct('sigma_xi', delta * 0.5, 'sigma_small', scen.sigma_small, ...
    'p_shock', scen.p_shock, 'shock_strength', scen.shock_strength, ...
    'n_perturb', 5000, 'seed', params.rng_seed + 8100, 'alpha_eval', alpha_eval);

fprintf('===== 论文 §5.1 实验八: Fuzzy/Interval-Game SOTA 对比 (Module A) =====\n');
fprintf('公共实例: 4×4 区间收益(Scenario-B 风险耦合核), δ=%.2f, exposure=[%s], 凹聚合 g(μ)=2μ-μ²\n', ...
    delta, num2str(G.exposure));
fprintf(['θ=[%.2f %.2f %.2f]; 统一评价 α=%.1f; FOU 噪声 σ_ξ=%.3f; ' ...
    '尾部 σ_small=%.3f, p_shock=%.2f, shock=%.2f\n\n'], ...
    G.theta, alpha_eval, protocol.sigma_xi, protocol.sigma_small, ...
    protocol.p_shock, protocol.shock_strength);

%% 1) 各方法求解 (统一 tic/toc 计时), 产出 4×1 行玩家/agent 混合策略
% 比较口径(必读): Dong-Wan / Kumar-Garg 原方法为两人零和, 会同时给出行/列两套策略
%   (诊断: KG player2 ≈ [0,0,0,1], DW 列 minimax y* ≈ [0,0,0,1])。本模块统一只取各方法
%   导出的"行玩家/agent policy", 部署到同一对称归约实例上比较其 agent 侧表现, 而非比较
%   完整 saddle-point pair 的零和博弈值。该口径在主文 Module A 段落明确说明。
methods = {'Dong-Wan 2024', 'Kumar-Garg 2025', 'Mallozzi-VP 2023', 'Proposed IT2-W-FBRI'};
num_m = numel(methods);
pis = cell(num_m, 1);
runtime = nan(num_m, 1);
rounds = nan(num_m, 1);
ok = true(num_m, 1);

% --- A1 Dong & Wan 2024: T2IVIF 目标规划 (零和 maximin) ---
try
    payoff8 = adapt_to_dong_wan(G.U_lo, G.U_hi);
    dw_opts = struct('gamma', 3, 'delta', 0.5, 'tau', 0.9, 'random_starts', 8, 'display', 'off');
    t0 = tic;
    dw = dong_wan_2024_t2ivif_solver(payoff8, dw_opts);
    runtime(1) = toc(t0);
    pis{1} = normalize_strategy(dw.maximin.strategy);
    rounds(1) = 1;                     % 一次性目标规划
catch err
    ok(1) = false; fprintf('[WARN] Dong-Wan 求解失败: %s\n', err.message);
end

% --- A3 Kumar & Garg 2025: 两层模糊 LP (零和) ---
try
    tfn = adapt_to_kumar_garg(G.U_lo, G.U_hat, G.U_hi);
    t0 = tic;
    kg = kumar_garg_2025_solver('solve_somg', tfn);
    runtime(2) = toc(t0);
    pis{2} = normalize_strategy(kg.player1.strategy);
    rounds(2) = 1;                     % 一次性两层 LP
catch err
    ok(2) = false; fprintf('[WARN] Kumar-Garg 求解失败: %s\n', err.message);
end

% --- A2 Mallozzi & Vidal-Puga 2023: 固定 Hurwicz 态度 + Nash ---
try
    mz = adapt_to_mallozzi(G.U_lo, G.U_hi, 0.5);     % η=0.5 中性固定态度
    t0 = tic;
    [pis{3}, ~] = solve_mallozzi_reduced(mz.M_eta);
    runtime(3) = toc(t0);
    rounds(3) = 1;                     % 固定态度一次性标量化 + 均衡
catch err
    ok(3) = false; fprintf('[WARN] Mallozzi 求解失败: %s\n', err.message);
end

% --- Proposed IT2-W-FBRI (α=0.5, s=40, 声明深退火调度, 与主表 tab:sota-scenb v1 同一工作点) ---
params_prop = params;
params_prop.lambda_path = lambda_path_proposed;
t0 = tic;
[pis{4}, prop_info] = solve_proposed_reduced(G, alpha_proposed, params_prop, focus_s_proposed);
runtime(4) = toc(t0);
rounds(4) = prop_info.iterations;

for i = 1:num_m
    if ok(i)
        fprintf('  %-22s π=[%s]  R=%d  t=%.3fs\n', methods{i}, ...
            num2str(pis{i}', '%.3f '), rounds(i), runtime(i));
    end
end

%% 2) 统一评估
metrics = cell(num_m, 1);
for i = 1:num_m
    if ok(i)
        metrics{i} = eval_reduced_strategy(pis{i}, G, protocol);
    end
end

%% 3) 能力矩阵 (结构性证据, que.md §4.2 / stag.md:193)
% 列: Players | Solver | ConvCert | TunableAlpha | CenterShift | Governance
players      = {'2';            '2';            '2';                 'N (mean-field)'};
solver_type  = {'one-shot GP';  'one-shot LP';  'one-shot Hurwicz';  'iterative learning'};
conv_cert    = {'No';           'No';           'No';                'Yes (q_th<1)'};
tunable_a    = {'No';           'No';           'No (fixed eta)';    'Yes'};
center_shift = {'No';           'No';           'No';                'Yes'};
governance   = {'No';           'No';           'No';                'Yes'};

%% 4) 主表: 能力 + 数值 合一 (tab:fuzzy-sota)
EquilErr = nan(num_m, 1); E_U = nan(num_m, 1); CVaR5 = nan(num_m, 1);
WC_Q5 = nan(num_m, 1); CE_g = nan(num_m, 1); ExPostViol = nan(num_m, 1);
for i = 1:num_m
    if ok(i)
        EquilErr(i)   = metrics{i}.exploitability;
        E_U(i)        = metrics{i}.E_U;
        CVaR5(i)      = metrics{i}.CVaR5;
        WC_Q5(i)      = metrics{i}.Q5;                               % 统一尾部度量 (与 tab:sota-scenb 一致)
        CE_g(i)       = (1 - gamma_ce) * metrics{i}.E_U + gamma_ce * metrics{i}.Q5;  % CE_0.55
        ExPostViol(i) = metrics{i}.violation;
    end
end

T = table(methods(:), players, solver_type, conv_cert, tunable_a, center_shift, ...
    governance, EquilErr, E_U, WC_Q5, CE_g, CVaR5, ExPostViol, runtime, ...
    'VariableNames', {'Method', 'Players', 'Solver', 'ConvCert', 'TunableAlpha', ...
    'CenterShiftCaptured', 'GovernanceCoupling', 'EquilibriumError', 'E_U', ...
    'WC_Q5', 'CE_055', 'CVaR5', 'ExPostViolation', 'Runtime_s'});
csv_path = fullfile(tbl_dir, 'table5_8_fuzzy_game_sota.csv');
writetable(T, csv_path);
fprintf('\n[表] %s\n', fullfile('table', 'table5_8_fuzzy_game_sota.csv'));
disp(T);

%% 5) Proposed α 扫描的 mean-tail 前沿 (诚信并列: α=1≈名义最优; 并入 Module B 图)
alpha_grid = 0.1:0.1:1.0;
na = numel(alpha_grid);
fr_alpha = alpha_grid(:); fr_EU = nan(na, 1); fr_CVaR = nan(na, 1);
fr_viol = nan(na, 1); fr_center = nan(na, 1);
for a = 1:na
    [pa, ~] = solve_proposed_reduced(G, alpha_grid(a), params);
    ma = eval_reduced_strategy(pa, G, protocol);
    fr_EU(a) = ma.E_U; fr_CVaR(a) = ma.CVaR5; fr_viol(a) = ma.violation;
    fr_center(a) = ma.center;
end
Tf = table(fr_alpha, fr_EU, fr_CVaR, fr_viol, fr_center, ...
    'VariableNames', {'alpha', 'E_U', 'CVaR5', 'ExPostViolation', 'Center'});
csv_path_f = fullfile(tbl_dir, 'table5_8c_alpha_frontier.csv');
writetable(Tf, csv_path_f);
fprintf('[表] %s\n', fullfile('table', 'table5_8c_alpha_frontier.csv'));

%% 6) 预期结论自动验证
fprintf('\n===== 预期结论自动验证 =====\n');

% (i) 单一数据来源: U_hat=½(U_lo+U_hi), U_lo≤U_hi
src_ok = max(abs(G.U_hat(:) - (G.U_lo(:) + G.U_hi(:)) / 2)) < 1e-12 && ...
    all(G.U_lo(:) <= G.U_hi(:) + 1e-12);
fprintf('(i) 公共实例单一来源/区间有效 %s\n', local_pass(src_ok));

% (ii) IT2 center-shift: |Û-U_T1| = Σθδ² (取 δ_j=δ 的对角口径作量级参考)
mean_shift = mean(abs(G.U_hat(:) - G.U_T1(:)));
fprintf('(ii) IT2 center-shift 平均量级 |Û-U_T1|=%.4f (>0, Type-1 无法捕捉) %s\n', ...
    mean_shift, local_pass(mean_shift > 1e-6));

% (iii) Proposed ex-post 违约≈0 (统一 α-FNE floor)
prop_viol = metrics{4}.violation;
fprintf('(iii) Proposed ex-post 违约率=%.3f (应≈0) %s\n', ...
    prop_viol, local_pass(prop_viol < 0.02));

% (iv) Proposed exploitability ≤ Corollary 1 认证近似界 λ·ln|S|
cor1_bound = params.lambda * log(params.num_strategies);
fprintf('(iv) Proposed exploitability=%.4f ≤ Cor.1 界 λln|S|=%.4f %s\n', ...
    metrics{4}.exploitability, cor1_bound, ...
    local_pass(metrics{4}.exploitability <= cor1_bound + 1e-9));

% (v) 对手中至少一个 ex-post 违约 > Proposed (结构性鲁棒差异; 对失败 solver 跳过)
comp_viol = nan(1, 3);
for i = 1:3
    if ok(i); comp_viol(i) = metrics{i}.violation; end
end
if any(~isnan(comp_viol))
    fprintf('(v) 对手 ex-post 违约率=[%.3f %.3f %.3f], 最大=%.3f > Proposed %s\n', ...
        comp_viol, max(comp_viol), local_pass(max(comp_viol) > prop_viol + 1e-9));
else
    fprintf('(v) 所有对手求解失败, 跳过 [WARN]\n');
end

% (vi) 诚信并报: 各法 E[U] 与 CVaR5
fprintf('(vi) 诚信并列 E[U] / CVaR5:\n');
for i = 1:num_m
    if ok(i)
        fprintf('     %-22s E[U]=%.4f  CVaR5=%.4f  Equil.err=%.4f\n', ...
            methods{i}, metrics{i}.E_U, metrics{i}.CVaR5, metrics{i}.exploitability);
    end
end

fprintf('\n===== 实验八完成 =====\n');

%% ====== 辅助函数 ======
function [pi_star, info] = solve_proposed_reduced(G, alpha, params, focus_s)
% SOLVE_PROPOSED_REDUCED 归约两人对称实例上的 W-FBRI (论文 §4 α-cut + FOU 自适应聚焦)
%   对群体(对手)混合 q, 本方纯策略 j 的决策值 (公式 (4-13) 推广, focus_s=s):
%       ρq_j = ρ(j,:)·q,  ρ⋆ = max(max_j ρq_j, ρ_floor)
%       ν_j  = (Û(j,:)·q) - (1-α)·ρq_j·(ρq_j/ρ⋆)^s
%   s=0 退化为固定标量 α 线性悲观 (向后兼容); s>0 把悲观预算聚焦到高-FOU 策略。
%   软响应 BR=softmax(ν/λ), 阻尼更新 π=(1-β)π+β·BR, 迭代至残差<eps_tol。
    if nargin < 4 || isempty(focus_s); focus_s = 0; end
    num_s = params.num_strategies;
    beta = params.beta;
    R_max = params.R_max; tol = params.eps_tol;
    if isfield(params, 'lambda_path') && ~isempty(params.lambda_path)
        lambda_path = params.lambda_path(:)';   % 声明退火调度 (主文 Remark 3)
    else
        lambda_path = params.lambda;            % 单段: 与历史版本一致
    end
    rng(params.rng_seed);
    q = ones(num_s, 1) / num_s;
    info.converged = true; info.iterations = 0; info.residual = NaN;
    for stage = 1:numel(lambda_path)
        lambda = lambda_path(stage);
        stage_converged = false;
        for r = 1:R_max
            Uq = G.U_hat * q;                 % 4×1 晶化中心
            rhoq = G.rho * q;                 % 4×1 各纯策略对 q 的期望 FOU 半径
            if focus_s <= 0
                penalty = (1 - alpha) * rhoq;
            else
                rho_floor = 0.01;             % 正下界保证良定义/Lipschitz
                rho_star = max(max(rhoq), rho_floor);
                penalty = (1 - alpha) * rhoq .* (rhoq / rho_star).^focus_s;
            end
            nu = Uq - penalty;                % 4×1 (α,s) 决策值
            br = sec4_3_1_softmax_br(nu, lambda);
            q_new = (1 - beta) * q + beta * br;
            res = sum(abs(q_new - q));
            q = q_new;
            if res <= tol
                stage_converged = true;
                info.iterations = info.iterations + r;
                info.residual = res;
                break;
            end
        end
        if ~stage_converged
            info.iterations = info.iterations + R_max;
        end
        info.converged = info.converged && stage_converged;
    end
    pi_star = q;
end

function [pi_star, info] = solve_mallozzi_reduced(M_eta)
% SOLVE_MALLOZZI_REDUCED 固定 Hurwicz 标量化 crisp 对称博弈的 Nash(演化静息点)
%   复现边界(必读): Mallozzi & Vidal-Puga (2023) 的闭式 dominance/Hurwicz 解针对 2×2;
%   本实例为 4×4, 故此处**基于其已发表的 Hurwicz 标量化思想实现**(implemented from the
%   published Hurwicz scalarization), 而非直接调用原文给出的 4×4 闭式算法: 在 Hurwicz
%   标量化矩阵 M_eta=(1-η)U_lo+η·U_hi 上用复制动态求静息点(对称 Nash)。该实现细节在
%   主文 Module A 段落如实标注, 以界定复现范围。
    num_s = size(M_eta, 1);
    q = ones(num_s, 1) / num_s;
    step = 0.1; max_it = 50000; tol = 1e-12;
    info.converged = false; info.iterations = max_it;
    for r = 1:max_it
        f = M_eta * q;
        q_new = q .* exp(step * (f - q' * f));
        q_new = q_new / sum(q_new);
        res = sum(abs(q_new - q));
        q = q_new;
        if res <= tol
            info.converged = true; info.iterations = r; break;
        end
    end
    pi_star = q;
end

function p = normalize_strategy(x)
% NORMALIZE_STRATEGY 将外部 solver 返回的策略整理为非负归一化 4×1 列向量
    p = max(0, x(:));
    s = sum(p);
    if s <= 0
        p = ones(numel(p), 1) / numel(p);
    else
        p = p / s;
    end
end

function s = local_pass(ok)
    if ok; s = '[PASS]'; else; s = '[WARN]'; end
end
