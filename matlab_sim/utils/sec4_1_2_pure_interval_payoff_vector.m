function [U_lower, U_upper, U_hat, rho, mu_lower, mu_upper] = ...
    sec4_1_2_pure_interval_payoff_vector(pi_profile, delta, theta, ...
    params, agent_idx)
%SEC4_1_2_PURE_INTERVAL_PAYOFF_VECTOR Pure-action IT2 payoff intervals.
%   For fixed opponents' profile pi_-i, this function evaluates every pure
%   action j of agent i using the leave-one-out mean field
%
%       xbar_-i = sum_{n ~= i} pi_n / (N - 1).
%
%   The nonlinear membership-to-payoff map is applied before mixed
%   extension. Mixed payoffs must therefore be formed by weighting the
%   returned pure-action endpoints, not by applying g to an averaged
%   membership.

    N = size(pi_profile, 1);
    if agent_idx < 1 || agent_idx > N || agent_idx ~= floor(agent_idx)
        error('sec4_1_2_pure_interval_payoff_vector:badAgentIndex', ...
            'agent_idx must be an integer in [1, N].');
    end

    [lower_matrix, upper_matrix, hat_matrix, rho_matrix, ...
        lower_membership, upper_membership] = ...
        sec4_1_2_pure_interval_payoff_matrix( ...
        pi_profile, delta, theta, params);
    U_lower = lower_matrix(agent_idx, :)';
    U_upper = upper_matrix(agent_idx, :)';
    U_hat = hat_matrix(agent_idx, :)';
    rho = rho_matrix(agent_idx, :)';
    mu_lower = reshape(lower_membership(agent_idx, :, :), ...
        params.num_strategies, 3);
    mu_upper = reshape(upper_membership(agent_idx, :, :), ...
        params.num_strategies, 3);
end
