% verify_setup.m - 环境与代码完整性快速验证
% 运行此脚本确认所有函数文件正确加载且基本逻辑无误
% 共 15 项检查，对应 dev_plan.md 中"一致性检查清单"

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));

fprintf('===== 代码完整性验证 (15 项) =====\n\n');
errors = 0;

%% 1. config_params (含论文 (3-8) θ=P_pay·ω 一致性)
try
    params = config_params();
    assert(params.N == 50);
    assert(params.num_strategies == 4);
    assert(params.K == 5);
    assert(size(params.P_pay, 1) == 3 && size(params.P_pay, 2) == 5);
    assert(all(abs(sum(params.P_pay, 1) - 1) < 1e-10), ...
        'P_pay 列归一化约束 (3-8) 违反');
    % 论文 (3-8): θ = P_pay × ω
    theta_recompute = params.P_pay * params.omega_init;
    assert(all(abs(params.theta - theta_recompute) < 1e-12), ...
        '论文 (3-8) θ = P_pay × ω 一致性违反');
    % 论文表5.1 设计目标: ω=uniform 下 θ ≈ [0.40; 0.35; 0.25]
    expected_theta = [0.40; 0.35; 0.25];
    assert(all(abs(params.theta - expected_theta) < 1e-10), ...
        sprintf('θ_default 偏离设计目标 [0.40,0.35,0.25]: 当前 [%.4f,%.4f,%.4f]', ...
        params.theta));
    fprintf('[ OK ] config_params: 参数加载正确, (3-8) θ=P_pay·ω 严格成立\n');
catch ME
    fprintf('[FAIL] config_params: %s\n', ME.message);
    errors = errors + 1;
end

%% 2. sec3_3_nominal_membership
try
    rng(42);
    N = 10; params.N = N;
    pi_test = ones(N, 4) / 4;
    mu_nom = sec3_3_nominal_membership(pi_test, params);
    assert(size(mu_nom, 1) == N && size(mu_nom, 2) == 3);
    assert(all(mu_nom(:) >= 0) && all(mu_nom(:) <= 1));
    fprintf('[ OK ] sec3_3_nominal_membership: 输出维度和范围正确\n');
catch ME
    fprintf('[FAIL] sec3_3_nominal_membership: %s\n', ME.message);
    errors = errors + 1;
end

%% 3. sec4_1_1_induced_membership
try
    [mu_l, mu_u] = sec4_1_1_induced_membership(pi_test, 0.1, params);
    assert(all(mu_l(:) <= mu_u(:)));
    assert(all(mu_l(:) >= 0) && all(mu_u(:) <= 1));
    fprintf('[ OK ] sec4_1_1_induced_membership: 上下界关系正确\n');
catch ME
    fprintf('[FAIL] sec4_1_1_induced_membership: %s\n', ME.message);
    errors = errors + 1;
end

%% 4. sec4_1_2_it2_payoff
try
    theta = params.theta;     % 从 config_params 统一取值 = P_pay × omega_init
    [U_l, U_u] = sec4_1_2_it2_payoff(mu_l, mu_u, theta);
    assert(all(U_l <= U_u));
    assert(all(U_l >= 0) && all(U_u <= 1));
    fprintf('[ OK ] sec4_1_2_it2_payoff: 收益范围正确\n');
catch ME
    fprintf('[FAIL] sec4_1_2_it2_payoff: %s\n', ME.message);
    errors = errors + 1;
end

%% 5. sec4_2_1_crystallized_payoff
try
    [U_hat, rho] = sec4_2_1_crystallized_payoff(U_l, U_u);
    assert(all(rho >= 0));
    assert(all(abs(U_hat - (U_l + U_u)/2) < 1e-12));
    fprintf('[ OK ] sec4_2_1_crystallized_payoff: 中心-半径计算正确\n');
catch ME
    fprintf('[FAIL] sec4_2_1_crystallized_payoff: %s\n', ME.message);
    errors = errors + 1;
end

%% 6. sec4_3_1_softmax_br
try
    nu_test = [0.5; 0.3; 0.1; 0.2];
    br = sec4_3_1_softmax_br(nu_test, 0.1);
    assert(abs(sum(br) - 1) < 1e-12);
    assert(all(br > 0));
    [~, max_idx] = max(nu_test);
    [~, br_max_idx] = max(br);
    assert(max_idx == br_max_idx);
    fprintf('[ OK ] sec4_3_1_softmax_br: 概率分布且最大值对应正确\n');
catch ME
    fprintf('[FAIL] sec4_3_1_softmax_br: %s\n', ME.message);
    errors = errors + 1;
end

%% 7. sec4_3_1_pure_payoff_vector
try
    nu_i = sec4_3_1_pure_payoff_vector(pi_test, 0.1, theta, params, 1);
    assert(length(nu_i) == 4);
    assert(all(nu_i >= 0) && all(nu_i <= 1));
    fprintf('[ OK ] sec4_3_1_pure_payoff_vector: 输出维度和范围正确\n');
catch ME
    fprintf('[FAIL] sec4_3_1_pure_payoff_vector: %s\n', ME.message);
    errors = errors + 1;
end

%% 8. sec4_4_1_population_payoff
try
    x_test = [0.3; 0.3; 0.2; 0.2];
    U_j = sec4_4_1_population_payoff(x_test, theta, params);
    assert(length(U_j) == 4);
    assert(all(U_j >= 0));
    fprintf('[ OK ] sec4_4_1_population_payoff: 群体收益计算正确\n');
catch ME
    fprintf('[FAIL] sec4_4_1_population_payoff: %s\n', ME.message);
    errors = errors + 1;
end

%% 9. sec4_3_1_wfbri_solve (小规模快速测试)
try
    params_small = config_params();
    params_small.N = 5;
    params_small.R_max = 20;
    [pi_star, hist] = sec4_3_1_wfbri_solve(params_small, 0.1, theta);
    assert(size(pi_star, 1) == 5 && size(pi_star, 2) == 4);
    assert(all(abs(sum(pi_star, 2) - 1) < 1e-10));
    assert(hist.iterations <= 20);
    fprintf('[ OK ] sec4_3_1_wfbri_solve: 小规模求解正常运行\n');
catch ME
    fprintf('[FAIL] sec4_3_1_wfbri_solve: %s\n', ME.message);
    errors = errors + 1;
end

%% 10. sec4_4_4_dual_timescale (含 Lyapunov 序列)
try
    params_small.T_evo = 50;
    params_small.dt_evo = 0.05;
    params_small.varepsilon_g = 1e-3;
    x0 = [0.4; 0.3; 0.2; 0.1];
    omega0 = ones(5,1) / 5;
    [x_h, o_h, t_h, V_h] = sec4_4_4_dual_timescale(x0, omega0, params_small);
    assert(size(x_h, 1) == 50 && size(x_h, 2) == 4);
    assert(all(abs(sum(x_h, 2) - 1) < 1e-6));
    assert(length(V_h) == 50);
    assert(V_h(end) <= V_h(1) + 1e-8);
    descent_ratio = sum(diff(V_h) <= 1e-8) / (length(V_h) - 1);
    assert(descent_ratio >= 0.6, ...
        sprintf('Lyapunov 下降率仅 %.2f%%, 期望 >=60%%', descent_ratio*100));
    fprintf('[ OK ] sec4_4_4_dual_timescale: 仿真+Lyapunov 下降率=%.1f%%\n', ...
        descent_ratio*100);
catch ME
    fprintf('[FAIL] sec4_4_4_dual_timescale: %s\n', ME.message);
    errors = errors + 1;
end

%% 11. sec4_2_2_robust_alpha_fne
try
    params_chk = config_params();
    params_chk.N = 5;
    params_chk.R_max = 30;
    [pi_chk, ~] = sec4_3_1_wfbri_solve(params_chk, 0.1, theta);
    report = sec4_2_2_robust_alpha_fne(pi_chk, 0.1, theta, 0.5, params_chk, 10);
    assert(isfield(report, 'eps_required'));
    assert(report.eps_required >= 0);
    assert(report.total_checks == params_chk.N * 10);
    fprintf('[ OK ] sec4_2_2_robust_alpha_fne: 不等式验证正常运行\n');
catch ME
    fprintf('[FAIL] sec4_2_2_robust_alpha_fne: %s\n', ME.message);
    errors = errors + 1;
end

%% 12. sec4_4_3_governance_performance 显式依赖 ω
try
    x_test = [0.3; 0.3; 0.2; 0.2];
    omega1 = ones(5, 1) / 5;
    omega2 = [0.5; 0.2; 0.1; 0.1; 0.1];
    rng(0);
    D1 = sec4_4_3_governance_performance(x_test, omega1, params.P_pay, params);
    rng(0);
    D2 = sec4_4_3_governance_performance(x_test, omega2, params.P_pay, params);
    assert(any(abs(D1 - D2) > 1e-6));
    fprintf('[ OK ] sec4_4_3_governance_performance: Δ(x,ω) 显式依赖 ω\n');
catch ME
    fprintf('[FAIL] sec4_4_3_governance_performance: %s\n', ME.message);
    errors = errors + 1;
end

%% 13. N=2 手算公式校验 (对应 dev_plan.md §4.4.1)
try
    params_v = config_params();
    params_v.N = 2;
    pi_profile_v = [0.5, 0.3, 0.1, 0.1; ...
                    0.2, 0.4, 0.3, 0.1];
    delta_v = 0.1;
    theta_v = params_v.theta;   % = P_pay × omega_init = [0.40; 0.35; 0.25]
    nu_v = sec4_3_1_pure_payoff_vector(pi_profile_v, delta_v, theta_v, ...
        params_v, 1);
    expected_nu_1_1 = 0.727;
    diff_v = abs(nu_v(1) - expected_nu_1_1);
    assert(diff_v < 1e-3, ...
        sprintf('手算 ν_{1,1}=0.727, 代码=%.4f, 偏差=%.2e', nu_v(1), diff_v));
    fprintf('[ OK ] N=2 手算校验: ν_{1,1}=%.4f (期望 0.727, 偏差 %.2e)\n', ...
        nu_v(1), diff_v);
catch ME
    fprintf('[FAIL] N=2 手算校验: %s\n', ME.message);
    errors = errors + 1;
end

%% 14. α-cut (4-13)(4-14) 代数恒等式校验
try
    U_l_t = [0.3; 0.4; 0.5];
    U_u_t = [0.5; 0.7; 0.8];
    [U_hat_t, rho_t] = sec4_2_1_crystallized_payoff(U_l_t, U_u_t);
    for alpha_t = [0.1, 0.5, 0.8, 1.0]
        U_alpha_l_t = U_hat_t - (1 - alpha_t) * rho_t;
        U_alpha_u_t = U_hat_t + (1 - alpha_t) * rho_t;
        assert(all(abs((U_alpha_l_t + U_alpha_u_t) - 2 * U_hat_t) < 1e-12));
        rho_alpha_t = (U_alpha_u_t - U_alpha_l_t) / 2;
        assert(all(abs(rho_alpha_t - (1 - alpha_t) * rho_t) < 1e-12));
    end
    fprintf('[ OK ] α-cut (4-13)(4-14) 代数恒等式: 全部 α 通过\n');
catch ME
    fprintf('[FAIL] α-cut 代数恒等式: %s\n', ME.message);
    errors = errors + 1;
end

%% 15. (4-29) 群体收益代数恒等式
try
    x_v = [0.3; 0.3; 0.2; 0.2];
    params_v = config_params();
    theta_v = params_v.theta;   % = P_pay × omega_init = [0.40; 0.35; 0.25]
    U_j = sec4_4_1_population_payoff(x_v, theta_v, params_v);
    % 手算 j=1 (SC):
    %   M_trust(1,:) * x = 0.9*0.3+0.7*0.3+0.3*0.2+0.1*0.2 = 0.56
    %   M_delay(1,:) * x = 0.85*0.3+0.75*0.3+0.5*0.2+0.3*0.2 = 0.640
    %   M_res(1,:)   * x = 0.7*0.3+0.8*0.3+0.6*0.2+0.4*0.2  = 0.650
    %   U_1 = 0.4*0.56 + 0.35*0.640 + 0.25*0.650 = 0.6105
    expected_U1 = 0.4*0.56 + 0.35*0.64 + 0.25*0.65;
    assert(abs(U_j(1) - expected_U1) < 1e-10);
    fprintf('[ OK ] (4-29) U_j(1)=%.4f (期望 %.4f)\n', U_j(1), expected_U1);
catch ME
    fprintf('[FAIL] (4-29) 代数校验: %s\n', ME.message);
    errors = errors + 1;
end

%% 总结
fprintf('\n===== 验证结果 =====\n');
if errors == 0
    fprintf('全部通过! 15/15 检查项无误\n');
    fprintf('可以运行 run_all.m 执行完整实验\n');
else
    fprintf('发现 %d 个错误，请检查对应模块\n', errors);
end
