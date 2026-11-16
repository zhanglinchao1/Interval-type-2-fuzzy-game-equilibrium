function [regret, witness] = sec5_1_embedded_regret(p, m, lower, upper, theta, eta)
%SEC5_1_EMBEDDED_REGRET Exact worst deviation in a specified embedded family.
% Each criterion has a common z in [-1,1]. The action-specific coordinate is
% (1-eta)*z + eta*v_j, v_j in [-1,1]. Memberships interpolate linearly through
% lower (-1), nominal (0), upper (+1). This compatibility assumption is extra
% information; it is not implied by the marginal FOU endpoints.
% g(mu)=2*mu-mu^2 makes each segment quadratic, so the oracle is analytic.
% witness is a feasible vector U_j-U, with p*witness attaining the regret.

[n, s] = size(p);
candidate = zeros(n, s); witnesses = zeros(n, s, s);
if eta == 1
    lo = sum((2*lower-lower.^2).*reshape(theta, 1, 1, []), 3);
    hi = sum((2*upper-upper.^2).*reshape(theta, 1, 1, []), 3);
    for j = 1:s
        values = lo; values(:, j) = hi(:, j);
        a = values(:, j)-values;
        candidate(:, j) = sum(p.*a, 2);
        witnesses(:, j, :) = reshape(a, n, 1, s);
    end
else
    breakpoint = min(1, eta/(1-eta));
    edges = unique([-1, -breakpoint, 0, breakpoint, 1]);
    for j = 1:s
        weights = -p; weights(:, j) = weights(:, j)+1;
        signs = -ones(1, s); signs(j) = 1;
        payoff = zeros(n, s);
        for k = 1:numel(theta)
            mk = m(:, :, k); dl = mk-lower(:, :, k); du = upper(:, :, k)-mk;
            best = -inf(n, 1); bestValues = zeros(n, s);
            for segment = 1:numel(edges)-1
                left = edges(segment); right = edges(segment+1);
                midpoint = (left+right)/2;
                positive = (1-eta)*midpoint+eta*signs >= 0;
                slope = dl; slope(:, positive) = du(:, positive);
                a = mk+eta*signs.*slope; b = (1-eta)*slope;
                c0 = 2*a-a.^2; c1 = 2*(1-a).*b; c2 = -b.^2;
                linear = sum(weights.*c1, 2); quadratic = sum(weights.*c2, 2);
                vertex = repmat(left, n, 1);
                concave = quadratic < -eps;
                vertex(concave) = max(left, min(right, ...
                    -linear(concave)./(2*quadratic(concave))));
                for z = [repmat(left, n, 1), repmat(right, n, 1), vertex]
                    values = c0+c1.*z+c2.*z.^2;
                    score = sum(weights.*values, 2);
                    replace = score > best;
                    best(replace) = score(replace);
                    bestValues(replace, :) = values(replace, :);
                end
            end
            payoff = payoff+theta(k)*bestValues;
        end
        a = payoff(:, j)-payoff;
        candidate(:, j) = sum(p.*a, 2);
        witnesses(:, j, :) = reshape(a, n, 1, s);
    end
end
[regret, action] = max(candidate, [], 2);
witness = zeros(n, s);
for j = 1:s
    selected = action == j;
    witness(selected, :) = reshape(witnesses(selected, j, :), sum(selected), s);
end
end
