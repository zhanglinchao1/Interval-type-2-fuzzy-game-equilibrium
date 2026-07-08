function report = sec4_2_2_robust_alpha_fne(pi_star, delta, theta, alpha, ...
    params, ~, focus_s)
%SEC4_2_2_ROBUST_ALPHA_FNE Exact pure-deviation robustness certificate.
%   The canonical mixed extension is affine in an agent's own strategy, so
%   the largest unilateral deviation is attained by a pure action. The
%   checker therefore enumerates all pure deviations instead of sampling.
%
%   For s=0, P=(1-alpha)rho and the standard Lemma-1 interval term is
%   2*barR. For focused pessimism, 0<=P<=R=(1-alpha)rho, and
%
%     Ubar_alpha(dev)-Uunder_alpha(inc)
%       <= eps_NE + (R_dev+P_dev) + (R_inc-P_inc).
%
%   Hence the profile-specific interval term below is exact for the given
%   pure-payoff slice, while 3*barR is a valid coarse bound. The former
%   reduces to at most 2*barR when s=0.

    if nargin < 7 || isempty(focus_s)
        focus_s = 0;
    end

    N = size(pi_star, 1);
    num_s = params.num_strategies;
    [~, ~, pure_hat, pure_rho] = ...
        sec4_1_2_pure_interval_payoff_matrix( ...
        pi_star, delta, theta, params);

    R = (1 - alpha) * pure_rho;
    if focus_s <= 0
        P = R;
    else
        rho_floor = 0.01;
        rho_peak = max(max(pure_rho, [], 2), rho_floor);
        P = R .* (pure_rho ./ rho_peak).^focus_s;
    end

    incumbent_hat = sum(pi_star .* pure_hat, 2);
    incumbent_R = sum(pi_star .* R, 2);
    incumbent_P = sum(pi_star .* P, 2);
    focused_pure = pure_hat - P;
    focused_incumbent = sum(pi_star .* focused_pure, 2);

    robust_gap = pure_hat + R - (incumbent_hat - incumbent_R);
    per_agent_gap = max(robust_gap, [], 2);
    ne_gap = max(focused_pure - focused_incumbent, [], 2);
    interval_term = max(R + P, [], 2) + incumbent_R - incumbent_P;

    bar_R = max(R, [], 'all');
    if focus_s <= 0
        coarse_interval_bound = 2 * bar_R;
    else
        coarse_interval_bound = 3 * bar_R;
    end

    report.eps_required = max(0, max(per_agent_gap));
    report.violation_count = nnz(robust_gap > 1e-6);
    report.total_checks = N * num_s;
    report.max_deviation_gap = max(per_agent_gap);
    report.per_agent_gap = per_agent_gap;
    report.alpha = alpha;
    report.focus_s = focus_s;
    report.eps_ne = max(0, max(ne_gap));
    report.profile_interval_term = max(interval_term);
    report.profile_certificate = report.eps_ne + ...
        report.profile_interval_term;
    report.theoretical_bound = coarse_interval_bound;
    report.certificate_slack = report.profile_certificate - ...
        report.eps_required;
end
