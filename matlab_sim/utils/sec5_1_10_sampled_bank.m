function [bank, counts] = sec5_1_10_sampled_bank(profiles, params, env, n)
%SEC5_1_10_SAMPLED_BANK Private simulation outcomes for sampled joint actions.
%   Counts are sufficient here only because agents have identical kernels.
%   Selection code must receive only the actually executed column/row.
    k = numel(profiles); bank = zeros(n, k); counts = zeros(n, 4, k);
    actions_rng = RandStream('mt19937ar', 'Seed', params.rng_seed+83000);
    uniforms = rand(actions_rng, n, params.N);
    for a = 1:k
        assert(max(abs(profiles{a}-profiles{a}(1, :)), [], 'all') < 1e-10);
        cuts = cumsum(profiles{a}(1, :));
        action = 1 + (uniforms > cuts(1)) + (uniforms > cuts(2)) + (uniforms > cuts(3));
        for j = 1:4; counts(:, j, a) = sum(action == j, 2); end
    end
    params.shock_mode = env.shock_mode;
    rng(params.rng_seed + 520);
    for t = 1:n
        p = scenario_b_sample_environment(params, env.p_shock, ...
            env.sigma_small, env.shock_strength);
        kernels = cat(3, p.trust_matrix, p.delay_matrix, p.res_matrix);
        for a = 1:k
            c = counts(t, :, a); other = (c-eye(4))/(p.N-1);
            % Exact population payoff for the realized one-hot profile.
            mu = zeros(4, 3);
            for h = 1:3; mu(:, h) = sum(other .* kernels(:, :, h), 2); end
            % Zero-count actions never contribute, even if their hypothetical
            % leave-one-out proportions contain a negative component.
            mu = max(0, min(1, mu));
            pure = (2*mu-mu.^2)*p.theta(:);
            bank(t, a) = c*pure/p.N;
            if t <= 2
                onehot = repelem(eye(4), c, 1);
                [~, ~, actual] = sec4_1_2_mixed_payoff(onehot, 0, p.theta, p);
                assert(abs(bank(t, a)-mean(actual)) < 1e-12);
            end
        end
    end
end
