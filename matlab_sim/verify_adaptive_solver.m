function verify_adaptive_solver()
%VERIFY_ADAPTIVE_SOLVER  确认正式求解器 (sec5_1_alpha_robust_solve) 的 (α,s) 行为:
%   (1) 向后兼容: s=0 (默认) 与历史标量 α 数值一致;
%   (2) 全量复现: s>0 在 Scenario B 复现探针的 CE (~0.728);
%   (3) 打印 Scenario B 下 ρ 量级, 确认 rho_floor=0.01 不误触发。

    clc;
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(script_dir, 'utils'));

    base = config_params();
    base.fou_modulation = true; base.R_max = 300; base.eps_tol = 1e-4; base.N = 50;
    cfg = scenario_b_config(); theta = base.theta; delta = 0.20; gamma = 0.55;
    seeds = 42:51; repeats = 300;

    % ---- rho magnitude probe (seed 42) ----
    p = base; p.rng_seed = 42; pB = scenario_b_env(p, cfg.fou_scale);
    [pi0,~] = sec5_1_alpha_robust_solve(pB, delta, theta, 0.5, 0);
    rng_show_rho(pi0, delta, theta, pB);

    % ---- backward compatibility: default (4 args) == explicit s=0 ----
    [piA,hA] = sec5_1_alpha_robust_solve(pB, delta, theta, 0.5);     % default
    [piB,hB] = sec5_1_alpha_robust_solve(pB, delta, theta, 0.5, 0);  % explicit s=0
    fprintf('\n[compat] max|pi_default - pi_s0| = %.3e  (iters %d vs %d)\n', ...
        max(abs(piA(:)-piB(:))), hA.iterations, hB.iterations);

    % ---- full Scenario B over s ----
    fprintf('\n==== Scenario B via OFFICIAL solver (10 seeds, 300 reps) ====\n');
    for s = [0, 10, 30]
        for a = [0.5]
            per = eval_seeds(base, cfg, theta, delta, seeds, repeats, gamma, a, s);
            fprintf('  alpha=%.2f s=%2d  E=%.4f+-%.4f  WC=%.4f+-%.4f  CE=%.4f+-%.4f  SC=%.3f  R=%4.1f\n', ...
                a, s, mean(per.E), ci95(per.E), mean(per.WC), ci95(per.WC), ...
                mean(per.CE), ci95(per.CE), mean(per.SC), mean(per.R));
        end
    end
    % worst-case endpoint via official solver (alpha=0,s=0)
    per0 = eval_seeds(base, cfg, theta, delta, seeds, repeats, gamma, 0.0, 0);
    fprintf('  alpha=0.00 s= 0  E=%.4f+-%.4f  WC=%.4f+-%.4f  CE=%.4f+-%.4f  SC=%.3f  R=%4.1f  (worst-case)\n', ...
        mean(per0.E), ci95(per0.E), mean(per0.WC), ci95(per0.WC), ...
        mean(per0.CE), ci95(per0.CE), mean(per0.SC), mean(per0.R));

    fprintf('\nExpected (from probe): s=0 ->CE~0.7167, s=30 ->CE~0.7283, worst-case ->CE~0.7171\n');
end

function per = eval_seeds(base, cfg, theta, delta, seeds, repeats, gamma, alpha, s)
    n = numel(seeds);
    per.E=zeros(n,1); per.WC=zeros(n,1); per.CE=zeros(n,1); per.SC=zeros(n,1); per.R=zeros(n,1);
    for k = 1:n
        p = base; p.rng_seed = seeds(k);
        pB = scenario_b_env(p, cfg.fou_scale);
        [pi_star, hist] = sec5_1_alpha_robust_solve(pB, delta, theta, alpha, s);
        [E1,W1] = scenario_b_payoff_stats(pi_star, delta, theta, pB, repeats, ...
            cfg.p_shock, cfg.sigma_small, cfg.shock_strength);
        per.E(k)=E1; per.WC(k)=W1; per.CE(k)=E1-gamma*(E1-W1);
        per.SC(k)=mean(pi_star(:,1)); per.R(k)=hist.iterations;
    end
end

function rng_show_rho(pi_star, delta, theta, params)
    [~, ~, ~, rho_all] = sec4_1_2_pure_interval_payoff_matrix( ...
        pi_star, delta, theta, params);
    fprintf('[rho] Scenario B rho range: min=%.4f  median=%.4f  max=%.4f  (floor=0.01)\n', ...
        min(rho_all(:)), median(rho_all(:)), max(rho_all(:)));
    fprintf('[rho] per-strategy mean rho [SC SP DC DP] = [%.4f %.4f %.4f %.4f]\n', ...
        mean(rho_all(:,1)), mean(rho_all(:,2)), mean(rho_all(:,3)), mean(rho_all(:,4)));
end

function c = ci95(x)
    x=x(~isnan(x)); if numel(x)<=1, c=0; else, c=1.96*std(x)/sqrt(numel(x)); end
end
