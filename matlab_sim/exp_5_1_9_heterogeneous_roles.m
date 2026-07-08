%% exp_5_1_9_heterogeneous_roles.m
% 异构角色变体 (审稿意见 MC4): 行使论文 §3.1 的 V/R/E 角色划分与受限
% 策略集 S_i ⊆ S, 在认证域内 (alpha=0.5, s=0, lambda=0.15 单温) 验证:
%   (1) W-FBRI 在受限单纯形积上收敛, q_hat < q_th (定理 1 证书不变,
%       因为可行子集上的跨策略 variation 不超过全集模量);
%   (2) 多种群复制动态 (Prop 3) 在受限单纯形积上收敛到局部稳定静止点,
%       以乘积切空间最大对称特征值 / 顶点入侵边距判定分支;
%   (3) 掩码外坐标严格为零, 事后 exploitability 证书有限。
% 输出: table/table5_9_heterogeneous_roles.csv

clear; clc;
addpath(genpath(fileparts(mfilename('fullpath'))));

params = config_params();
params.N = 50;
params.rng_seed = 42;
delta = params.delta;          % 0.10
theta = params.theta;          % (0.40, 0.35, 0.25)
alpha = 0.5;
focus_s = 0;

% 角色划分: 30 车辆 (全集), 12 RSU (数据共享义务 {SC,SP}),
% 8 边缘服务器 (资源开放义务 {SC,DC})。策略序 (SC,SP,DC,DP)。
idx_V = 1:30;  feas_V = [1 2 3 4];
idx_R = 31:42; feas_R = [1 2];
idx_E = 43:50; feas_E = [1 3];
mask = false(params.N, params.num_strategies);
mask(idx_V, feas_V) = true;
mask(idx_R, feas_R) = true;
mask(idx_E, feas_E) = true;

D_nu = 0.218;
q_th = (1 - params.beta) + params.beta * D_nu / (2 * params.lambda);

%% ---- W-FBRI: 同质参照 vs 异构受限 ----
[pi_hom, hist_hom] = sec4_3_1_wfbri_solve(params, delta, theta, ...
    alpha, focus_s);
params_het = params;
params_het.feasible_mask = mask;
[pi_het, hist_het] = sec4_3_1_wfbri_solve(params_het, delta, theta, ...
    alpha, focus_s);

q_hat_hom = estimate_q_hat_local(hist_hom.residual);
q_hat_het = estimate_q_hat_local(hist_het.residual);

x_V = mean(pi_het(idx_V, :), 1);
x_R = mean(pi_het(idx_R, :), 1);
x_E = mean(pi_het(idx_E, :), 1);

fprintf('\n===== W-FBRI heterogeneous-role variant =====\n');
fprintf('Hom : R=%d q_hat=%.4f eps_NE=%.4f\n', ...
    hist_hom.iterations, q_hat_hom, hist_hom.eps_ne);
fprintf('Het : R=%d q_hat=%.4f eps_NE=%.4f (q_th=%.3f)\n', ...
    hist_het.iterations, q_hat_het, hist_het.eps_ne, q_th);
fprintf('x_V = [%.4f %.4f %.4f %.4f]\n', x_V);
fprintf('x_R = [%.4f %.4f %.4f %.4f]\n', x_R);
fprintf('x_E = [%.4f %.4f %.4f %.4f]\n', x_E);

%% ---- 多种群复制动态 (Prop 3, 受限单纯形积) ----
w_tau = [numel(idx_V), numel(idx_R), numel(idx_E)] / params.N;
feas = {feas_V, feas_R, feas_E};
type_idx = {idx_V, idx_R, idx_E};

% 初始状态: 各类型可行集上均匀
x_types = cell(1, 3);
for t = 1:3
    x0 = zeros(1, params.num_strategies);
    x0(feas{t}) = 1 / numel(feas{t});
    x_types{t} = x0;
end

T_evo = 8000;                  % 顶点收敛时间常数 ~1/|d_k| ≈ 30 → t=400 足够
dt = params.dt_evo;
traj = zeros(T_evo, 3 * params.num_strategies);
for step = 1:T_evo
    U = type_payoffs(x_types, type_idx, delta, theta, alpha, params);
    for t = 1:3
        x = x_types{t};
        Ut = U(t, :);
        Ubar = sum(x .* Ut);
        xdot = x .* (Ut - Ubar);          % 不可行坐标 x=0 → xdot=0
        x = x + dt * xdot;
        x = max(x, 0);
        x = x / sum(x);
        x_types{t} = x;
    end
    traj(step, :) = [x_types{1}, x_types{2}, x_types{3}];
end

T_w = 400;
osc = max(max(traj(end-T_w+1:end, :), [], 1) ...
    - min(traj(end-T_w+1:end, :), [], 1));

% 稳定性判定: 各类型可行支撑为内部 → 乘积切空间特征值;
% 顶点/边界 → Prop 3(b) 入侵边距 d_k = U_k - U_{j*} (可行 k)。
U_term = type_payoffs(x_types, type_idx, delta, theta, alpha, params);
interior = true;
max_margin = -inf;
for t = 1:3
    xf = x_types{t}(feas{t});
    if min(xf) < 1e-3
        interior = false;
    end
    [~, j_best] = max(x_types{t});
    d_k = U_term(t, feas{t}) - U_term(t, j_best);
    d_k(feas{t} == j_best) = [];
    if ~isempty(d_k)
        max_margin = max(max_margin, max(d_k));
    end
end
lambda_max_T = product_tangent_lambda_max(x_types, type_idx, feas, ...
    delta, theta, alpha, params);

fprintf('\n===== Multi-population replicator =====\n');
fprintf('terminal x_V=[%.4f %.4f %.4f %.4f]  x_R=[%.4f %.4f]  x_E=[%.4f %.4f]\n', ...
    x_types{1}, x_types{2}(feas_R), x_types{3}(feas_E));
fprintf('Osc(T_w)=%.2e  interior=%d  lambda_max_T=%.4f  max_margin=%.4f\n', ...
    osc, interior, lambda_max_T, max_margin);

%% ---- 导出 ----
tbl_dir = fullfile(fileparts(mfilename('fullpath')), 'table');
rows = {
 'Homogeneous', hist_hom.iterations, q_hat_hom, q_th, ...
    hist_hom.converged, hist_hom.eps_ne, ...
    mean(pi_hom(:,1)), mean(pi_hom(:,2)), mean(pi_hom(:,3)), ...
    mean(pi_hom(:,4)), NaN, NaN, NaN, NaN, NaN, NaN, NaN;
 'Heterogeneous', hist_het.iterations, q_hat_het, q_th, ...
    hist_het.converged, hist_het.eps_ne, ...
    x_V(1), x_V(2), x_V(3), x_V(4), x_R(1), x_R(2), x_E(1), x_E(3), ...
    lambda_max_T, max_margin, osc};
T = cell2table(rows, 'VariableNames', ...
    {'Variant','Rounds','qHat','qTh','Converged','EpsNE', ...
     'xV_SC','xV_SP','xV_DC','xV_DP','xR_SC','xR_SP','xE_SC','xE_DC', ...
     'RepLambdaMaxT','RepMaxMargin','RepOsc'});
writetable(T, fullfile(tbl_dir, 'table5_9_heterogeneous_roles.csv'));
fprintf('\n[TABLE] table/table5_9_heterogeneous_roles.csv\n');

%% ---- 预期结论自动验证 ----
fprintf('\n===== Checks =====\n');
check('Het W-FBRI converged', hist_het.converged);
check('q_hat_het < q_th', q_hat_het < q_th);
check('masked entries exactly zero', ...
    all(pi_het(~mask) == 0));
check('eps_NE within entropy bound lambda*ln4', ...
    hist_het.eps_ne <= params.lambda * log(4));
check('replicator stationary (Osc < 1e-4)', osc < 1e-4);
if interior
    check('Prop 3(a): lambda_max_T < 0', lambda_max_T < 0);
else
    check('Prop 3(b): all invasion margins < 0', max_margin < 0);
end

%% ---- 局部函数 ----
function U = type_payoffs(x_types, type_idx, delta, theta, alpha, params)
% 各类型代表 agent 的 Gamma_alpha 纯策略决策收益 (平均场, s=0)。
    P = zeros(params.N, params.num_strategies);
    for t = 1:3
        P(type_idx{t}, :) = repmat(x_types{t}, numel(type_idx{t}), 1);
    end
    [~, ~, pure_hat, pure_rho] = sec4_1_2_pure_interval_payoff_matrix( ...
        P, delta, theta, params);
    nu = pure_hat - (1 - alpha) * pure_rho;
    U = zeros(3, params.num_strategies);
    for t = 1:3
        U(t, :) = nu(type_idx{t}(1), :);
    end
end

function lam = product_tangent_lambda_max(x_types, type_idx, feas, ...
    delta, theta, alpha, params)
% 复制动态在乘积可行单纯形切空间上的最大对称特征值 (中心差分)。
    dims = cellfun(@numel, feas);
    z0 = [x_types{1}(feas{1}), x_types{2}(feas{2}), x_types{3}(feas{3})]';
    n = numel(z0);
    h = 1e-6;
    J = zeros(n);
    for k = 1:n
        zp = z0; zp(k) = zp(k) + h;
        zm = z0; zm(k) = zm(k) - h;
        J(:, k) = (rep_rhs(zp) - rep_rhs(zm)) / (2 * h);
    end
    J_sym = (J + J') / 2;
    B = blkdiag(null(ones(1, dims(1))), null(ones(1, dims(2))), ...
        null(ones(1, dims(3))));
    lam = max(eig(B' * J_sym * B));

    function f = rep_rhs(z)
        xt = cell(1, 3);
        pos = 0;
        for t = 1:3
            x_full = zeros(1, params.num_strategies);
            x_full(feas{t}) = z(pos+1:pos+dims(t));
            xt{t} = x_full;
            pos = pos + dims(t);
        end
        Uz = type_payoffs(xt, type_idx, delta, theta, alpha, params);
        f = zeros(n, 1);
        pos = 0;
        for t = 1:3
            xf = z(pos+1:pos+dims(t))';
            Uf = Uz(t, feas{t});
            f(pos+1:pos+dims(t)) = (xf .* (Uf - sum(xf .* Uf)))';
            pos = pos + dims(t);
        end
    end
end

function q = estimate_q_hat_local(residual)
    R = numel(residual);
    if R < 2 || residual(1) <= 0
        q = NaN;
    else
        q = (residual(end) / residual(1))^(1 / (R - 1));
    end
end

function check(label, ok)
    if ok
        fprintf('[PASS] %s\n', label);
    else
        fprintf('[WARN] %s\n', label);
    end
end
