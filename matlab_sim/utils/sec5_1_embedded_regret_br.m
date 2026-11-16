function [p, gap, iterations] = sec5_1_embedded_regret_br(center, m, lo, hi, theta, eta, alpha, lambda)
%SEC5_1_EMBEDDED_REGRET_BR Entropy-regularized minimax-regret response.
% Maximize alpha*p*center-(1-alpha)*R_E(p)+lambda*H(p).
% Dual conditional gradient uses exact witnesses and a concave line search.
% The returned duality gap bounds the own-response optimization error.

weight = 1-alpha;
p = softmax_rows(center/lambda);
if weight == 0
    gap = zeros(size(p, 1), 1); iterations = 0;
    return;
end
[~, dual] = sec5_1_embedded_regret(p, m, lo, hi, theta, eta);
for iterations = 1:2000
    p = softmax_rows((alpha*center-weight*dual)/lambda);
    [~, vertex] = sec5_1_embedded_regret(p, m, lo, hi, theta, eta);
    direction = vertex-dual;
    gap = weight*sum(p.*direction, 2);
    if max(gap) <= 1e-10
        return;
    end
    left = zeros(size(gap)); right = ones(size(gap));
    for step = 1:35
        fraction = (left+right)/2;
        trial = softmax_rows((alpha*center-weight*(dual+fraction.*direction))/lambda);
        increasing = sum(trial.*direction, 2) > 0;
        left(increasing) = fraction(increasing);
        right(~increasing) = fraction(~increasing);
    end
    fraction = (left+right)/2;
    fraction(gap <= 1e-10) = 0;
    dual = dual+fraction.*direction;
end
p = softmax_rows((alpha*center-weight*dual)/lambda);
[~, vertex] = sec5_1_embedded_regret(p, m, lo, hi, theta, eta);
gap = weight*sum(p.*(vertex-dual), 2);
end

function p = softmax_rows(score)
p = exp(score-max(score, [], 2));
p = p./sum(p, 2);
end
