function report = sec5_1_premise_diagnostics(omega, params)
%SEC5_1_PREMISE_DIAGNOSTICS Local numerical checks for A2/A5.
%   These quantities are trajectory-local diagnostics, not global
%   certificates. L_sigma is the tangent-space spectral norm of the
%   reduced governance target h(omega)=sigma(Delta(x*(omega),omega)).

    [omega, fixed_point_iterations] = solve_reduced_fixed_point( ...
        omega(:), params);
    K = numel(omega);
    basis = null(ones(1, K));
    h_step = 1e-5;
    jacobian_reduced = zeros(K, K - 1);

    for k = 1:(K - 1)
        direction = basis(:, k);
        omega_plus = sec3_2_project_simplex(omega + h_step * direction);
        omega_minus = sec3_2_project_simplex(omega - h_step * direction);
        target_plus = reduced_target(omega_plus, params);
        target_minus = reduced_target(omega_minus, params);
        jacobian_reduced(:, k) = ...
            (target_plus - target_minus) / (2 * h_step);
    end

    tangent_jacobian = basis' * jacobian_reduced;
    L_sigma_local = norm(tangent_jacobian, 2);
    if L_sigma_local < 1
        c_omega_local = (1 - L_sigma_local) / ...
            (1 + L_sigma_local)^2;
    else
        c_omega_local = NaN;
    end

    x_uniform = ones(4, 1) / 4;
    x_star = sec5_1_slow_manifold(omega, params, x_uniform);
    theta = params.P_pay * omega;
    theta = theta / sum(theta);
    lambda_max_tangent = sec5_1_jacobian_lambda_max( ...
        x_star, theta, params);

    initial_states = [x_uniform, ...
        [0.70; 0.10; 0.10; 0.10], ...
        [0.10; 0.70; 0.10; 0.10], ...
        [0.10; 0.10; 0.70; 0.10], ...
        [0.10; 0.10; 0.10; 0.70]];
    equilibria = zeros(4, size(initial_states, 2));
    for k = 1:size(initial_states, 2)
        equilibria(:, k) = sec5_1_slow_manifold( ...
            omega, params, initial_states(:, k));
    end
    basin_spread = 0;
    for a = 1:size(equilibria, 2)
        for b = (a + 1):size(equilibria, 2)
            basin_spread = max(basin_spread, ...
                norm(equilibria(:, a) - equilibria(:, b), 2));
        end
    end

    governance_initial_states = zeros(K, K + 1);
    governance_initial_states(:, 1) = ones(K, 1) / K;
    for k = 1:K
        governance_initial_states(:, k + 1) = 0.1;
        governance_initial_states(k, k + 1) = 0.6;
    end
    governance_equilibria = zeros(K, size(governance_initial_states, 2));
    for k = 1:size(governance_initial_states, 2)
        governance_equilibria(:, k) = solve_reduced_fixed_point( ...
            governance_initial_states(:, k), params);
    end
    governance_basin_spread = 0;
    for a = 1:size(governance_equilibria, 2)
        for b = (a + 1):size(governance_equilibria, 2)
            governance_basin_spread = max(governance_basin_spread, ...
                norm(governance_equilibria(:, a) - ...
                governance_equilibria(:, b), 2));
        end
    end

    target = reduced_target(omega, params);
    report.L_sigma_local = L_sigma_local;
    report.c_omega_local = c_omega_local;
    report.lambda_max_tangent = lambda_max_tangent;
    report.fast_margin_local = max(0, -lambda_max_tangent);
    report.reduced_residual_inf = norm(target - omega, Inf);
    report.basin_spread = basin_spread;
    report.num_basin_initializations = size(initial_states, 2);
    report.governance_basin_spread = governance_basin_spread;
    report.num_governance_initializations = ...
        size(governance_initial_states, 2);
    report.fixed_point_iterations = fixed_point_iterations;
    report.evaluation_omega = omega;
    report.global_certificate = false;
    report.epsilon_g_threshold = NaN;
end

function [omega, iterations] = solve_reduced_fixed_point(omega, params)
%SOLVE_REDUCED_FIXED_POINT Locate the tested reduced-governance fixed point.
    omega = sec3_2_project_simplex(omega(:));
    max_iterations = 200;
    tolerance = 1e-10;
    for iterations = 1:max_iterations
        omega_next = reduced_target(omega, params);
        if norm(omega_next - omega, Inf) <= tolerance
            omega = omega_next;
            return;
        end
        omega = omega_next;
    end
end

function target = reduced_target(omega, params)
    x_star = sec5_1_slow_manifold(omega, params);
    delta = sec4_4_3_governance_performance( ...
        x_star, omega, params.P_pay, params);
    target = sec3_2_bounded_sigma(delta);
end
