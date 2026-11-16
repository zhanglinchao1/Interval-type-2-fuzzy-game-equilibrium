function exp_5_1_11b_shared_membership()
%EXP_5_1_11B_SHARED_MEMBERSHIP Conditional R3-1 model-structure experiment.
% Existing policies and every marginal payoff endpoint remain unchanged.
% A common embedded membership curve is used across actions for each state.
% This is an additional compatibility condition, not implied by interval data.
% The bound uses uncontracted FOUs within this selected embedded family;
% it is separate from the paper's alpha-cut criterion.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'utils'));
base = config_params(); base.lambda = 0.20; base.eps_tol = 1e-10;
rows = cell(216, 18); nrow = 0;
partialRows = cell(126, 11); npartial = 0;
for scenario = ["A", "B"]
    for n = [20, 50, 200]
        for delta = [0, 0.05, 0.10, 0.20]
            for alpha = [0, 0.5, 1]
                for seed = 42:44
                    p = base; p.N = n; p.rng_seed = seed; p.fou_modulation = true;
                    if scenario == "B"
                        cfg = scenario_b_config('concentrated');
                        p = scenario_b_env(p, cfg.fou_scale);
                    end
                    [pi, history] = sec4_3_1_wfbri_solve(p, delta, p.theta, alpha);
                    assert(history.converged, 'Original policy did not converge.');
                    [lo, hi, ~, ~, ml, mu] = sec4_1_2_pure_interval_payoff_matrix( ...
                        pi, delta, p.theta, p);
                    nominal = nominal_memberships(pi, p);
                    assert(all(ml > 0 & mu < 1, 'all'), 'Logit family needs interior bounds.');
                    separate = max(hi-sum(pi.*lo, 2), [], 'all');
                    boxByAction = hi-sum(pi.*lo, 2)-pi.*(hi-lo);
                    boxRegret = max(boxByAction, [], 'all');
                    nominalPayoff = sum((2*nominal-nominal.^2).*reshape(p.theta, 1, 1, 3), 3);
                    nominalRegret = max(nominalPayoff-sum(pi.*nominalPayoff, 2), [], 'all');
                    timer = tic;
                    [lower, upper, errorBound, endpointError] = ...
                        shared_bound(pi, nominal, ml, mu, p.theta, 1001);
                    seconds = toc(timer);
                    % Intersection of two valid upper bounds remains valid.
                    upper = min(upper, boxRegret);
                    assert(lower >= nominalRegret-1e-12 && lower <= upper+1e-12, ...
                        'The common-curve interval is inconsistent.');
                    assert(upper <= boxRegret+1e-12 && boxRegret <= separate+1e-12, ...
                        'The uncertainty-set inclusions failed.');
                    assert(endpointError < 1e-12, 'Marginal endpoints changed.');
                    if delta == 0
                        assert(max(abs([lower, upper, boxRegret, separate]-nominalRegret)) < 1e-12, ...
                            'Zero FOU must recover the nominal deviation.');
                    end
                    check_box_vertices(pi(1, :), lo(1, :), hi(1, :), boxByAction(1, :));
                    refinedLower = NaN; refinedUpper = NaN; sampledMax = NaN;
                    if n == 50 && seed == 42
                        [refinedLower, refinedUpper] = ...
                            shared_bound(pi, nominal, ml, mu, p.theta, 4001);
                        refinedUpper = min(refinedUpper, boxRegret);
                        assert(refinedLower >= lower-1e-12 && refinedLower <= upper+1e-12 ...
                            && refinedUpper >= lower-1e-12, 'Grid refinement disagrees.');
                        sampledMax = sample_check(pi, nominal, ml, mu, p.theta, seed+900);
                        assert(sampledMax <= refinedUpper+1e-12, ...
                            'A compatible realization exceeds the bound.');
                        if delta > 0
                            for eta = [0, 0.01, 0.05, 0.1, 0.25, 0.5, 1]
                                [partialLower, partialUpper, partialError] = shared_bound( ...
                                    pi, nominal, ml, mu, p.theta, 1001, eta);
                                partialUpper = min(partialUpper, boxRegret);
                                % The latent offset can differ from its common component
                                % by <= 2*eta. Reuse its exact Lipschitz bound.
                                transfer = min(boxRegret, upper+2*eta*errorBound/0.001);
                                assert(partialLower <= transfer+1e-12 && ...
                                    partialLower <= partialUpper+1e-12, ...
                                    'Mismatch transfer bound failed.');
                                if eta == 1
                                    assert(abs(partialLower-boxRegret) < 1e-12, ...
                                        'Independent offsets must recover the box.');
                                end
                                npartial = npartial+1;
                                partialRows(npartial, :) = {scenario, n, delta, alpha, eta, ...
                                    partialLower, partialUpper, upper, transfer, ...
                                    partialLower > upper+1e-12, partialError};
                            end
                        end
                    end
                    nrow = nrow+1;
                    rows(nrow, :) = {scenario, n, delta, alpha, seed, history.iterations, ...
                        nominalRegret, separate, boxRegret, lower, upper, errorBound, ...
                        endpointError, refinedLower, refinedUpper, sampledMax, ...
                        seconds, boxRegret-upper};
                end
            end
        end
        fprintf('[PASS] Shared membership family: %s, N=%d\n', scenario, n);
    end
end
T = cell2table(rows, 'VariableNames', {'Scenario','N','Delta','Alpha','Seed', ...
    'Iterations','NominalRegret','SeparateEndpointBound','RectangularRegret', ...
    'SharedLower','SharedUpper','GridErrorBound','EndpointError','RefinedLower', ...
    'RefinedUpper','SampledMaxRegret','EvaluationSeconds','BoundReduction'});
writetable(T, fullfile(root, 'table', 'table5_11b_shared_membership.csv'));
P = cell2table(partialRows, 'VariableNames', {'Scenario','N','Delta','Alpha', ...
    'IndependentFraction','PartialLower','PartialUpper','SharedOnlyUpper', ...
    'TransferredUpper','SharedBoundViolated','GridErrorBound'});
writetable(P, fullfile(root, 'table', 'table5_11b_membership_mismatch.csv'));
fprintf('Completed %d configurations; max endpoint error %.3g, grid budget %.3g.\n', ...
    height(T), max(T.EndpointError), max(T.GridErrorBound));
end

function m = nominal_memberships(pi, p)
opponents = (sum(pi, 1)-pi)/(p.N-1);
kernels = {p.trust_matrix, p.delay_matrix, p.res_matrix};
m = zeros(p.N, p.num_strategies, 3);
for k = 1:3
    m(:, :, k) = opponents*kernels{k}';
end
end

function [lower, upper, maxError, endpointError] = shared_bound(pi, m, ml, mu, theta, count, eta)
% z_k is common across actions. States k may have different offsets z_k.
% Interpolation in logit coordinates passes through lower / nominal / upper.
% For the exact sigmoid pair in Appendix J this is the shared offset family.
if nargin < 7, eta = 0; end
grid = linspace(-1, 1, count)';
step = grid(2)-grid(1);
n = size(pi, 1); s = size(pi, 2);
best = zeros(n, s); errors = zeros(n, s); endpointError = 0;
for i = 1:n
    for k = 1:3
        v0 = log(m(i, :, k)./(1-m(i, :, k)));
        down = v0-log(ml(i, :, k)./(1-ml(i, :, k)));
        up = log(mu(i, :, k)./(1-mu(i, :, k)))-v0;
        assert(all(down >= -1e-12 & up >= -1e-12), 'Nominal curve left the FOU.');
        if eta == 0
            membership = 1./(1+exp(-(v0+min(grid, 0)*down+max(grid, 0)*up)));
            values = 2*membership-membership.^2;
            deviation = values-values*pi(i, :)';
            best(i, :) = best(i, :)+theta(k)*max(deviation, [], 1);
            endpointError = max([endpointError, ...
                max(abs(membership(1, :)-ml(i, :, k))), ...
                max(abs(membership(end, :)-mu(i, :, k))), ...
                max(abs(values(1, :)-(2*ml(i, :, k)-ml(i, :, k).^2))), ...
                max(abs(values(end, :)-(2*mu(i, :, k)-mu(i, :, k).^2)))]);
        else
            for j = 1:s
                % Monotonicity gives the adversarial independent offsets:
                % +1 for the deviating action, -1 for all competing actions.
                signs = -ones(1, s); signs(j) = 1;
                offsets = (1-eta)*grid+eta*signs;
                membership = 1./(1+exp(-(v0+min(offsets, 0).*down+max(offsets, 0).*up)));
                values = 2*membership-membership.^2;
                deviation = values(:, j)-values*pi(i, :)';
                best(i, j) = best(i, j)+theta(k)*max(deviation);
            end
        end
        % max_t d[g(sigmoid(t))]/dt = 8/27. At a grid distance <= step/2,
        % each action's deviation has this explicit Lipschitz error budget.
        slope = (8/27)*max(down, up);
        variation = (1-2*pi(i, :)).*slope+sum(pi(i, :).*slope);
        errors(i, :) = errors(i, :)+theta(k)*(1-eta)*variation*step/2;
    end
end
lower = max(best, [], 'all');
upper = max(best+errors, [], 'all');
maxError = max(errors, [], 'all');
end

function check_box_vertices(pi, lo, hi, expected)
% Independent audit of the exact rectangular same-realization regret.
s = numel(pi);
corners = dec2bin(0:2^s-1, s)-'0';
values = lo+corners.*(hi-lo);
observed = max(values-values*pi', [], 1);
assert(max(abs(observed-expected)) < 1e-12, 'Rectangular regret formula failed.');
end

function worst = sample_check(pi, m, ml, mu, theta, seed)
% Three-dimensional offsets shared by all actions and agents in each draw.
rng(seed);
offsets = 2*rand(100, 3)-1;
worst = 0;
for t = 1:size(offsets, 1)
    values = zeros(size(pi));
    for k = 1:3
        v0 = log(m(:, :, k)./(1-m(:, :, k)));
        down = v0-log(ml(:, :, k)./(1-ml(:, :, k)));
        up = log(mu(:, :, k)./(1-mu(:, :, k)))-v0;
        z = offsets(t, k);
        member = 1./(1+exp(-(v0+min(z, 0)*down+max(z, 0)*up)));
        values = values+theta(k)*(2*member-member.^2);
    end
    worst = max(worst, max(values-sum(pi.*values, 2), [], 'all'));
end
end
