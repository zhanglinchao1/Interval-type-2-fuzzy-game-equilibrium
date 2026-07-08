function [U_lower, U_upper, U_hat, rho, pure] = ...
    sec4_1_2_mixed_payoff(pi_profile, delta, theta, params)
%SEC4_1_2_MIXED_PAYOFF Canonical multilinear extension of IT2 payoffs.
%   Pure-action interval payoffs are evaluated first. The mixed-strategy
%   endpoints are their probability-weighted expectations:
%
%       U_lower_i = sum_j pi_ij u_lower_ij,
%       U_upper_i = sum_j pi_ij u_upper_ij.
%
%   This ordering is the single payoff definition used by the game,
%   W-FBRI, robustness checks, and experiment metrics.

    [pure.U_lower, pure.U_upper, pure.U_hat, pure.rho, ...
        pure.mu_lower, pure.mu_upper] = ...
        sec4_1_2_pure_interval_payoff_matrix( ...
        pi_profile, delta, theta, params);

    U_lower = sum(pi_profile .* pure.U_lower, 2);
    U_upper = sum(pi_profile .* pure.U_upper, 2);
    [U_hat, rho] = sec4_2_1_crystallized_payoff(U_lower, U_upper);
end
