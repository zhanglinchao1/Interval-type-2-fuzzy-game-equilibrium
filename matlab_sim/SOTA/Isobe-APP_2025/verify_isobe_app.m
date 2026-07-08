% verify_isobe_app.m  —  Isobe-APP'25 复现自检 (与 solve_isobe_app 同处论文文件夹)
%
% 校验目标 (Karpathy 准则 §4 目标驱动):
%   1. solve_isobe_app 在 benign 核 (δ=0,α=1) 收敛 (converged=true), R 与现代收敛
%      SOTA (OGDA/OMWU) 同量级。
%   2. 输出为合法策略剖面 (每行单纯形, 行和=1, 非负)。
%   3. last-iterate 性质: 外层 anchor 残差 ≤ eps_tol；内层残差仅作轨迹诊断。
%   4. 收敛到与 OGDA/OMWU 一致的名义均衡 (FOU-agnostic 同一名义博弈), 偏差小。
%   5. λη<1 守卫: 给非法 (η,λ) 抛错。
%   6. (附) 在风险耦合 Scenario B 决策面也能稳定收敛 (鲁棒赛道路由不崩)。

clearvars; clc;
script_dir = fileparts(mfilename('fullpath'));      % SOTA/Isobe-APP_2025
addpath(script_dir);                                 % 本文件夹: solve_isobe_app
addpath(fullfile(script_dir, '..', '..', 'utils'));  % 共享博弈模型 helper + config_params

params = config_params();
params.fou_modulation = true;
params.R_max = 300;
params.eps_tol = 1e-4;
params.N = 50;
params.rng_seed = 42;
theta = params.theta;

fprintf('===== Isobe-APP 复现自检 (N=%d, seed=%d) =====\n', params.N, params.rng_seed);

%% 1-4. benign 核, FOU-agnostic (δ=0, α=1) —— 与 OGDA/OMWU 同口径
delta_agn = 0; alpha_agn = 1.0;
[pi_iso, h_iso] = solve_isobe_app(params, delta_agn, theta, alpha_agn);
[pi_ogda, h_ogda] = solve_ogda(params, delta_agn, theta, alpha_agn);
[pi_omwu, h_omwu] = solve_omwu(params, delta_agn, theta, alpha_agn);

dist_iso  = mean(pi_iso, 1);
dist_ogda = mean(pi_ogda, 1);
dist_omwu = mean(pi_omwu, 1);

fprintf('\n[1] 收敛性 (benign, δ=0, α=1):\n');
fprintf('    Isobe-APP : converged=%d, R=%d, 外层残差=%.3e\n', ...
    h_iso.converged, h_iso.iterations, h_iso.final_native_residual);
fprintf('    OGDA      : converged=%d, R=%d\n', h_ogda.converged, h_ogda.iterations);
fprintf('    OMWU      : converged=%d, R=%d\n', h_omwu.converged, h_omwu.iterations);

fprintf('\n[2] 合法策略剖面: 行和 max|Σ-1|=%.2e, min 元素=%.3e (应≥0)\n', ...
    max(abs(sum(pi_iso, 2) - 1)), min(pi_iso(:)));

fprintf('\n[3] last-iterate (外层 anchor 判据；内层轨迹不要求单调):\n');
res = h_iso.residual;
n_increase = sum(diff(res) > 1e-12);
fprintf(['    内层序列长度=%d, 上升步数=%d/%d; 外层末值=%.3e ' ...
    '≤ eps_tol(%.1e)? %d\n'], numel(res), n_increase, numel(res) - 1, ...
    h_iso.final_native_residual, params.eps_tol, ...
    h_iso.final_native_residual <= params.eps_tol);

fprintf('\n[4] 名义均衡一致性 (各方法终点策略分布 [SC SP DC DP]):\n');
fprintf('    Isobe-APP : [%.4f %.4f %.4f %.4f]\n', dist_iso);
fprintf('    OGDA      : [%.4f %.4f %.4f %.4f]\n', dist_ogda);
fprintf('    OMWU      : [%.4f %.4f %.4f %.4f]\n', dist_omwu);
fprintf('    ||Isobe-OGDA||_1=%.4f, ||Isobe-OMWU||_1=%.4f\n', ...
    sum(abs(dist_iso - dist_ogda)), sum(abs(dist_iso - dist_omwu)));

% 名义晶化平均收益 (终点)
[~, ~, U_hat_iso] = sec4_1_2_mixed_payoff( ...
    pi_iso, 0, theta, params);
fprintf('    Isobe-APP 终点名义平均收益 Û=%.4f\n', mean(U_hat_iso));

%% 5. λη<1 守卫
fprintf('\n[5] λη<1 守卫测试 (η=20, λ=0.1 → λη=2.0, 应抛错):\n');
bad = params; bad.isobe_eta = 20; bad.isobe_lambda = 0.1;
try
    solve_isobe_app(bad, delta_agn, theta, alpha_agn);
    fprintf('    [FAIL] 未抛错\n');
catch ME
    fprintf('    [PASS] 已捕获: %s\n', ME.message);
end

%% 6. 风险耦合 Scenario B 决策面收敛 (鲁棒路由不崩)
fprintf('\n[6] Scenario B 决策面 (δ=0.20, α=0.5) 稳定性:\n');
[pi_b, h_b] = solve_isobe_app(params, 0.20, theta, 0.5);
fprintf('    converged=%d, R=%d, 外层残差=%.3e, 终点分布=[%.4f %.4f %.4f %.4f]\n', ...
    h_b.converged, h_b.iterations, h_b.final_native_residual, mean(pi_b, 1));

%% 7. 论文核心论点复现: 完整 Isobe-APP (外层 PP) 收敛顶点 vs 单纯 RMD 偏内部
%    论文 §5: RMD (锚点不更新) 收敛到单纯形内部 (错误); 加外层 PP 自适应扰动后
%    收敛到顶点 (正确)。用超大 τ (锚点在 R_max 内不更新) 模拟"单纯 RMD"。
fprintf('\n[7] 论文核心论点 (PP 外层使收敛到正确顶点, 单纯 RMD 偏内部):\n');
rmd_only = params; rmd_only.isobe_T = params.R_max + 10;   % 锚点永不更新 = 纯 RMD
[pi_rmd, h_rmd] = solve_isobe_app(rmd_only, delta_agn, theta, alpha_agn);
fprintf('    纯 RMD (锚点不更新): 终点=[%.4f %.4f %.4f %.4f], R=%d (应偏内部)\n', ...
    mean(pi_rmd, 1), h_rmd.iterations);
fprintf('    完整 Isobe-APP    : 终点=[%.4f %.4f %.4f %.4f], R=%d (应近顶点 SC)\n', ...
    dist_iso, h_iso.iterations);

%% 8. 跨 seed / N 鲁棒性 (默认操作点是否稳定收敛到同一顶点)
fprintf('\n[8] 跨 seed/N 鲁棒性 (benign, δ=0, α=1):\n');
fprintf('    N    seed | R    SC      conv\n');
for Ntest = [20 50 100]
    for stest = [42 44 46]
        q = params; q.N = Ntest; q.rng_seed = stest;
        [pq, hq] = solve_isobe_app(q, delta_agn, theta, alpha_agn);
        dq = mean(pq, 1);
        fprintf('    %-4d %-4d | %-4d %.4f  %d\n', Ntest, stest, ...
            hq.iterations, dq(1), hq.converged);
    end
end

fprintf('\n===== 自检完成 =====\n');
