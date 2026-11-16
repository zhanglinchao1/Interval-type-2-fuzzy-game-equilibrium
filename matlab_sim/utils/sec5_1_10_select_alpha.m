function [selected_alpha, scores, counts] = sec5_1_10_select_alpha( ...
    observed_alpha, observed_payoff, candidates, gamma)
%SEC5_1_10_SELECT_ALPHA Select from executed-policy observations only.
%   No simulator, perturbation labels, other policies' rewards, or future
%   observations enter this interface. gamma is a declared risk preference.
    observed_alpha = observed_alpha(:);
    observed_payoff = observed_payoff(:);
    assert(numel(observed_alpha) == numel(observed_payoff), ...
        'Calibration observations must be paired.');
    assert(all(isfinite(observed_payoff)), 'Payoffs must be finite.');
    scores = zeros(size(candidates)); counts = scores;
    for j = 1:numel(candidates)
        y = observed_payoff(observed_alpha == candidates(j));
        assert(~isempty(y), 'Every candidate needs executed-policy data.');
        counts(j) = numel(y);
        scores(j) = (1-gamma)*mean(y) + gamma*quantile(y, .05);
    end
    % Increasing candidate order breaks exact ties toward the smaller alpha.
    [~, best] = max(scores);
    selected_alpha = candidates(best);
end
