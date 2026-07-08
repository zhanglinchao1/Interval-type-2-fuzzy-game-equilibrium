function [U_lower, U_upper, U_hat, rho, mu_lower, mu_upper] = ...
    sec4_1_2_pure_interval_payoff_matrix(pi_profile, delta, theta, params)
%SEC4_1_2_PURE_INTERVAL_PAYOFF_MATRIX Pure-action payoffs for all agents.
%   Rows index agents and columns index their pure actions. Opponent mean
%   fields are computed leave-one-out in one vectorized pass, preserving
%   O(N) scaling for the fixed four-strategy game.

    N = size(pi_profile, 1);
    num_s = params.num_strategies;
    if N < 2
        error('sec4_1_2_pure_interval_payoff_matrix:requiresTwoAgents', ...
            'The leave-one-out mean field requires at least two agents.');
    end
    if size(pi_profile, 2) ~= num_s
        error('sec4_1_2_pure_interval_payoff_matrix:badProfileWidth', ...
            'pi_profile must have params.num_strategies columns.');
    end

    theta = theta(:);
    if numel(theta) ~= 3
        error('sec4_1_2_pure_interval_payoff_matrix:badTheta', ...
            'theta must contain trust, delay, and resource weights.');
    end

    x_bar_minus = (sum(pi_profile, 1) - pi_profile) / (N - 1);
    kernels = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    mu_nominal = zeros(N, num_s, 3);
    for k = 1:3
        mu_nominal(:, :, k) = x_bar_minus * kernels{k}';
    end
    mu_nominal = max(0, min(1, mu_nominal));

    if isscalar(delta)
        delta_by_state = reshape(repmat(delta, 1, 3), 1, 1, 3);
    else
        delta_by_state = reshape(delta, 1, 1, []);
        if numel(delta_by_state) ~= 3
            error('sec4_1_2_pure_interval_payoff_matrix:badDelta', ...
                'delta must be scalar or contain three state half-widths.');
        end
    end

    use_bell_fou = isfield(params, 'fou_modulation') ...
        && params.fou_modulation;
    if use_bell_fou
        fou_shape = 4 * mu_nominal .* (1 - mu_nominal);
    else
        fou_shape = ones(N, num_s, 3);
    end

    if isfield(params, 'fou_strategy_scale') ...
            && ~isempty(params.fou_strategy_scale)
        exposure = params.fou_strategy_scale(:)';
        if numel(exposure) ~= num_s
            error('sec4_1_2_pure_interval_payoff_matrix:badExposure', ...
                'fou_strategy_scale must contain one value per strategy.');
        end
    else
        exposure = ones(1, num_s);
    end

    delta_eff = fou_shape .* reshape(exposure, 1, num_s, 1) ...
        .* delta_by_state;
    mu_lower = max(0, mu_nominal - delta_eff);
    mu_upper = min(1, mu_nominal + delta_eff);

    if isfield(params, 'payoff_aggregation')
        aggregation = params.payoff_aggregation;
    else
        aggregation = 'concave_quadratic';
    end
    lower_flat = reshape(mu_lower, N * num_s, 3);
    upper_flat = reshape(mu_upper, N * num_s, 3);
    [U_lower_flat, U_upper_flat] = sec4_1_2_it2_payoff( ...
        lower_flat, upper_flat, theta, aggregation);
    U_lower = reshape(U_lower_flat, N, num_s);
    U_upper = reshape(U_upper_flat, N, num_s);
    [U_hat, rho] = sec4_2_1_crystallized_payoff(U_lower, U_upper);
end
