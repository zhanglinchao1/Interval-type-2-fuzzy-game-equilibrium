% design_interior_ess.m - 大修设计脚本（不进论文管线）
%
% 目标 (que.md M5/M6):
%   设计带"拥塞结构"的三类隶属度生成矩阵 M_trust/M_delay/M_res，使得
%   (1) 多种群复制动态 (V: 4策略, R:{SC,SP}, E:{SC,DC}) 在治理可达的 θ 范围内
%       存在内点均衡 x*，且 SC 份额最大（合作主导 → 修复叙事）；
%   (2) ν^α 收益场 A^α(θ) 的对称部分在切空间负定 → λ_max^T < 0（定理3条件）；
%   (3) 元素 ∈ [0.02, 0.98]，叙事可解释：
%       trust  : 共享行为提升信任（share 单调）
%       delay  : C-C 同时开放资源 → 信道竞争；同策略拥挤 −η（调度碰撞）
%       res    : 他人开放资源提升可行性，但同时开放产生争用
%   (4) 治理把 θ_trust 提高时 x*_SC 上升（治理维持合作的叙事验证）。
%
% 构造法:
%   A^0_k = 拥塞/结构项（rank-1 share/open 外积 + 对角拥挤）
%   行偏置 u_k(j) 由"目标内点 x_tgt 处各策略 ν^α 无差异"反解。
%
% 输出: 打印三个矩阵（写入 config_params.m 用）+ 验证报告

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));

% ---- 策略特征向量 ----
share = [1 1 0 0]';   % SC SP DC DP: 是否共享信息
open_ = [1 0 1 0]';   % 是否开放资源

% ---- 悲观标度 h^alpha (与论文 Γ_α 一致, 默认 α=0.5, δ̄=0.10) ----
alpha   = 0.5;
delta_b = 0.10;
c_pess  = 4 * delta_b * (1 - alpha);          % = 0.2
h_pess  = @(mu) mu - c_pess * mu .* (1 - mu); % ν^α 的单调标度
% h'(mu) = 1 - c(1-2mu) ∈ [0.8, 1.2] —— 单调，保序

% ---- 目标内点 (V 种群) ----
x_tgt = [0.42; 0.26; 0.18; 0.14];

% ---- θ 参考值与可达范围 ----
theta_ref  = [0.40; 0.35; 0.25];

% ---- 结构项设计 ----
% trust: 共享互惠 + 同策略轻微拥挤
eta_t = 0.12;  g_t_ss = +0.08;   % share×share 互惠（正，叙事）
% delay: C-C 信道竞争 + 同策略拥挤（核心负定来源）
eta_d = 0.22;  g_d_oo = -0.18;  g_d_ss = -0.08;
% res: 他人开放提升可行性(列效应) + 开放争用 + 同策略拥挤
eta_r = 0.18;  g_r_oo = -0.15;
% 种群内同策略拥挤 (多种群稳定性来源; 叙事: 同类智能体争用同一信道/服务)
kappa_pop = 0.08;

S0_t = g_t_ss * (share*share') - eta_t * eye(4);
S0_d = g_d_oo * (open_*open_') + g_d_ss * (share*share') - eta_d * eye(4);
S0_r = g_r_oo * (open_*open_') - eta_r * eye(4);

% 列效应（他人行为对自己状态的外部性，行常数 → 不影响切空间负定）
colfx_t = 0.26 * share';            % 邻居共享 → 我方信任评估高
colfx_d = 0.10 * share';            % 邻居共享信息 → 链路可预测性略升
colfx_r = 0.30 * open_';            % 邻居开放资源 → 我方资源可行性升

% 行偏置基线（再由无差异条件微调）
base_t = 0.40;  base_d = 0.62;  base_r = 0.45;

M_t0 = base_t + repmat(colfx_t, 4, 1) + S0_t;
M_d0 = base_d + repmat(colfx_d, 4, 1) + S0_d;
M_r0 = base_r + repmat(colfx_r, 4, 1) + S0_r;

% ---- 行偏置反解：在 x_tgt 处 ν^α 各策略无差异 ----
% ν^α_j = Σ_k θ_k h(μ_kj),  μ_kj = M_k(j,:) x.
% 给 trust 矩阵行加 u(j)（share 维度的策略内在收益），解 ν^α_j 全相等。
% 用数值最小二乘：变量 u ∈ R^4（加在 M_t 行上，含义=策略 j 的链上信誉回报）
nu_fun = @(Mt, Md, Mr, x, th) th(1)*h_pess(Mt*x) + th(2)*h_pess(Md*x) + th(3)*h_pess(Mr*x);
% 单种群完整收益（含种群内拥挤）
nu_sp  = @(Mt, Md, Mr, x, th, kp) nu_fun(Mt, Md, Mr, x, th) - kp*x;

% 解析反解: (M_t0 + u·1')x = M_t0·x + u (因 1'x=1)，故 μ_t,j → μ_t,j + u_j
% 要求 θ1·h(μ_t,j + u_j) + θ2·h(μ_d,j) + θ3·h(μ_r,j) = c (公共值)
% h(m) = (1-cp)m + cp·m² 单调可逆 (m∈[0,1], cp=0.2)，解二次方程取正根
% 收益统一含种群内拥挤项: ν_j = Σθ_k h(μ_kj) - κ_pop·x_j
mu_t0 = M_t0 * x_tgt;  mu_d0 = M_d0 * x_tgt;  mu_r0 = M_r0 * x_tgt;
rest  = theta_ref(2)*h_pess(mu_d0) + theta_ref(3)*h_pess(mu_r0) - kappa_pop*x_tgt;
nu0   = theta_ref(1)*h_pess(mu_t0) + rest;
c_tgt = mean(nu0);                              % 公共无差异值取均值
h_inv = @(y) (-(1-c_pess) + sqrt((1-c_pess)^2 + 4*c_pess*y)) / (2*c_pess);
u_sol = h_inv((c_tgt - rest)/theta_ref(1)) - mu_t0;

M_t = M_t0 + repmat(u_sol, 1, 4);
M_d = M_d0;  M_r = M_r0;

% 裁剪检查
clip_warn = any([M_t(:); M_d(:); M_r(:)] < 0.02) || any([M_t(:); M_d(:); M_r(:)] > 0.98);

fprintf('=== 行偏置 u (加在 trust 行) ===\n'); disp(u_sol');
fprintf('=== M_trust ===\n'); disp(round(M_t,3));
fprintf('=== M_delay ===\n'); disp(round(M_d,3));
fprintf('=== M_res ===\n');   disp(round(M_r,3));
fprintf('元素范围: [%.3f, %.3f]  越界=%d\n', ...
    min([M_t(:);M_d(:);M_r(:)]), max([M_t(:);M_d(:);M_r(:)]), clip_warn);

% ---- 验证 1: 单种群复制动态内点稳定 (θ_ref) ----
x = x_tgt + 0.05*[1;-1;0.5;-0.5]/4;  x = x/sum(x);
dt = 0.05;
for t = 1:40000
    nu = nu_sp(M_t, M_d, M_r, x, theta_ref, kappa_pop);
    x  = x + dt * x .* (nu - x'*nu);
    x  = max(x,1e-12); x = x/sum(x);
end
fprintf('\n[验证1] 单种群终态 x* = [%s]  (目标 [%s])\n', ...
    num2str(x',' %.3f'), num2str(x_tgt',' %.3f'));

% 切空间最大对称特征值（数值 Jacobian）
rhs1 = @(z) z.*(nu_sp(M_t,M_d,M_r,z,theta_ref,kappa_pop) - z'*nu_sp(M_t,M_d,M_r,z,theta_ref,kappa_pop));
lam = jac_lambda_max(rhs1, x);
fprintf('[验证1] λ_max^T(θ_ref) = %.4f  (要求 < 0)\n', lam);

% ---- 验证 2: θ 扫描（治理可达范围）----
fprintf('\n[验证2] θ 网格扫描 内点性 + λ_max^T:\n');
bad = 0;
for tt = 0.25:0.05:0.55
    for dd = 0.20:0.05:0.45
        rr = 1 - tt - dd;
        if rr < 0.10 || rr > 0.45, continue; end
        th = [tt; dd; rr];
        xs = solve_interior(@(z)nu_sp(M_t,M_d,M_r,z,th,kappa_pop), x_tgt);
        rhs_th = @(z) z.*(nu_sp(M_t,M_d,M_r,z,th,kappa_pop) - z'*nu_sp(M_t,M_d,M_r,z,th,kappa_pop));
        lam_th = jac_lambda_max(rhs_th, xs);
        interior = all(xs > 0.02);
        if ~interior || lam_th >= 0, bad = bad + 1; end
        if mod(round(tt*100),10)==0 && mod(round(dd*100),10)==0
            fprintf('  θ=[%.2f %.2f %.2f]: x*=[%s] λ=%.3f %s\n', tt, dd, rr, ...
                num2str(xs',' %.2f'), lam_th, ternary(interior&&lam_th<0,'OK','BAD'));
        end
    end
end
fprintf('[验证2] 失败网格点数 = %d\n', bad);

% ---- 验证 3: 治理→合作单调性 (θ_trust ↑ ⇒ x*_SC ↑) ----
fprintf('\n[验证3] θ_trust 从 0.30→0.55 时 x*_SC:\n');
for tt = [0.30 0.40 0.50 0.55]
    th = [tt; 0.30; 0.70-tt+0.0];  th = th/sum(th);  % delay 固定 0.30 归一
    xs = solve_interior(@(z)nu_sp(M_t,M_d,M_r,z,th,kappa_pop), x_tgt);
    fprintf('  θ_trust=%.2f: x*_SC=%.3f  x*=[%s]\n', th(1), xs(1), num2str(xs',' %.2f'));
end

% ---- 验证 4: 多种群 (V 0.8 / R 0.1 / E 0.1) ----
% R: {SC,SP} (必须共享, 选择是否开放), E: {SC,DC} (必须开放, 选择是否共享)
wV=0.8; wR=0.1; wE=0.1;
xV = x_tgt; xR = [0.5;0.5]; xE = [0.5;0.5];
LR = [1 0; 0 1; 0 0; 0 0];   % R 策略嵌入: SC,SP
LE = [1 0; 0 0; 0 1; 0 0];   % E 策略嵌入: SC,DC
for t = 1:60000
    xt = wV*xV + wR*(LR*xR) + wE*(LE*xE);
    nu = nu_fun(M_t, M_d, M_r, xt, theta_ref);
    nuV = nu - kappa_pop*xV;
    xV = xV + dt*xV.*(nuV - xV'*nuV);           xV=max(xV,1e-12); xV=xV/sum(xV);
    nuR = [nu(1); nu(2)] - kappa_pop*xR;
    xR = xR + dt*xR.*(nuR - xR'*nuR);           xR=max(xR,1e-12); xR=xR/sum(xR);
    nuE = [nu(1); nu(3)] - kappa_pop*xE;
    xE = xE + dt*xE.*(nuE - xE'*nuE);           xE=max(xE,1e-12); xE=xE/sum(xE);
end
fprintf('\n[验证4] 多种群终态 (κ_pop=%.2f):\n  xV=[%s]\n  xR=[%s]  xE=[%s]\n', ...
    kappa_pop, num2str(xV',' %.3f'), num2str(xR',' %.3f'), num2str(xE',' %.3f'));

% 多种群切空间 λ_max（在乘积切空间上）
zfull = [xV; xR; xE];
lamM = multi_lambda_max(zfull, M_t, M_d, M_r, theta_ref, nu_fun, wV, wR, wE, LR, LE, kappa_pop);
fprintf('[验证4] 多种群 λ_max^T = %.4f (要求 < 0)\n', lamM);

% ---- 验证 5: 收缩常数 S^α/(4λ) (定理2新界) ----
% 精确 S^α: 收益梯度行 G_j(x̄) = Σθ_k h'(μ_kj(x̄))·M_k(j,:) − κ·e_j'
% h'(μ)=1−c(1−2μ), μ_kj 线性于 x̄ ⇒ G_j 线性于 x̄ ⇒ span 凸 ⇒ 最大值在顶点
Ms = {M_t, M_d, M_r};
S_alpha = 0;
for l = 1:4
    e_l = zeros(4,1); e_l(l) = 1;
    G = zeros(4,4);
    for j = 1:4
        for k = 1:3
            mukj = Ms{k}(j,:) * e_l;
            hp = 1 - c_pess*(1 - 2*mukj);
            G(j,:) = G(j,:) + theta_ref(k) * hp * Ms{k}(j,:);
        end
        G(j,j) = G(j,j) - kappa_pop;
    end
    for j=1:4, for jj=1:4
        d_ = G(j,:)-G(jj,:);
        S_alpha = max(S_alpha, max(d_)-min(d_));
    end, end
end
S_A = S_alpha / (1 + c_pess);  % 仅作参考打印
fprintf('\n[验证5] S_A=%.4f, S^α=%.4f, κ(λ=0.10)=%.3f, κ(λ=0.05)=%.3f, κ(λ=0.20)=%.3f\n', ...
    S_A, S_alpha, S_alpha/(4*0.10), S_alpha/(4*0.05), S_alpha/(4*0.20));
fprintf('         q_th(λ=0.10,β=0.3)=%.3f\n', 0.7 + 0.3*S_alpha/(4*0.10));

%% ===== 辅助函数 =====
function xs = solve_interior(nu_f, x0)
    xs = x0; dt = 0.05;
    for t = 1:40000
        nu = nu_f(xs);
        xs = xs + dt*xs.*(nu - xs'*nu);
        xs = max(xs,1e-12); xs = xs/sum(xs);
    end
end

function lam = jac_lambda_max(f, x)
    n = length(x); h = 1e-6; J = zeros(n);
    for k = 1:n
        e = zeros(n,1); e(k)=1;
        J(:,k) = (f(x+h*e)-f(x-h*e))/(2*h);
    end
    B = null(ones(1,n));
    lam = max(real(eig(B'*(J+J')/2*B)));
end

function lam = multi_lambda_max(z, Mt, Md, Mr, th, nu_fun, wV, wR, wE, LR, LE, kpop)
    f = @(zz) multi_rhs(zz, Mt, Md, Mr, th, nu_fun, wV, wR, wE, LR, LE, kpop);
    n = length(z); h = 1e-6; J = zeros(n);
    for k = 1:n
        e = zeros(n,1); e(k)=1;
        J(:,k) = (f(z+h*e)-f(z-h*e))/(2*h);
    end
    C = blkdiag(ones(1,4), ones(1,2), ones(1,2));
    B = null(C);
    lam = max(real(eig(B'*(J+J')/2*B)));
end

function dz = multi_rhs(z, Mt, Md, Mr, th, nu_fun, wV, wR, wE, LR, LE, kpop)
    xV = z(1:4); xR = z(5:6); xE = z(7:8);
    xt = wV*xV + wR*(LR*xR) + wE*(LE*xE);
    nu = nu_fun(Mt, Md, Mr, xt, th);
    nuV = nu - kpop*xV;
    nuR = [nu(1); nu(2)] - kpop*xR;
    nuE = [nu(1); nu(3)] - kpop*xE;
    dz = [xV.*(nuV - xV'*nuV); xR.*(nuR - xR'*nuR); xE.*(nuE - xE'*nuE)];
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
