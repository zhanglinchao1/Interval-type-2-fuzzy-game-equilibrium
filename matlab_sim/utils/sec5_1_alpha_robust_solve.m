function [pi_star, history] = sec5_1_alpha_robust_solve(params, delta, theta, alpha, focus_s)
%SEC5_1_ALPHA_ROBUST_SOLVE Compatibility wrapper for canonical W-FBRI.
%   All Gamma_{alpha,s} computations are implemented by
%   sec4_3_1_wfbri_solve so that theory and experiments share one solver.

    if nargin < 5 || isempty(focus_s)
        focus_s = 0;
    end

    [pi_star, history] = sec4_3_1_wfbri_solve( ...
        params, delta, theta, alpha, focus_s);
end
