function [chosen, scores, ess] = sec5_1_10_logged_select(counts, log_behavior, y, q, cfg)
%SEC5_1_10_LOGGED_SELECT Joint-propensity weighted empirical risk selection.
%   Inputs contain only executed action counts, known joint log propensities,
%   observed population rewards and candidate probabilities. No simulator.
%   Homogeneous independent agents: log P(action vector) = counts*log(q').
    y = y(:); log_behavior = log_behavior(:);
    assert(size(counts, 1) == numel(y) && numel(y) == numel(log_behavior));
    assert(all(q > 0, 'all') && all(isfinite(y)));
    lw = counts*log(q')-log_behavior;
    w = exp(lw-max(lw, [], 1)); w = w./sum(w, 1);
    ess = 1./sum(w.^2, 1);
    [ys, order] = sort(y); ws = w(order, :);
    % Interpolated weighted quantile: equal weights reproduce MATLAB quantile.
    mids = cumsum(ws, 1)-.5*ws; tail = zeros(1, size(q, 1));
    for a = 1:numel(tail)
        tail(a) = interp1([0; mids(:, a); 1], [ys(1); ys; ys(end)], .05);
    end
    scores = (1-cfg.gamma)*(y'*w)+cfg.gamma*tail;
    eligible = ess >= max(cfg.min_ess, cfg.ess_fraction*numel(y));
    safe_scores = scores; safe_scores(~eligible) = -Inf;
    chosen = cfg.default_index;
    if any(eligible)
        [~, chosen] = max(safe_scores);
        if eligible(cfg.default_index) && ...
                scores(chosen)-scores(cfg.default_index) < 1e-12
            chosen = cfg.default_index;
        end
    end
end
