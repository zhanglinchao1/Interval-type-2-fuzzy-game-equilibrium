% diag_beta_scan.m
% ============================================================================
% 临时诊断脚本 (验证后删除): 阻尼步长 β 对 Scenario B (concentrated) Proposed 的影响
%
% 命题 (待验证):
%   W-FBRI 阻尼迭代 π^{r+1}=(1-β)π^r+β·BR_λ(π^r) 的不动点 π*=BR_λ(π*) 与 β 无关,
%   故增大 β 只加快收敛 (降低收敛轮数 R), 不改变 π* (因此 E/WC/CE 完全不变)。
%
% 目的:
%   (1) 画出 β -> R 曲线, 确认在论文声明网格 {0.1,0.3,0.5} 内增大 β 能把 R
%       降到 < MF-RQE 的 16 (当前表四 Proposed R=17, β=0.30);
%   (2) 验证不同 β 下 π* 偏差≈0 (机器精度), 即 E/WC/CE 不变;
%   (3) 对 β=0.30 (现状) 与 β=0.50 (目标) 实测 E/WC/CE, 对照表四
%       (0.7736 / 0.6772 / 0.7206), 确认不变。
%
% 与 exp_5_1_6 的 Scenario B Proposed 工作点完全一致:
%   N=50, λ=config(0.20), α-cut=0.50, focus_s=10, delta=0.20,
%   tail-CVaR(enable, K=64, α=0.10, mix=0.50), concentrated 冲击, seeds 42:51。
% ============================================================================
clearvars; clc;
sd = fileparts(mfilename('fullpath'));
addpath(fullfile(sd, 'utils'));
addpath(genpath(fullfile(sd, 'SOTA')));

% ---- 复现表四 Proposed 工作点 ----
pb = config_params();
pb.fou_modulation   = true;
pb.R_max            = 300;
pb.eps_tol          = 1e-4;
pb.proposed_focus_s = 10;
delta_true = 0.20;
alpha_true = 0.50;
theta_true = pb.theta;
cfg   = scenario_b_config('concentrated');
seeds = 42:51;
betas = [0.10 0.20 0.30 0.40 0.50 0.60 0.70];

% 设定单个 (β, seed) 的 Proposed 工作点参数
make_pB = @(b, seed) set_tail(scenario_b_env_seed(pb, cfg, b, seed), alpha_true);

% ---- Part 1: β -> R 曲线 + π* 不变性 (只 solve, 快) ----
R_mean = zeros(numel(betas), 1);
R_min  = zeros(numel(betas), 1);
R_max_ = zeros(numel(betas), 1);
PIS    = cell(numel(betas), numel(seeds));
for bi = 1:numel(betas)
    Rs = zeros(numel(seeds), 1);
    for si = 1:numel(seeds)
        pB = make_pB(betas(bi), seeds(si));
        [pi_star, h] = sec5_1_alpha_robust_solve(pB, delta_true, ...
            theta_true, alpha_true, pb.proposed_focus_s);
        Rs(si) = h.iterations;
        PIS{bi, si} = pi_star;
    end
    R_mean(bi) = mean(Rs);
    R_min(bi)  = min(Rs);
    R_max_(bi) = max(Rs);
end

ref_bi = find(abs(betas - 0.30) < 1e-9, 1);
fprintf('\n==== Part 1: beta -> R (mean over 10 seeds) + pi* deviation vs beta=0.30 ====\n');
fprintf('beta   R_mean  R_min  R_max   max|pi*-pi*(0.30)|\n');
for bi = 1:numel(betas)
    dev = 0;
    for si = 1:numel(seeds)
        dev = max(dev, max(abs(PIS{bi, si}(:) - PIS{ref_bi, si}(:))));
    end
    fprintf('%.2f   %5.1f   %4d   %4d    %.3e\n', ...
        betas(bi), R_mean(bi), R_min(bi), R_max_(bi), dev);
end

% ---- Part 2: β=0.30 vs 0.50 的 E/WC/CE (repeats=500), 验证不变 + 对照表四 ----
fprintf('\n==== Part 2: E/WC/CE at beta=0.30 vs 0.50 (repeats=500, mean over 10 seeds) ====\n');
fprintf('(table IV reference: E=0.7736, WC=0.6772, CE=0.7206)\n');
fprintf('beta    E[Ubar]     WC_Q5      CE_0.55\n');
for b = [0.30 0.50]
    E = zeros(numel(seeds), 1);
    W = zeros(numel(seeds), 1);
    for si = 1:numel(seeds)
        pB = make_pB(b, seeds(si));
        [pi_star, ~] = sec5_1_alpha_robust_solve(pB, delta_true, ...
            theta_true, alpha_true, pb.proposed_focus_s);
        [e, w] = scenario_b_payoff_stats(pi_star, delta_true, theta_true, ...
            pB, 500, cfg.p_shock, cfg.sigma_small, cfg.shock_strength);
        E(si) = e; W(si) = w;
    end
    Em = mean(E); Wm = mean(W); CE = Em - 0.55 * (Em - Wm);
    fprintf('%.2f    %.4f     %.4f     %.4f\n', b, Em, Wm, CE);
end
fprintf('\n[diag_beta_scan] done.\n');

% ---------------------------------------------------------------------------
function pB = scenario_b_env_seed(pb, cfg, beta, seed)
% 构造单个 (β, seed) 的 Scenario B 环境参数 (与 exp_5_1_6 一致)
    p = pb;
    p.N = 50;
    p.rng_seed = seed;
    p.beta = beta;
    pB = scenario_b_env(p, cfg.fou_scale);
    pB.shock_mode = cfg.shock_mode;
end

function pB = set_tail(pB, alpha_true)
% 注入 proposed_tail_profile 的统一合法工作点字段 (exp_5_1_6 L734-738)
    pB.proposed_decision_alpha = alpha_true;
    pB.tail_cvar_enable = true;
    pB.tail_cvar_K      = 64;
    pB.tail_cvar_alpha  = 0.10;
    pB.tail_cvar_mix    = 0.50;
end
