function p = scenario_b_sample_environment(params, p_shock, sigma_small, shock_strength)
%SCENARIO_B_SAMPLE_ENVIRONMENT One canonical Scenario-B kernel realization.
%   Uses the caller's RNG. Draw order matches scenario_b_payoff_stats.
    p = params;
    names = {'trust_matrix', 'delay_matrix', 'res_matrix'};
    for k = 1:3
        name = names{k};
        p.(name) = max(0, min(1, params.(name) + ...
            sigma_small * randn(size(params.(name)))));
    end
    if rand() < p_shock
        t = 1;
        if isfield(params, 'shock_mode') && strcmp(params.shock_mode, 'dispersed')
            prob = params.fou_strategy_scale(:)' / sum(params.fou_strategy_scale);
            t = find(rand() <= cumsum(prob), 1, 'first');
            if isempty(t); t = numel(prob); end
        end
        for k = 1:3
            name = names{k}; M = p.(name);
            M(t, :) = M(t, :) - shock_strength;
            M(:, t) = M(:, t) - .5 * shock_strength;
            p.(name) = max(0, min(1, M));
        end
    end
end
