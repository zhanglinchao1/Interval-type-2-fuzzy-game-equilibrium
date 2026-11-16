function cert = sec4_3_1_scenario_b_certificate(p, delta, theta, alpha, focus_s, lambdas)
%SEC4_3_1_SCENARIO_B_CERTIFICATE Global response bound for the actual bell FOU.
%   Covers the full local-mean simplex by longest-edge tetrahedron bisection.
%   Polynomial ranges use Bernstein enclosures, not a sampled Jacobian.
%   For H_jk = half the directional range of grad(nu_j-nu_k),
%     Lip_1(softmax(nu/lambda)) <= (2/lambda)*sum_{j<k} b_j*b_k*H_jk.
%   Probability products are bounded on each whole tetrahedron. Complete
%   leave-one-out aggregation has l1 gain one, so the local bound also
%   bounds the N-player response. Damping gives q=1-beta+beta*kappa.
%   This evaluates the canonical solver's payoff without changing it.

assert(strcmp(p.interaction_model, 'complete_leave_one_out'));
assert(p.fou_modulation && strcmp(p.payoff_aggregation, 'concave_quadratic'));
assert(~isfield(p, 'adjacency') || isempty(p.adjacency));
assert(~isfield(p, 'tail_cvar_enable') || ~p.tail_cvar_enable);
assert(alpha >= 0 && alpha <= 1 && focus_s >= 0 && all(lambdas > 0));
K = {p.trust_matrix, p.delay_matrix, p.res_matrix};
theta = theta(:); lambdas = lambdas(:)';
assert(numel(theta) == 3 && all(theta >= 0) && abs(sum(theta)-1) < 1e-12);
assert(isequal(size(K{1}), [4,4]) && isscalar(delta));
pairs = nchoosek(1:4, 2);
polys = cell(4,3,4); endpoints = cell(4,3,2);
for j = 1:4
    d = delta*p.fou_strategy_scale(j);
    for k = 1:3
        % Ascending powers: center=g(mu)-[4*d*mu*(1-mu)]^2;
        % radius=8*d*mu*(1-mu)^2. Valid after verifying no clipping.
        polys{j,k,1} = [0,2,-1-16*d*d,32*d*d,-16*d*d];
        polys{j,k,2} = [0,8*d,-16*d,8*d];
        polys{j,k,3} = (1:4).*polys{j,k,1}(2:end);
        polys{j,k,4} = (1:3).*polys{j,k,2}(2:end);
        endpoints{j,k,1} = [0,1-4*d,4*d];
        endpoints{j,k,2} = [0,1+4*d,-4*d];
    end
end

% Independent, uniform-in-alpha scalar envelope from endpoint derivatives.
action_L = zeros(4,1); endpoint_range = [Inf,-Inf];
for j = 1:4
    for k = 1:3
        a = min(K{k}(j,:)); b = max(K{k}(j,:)); slope = 0;
        for t = 1:2
            ep = endpoints{j,k,t}; z = polynomial_range(ep,a,b);
            endpoint_range = [min(endpoint_range(1),z(1)), max(endpoint_range(2),z(2))];
            gp = [2*ep,0,0]-conv(ep,ep);
            dp = (1:4).*gp(2:end);
            z = polynomial_range(dp,a,b); slope = max(slope,max(abs(z)));
        end
        action_L(j) = action_L(j)+0.5*theta(k)*(b-a)*slope;
    end
end
assert(endpoint_range(1)>0 && endpoint_range(2)<1, ...
    'Scenario-B certificate requires unclipped endpoints on the actual mean domain.');
sorted_L = sort(action_L,'descend'); scalar_D = sum(sorted_L(1:2));

pending = {eye(4)}; depths = 0; kappa = zeros(size(lambdas));
gap_lower = inf(1,4); radius_gap = Inf; leaves = 0; nodes = 0;
volume_sum = 0; deepest = 0; leaf_rows = zeros(0,5+numel(lambdas));
while ~isempty(pending)
    V = pending{end}; pending(end) = []; depth = depths(end); depths(end) = [];
    [nu, grad, rhogap] = enclose_payoff(V);
    H = zeros(6,1);
    for t = 1:6
        j = pairs(t,1); k = pairs(t,2);
        z = [grad(j,:,1)-grad(k,:,2); grad(j,:,2)-grad(k,:,1)];
        H(t) = 0.5*max(abs(z),[],'all');
    end
    local_kappa = zeros(size(lambdas));
    for ti = 1:numel(lambdas)
        lam = lambdas(ti); prob_upper = zeros(4,1);
        for j = 1:4
            others = setdiff(1:4,j);
            exponents = (nu(others,1)-nu(j,2))/lam;
            prob_upper(j) = 1/(1+sum(exp(min(700,exponents))));
        end
        weighted = 0;
        for t = 1:6
            j = pairs(t,1); k = pairs(t,2);
            gap = [nu(j,1)-nu(k,2),nu(j,2)-nu(k,1)];
            distance = max([gap(1),-gap(2),0]); u = exp(-distance/lam);
            product = min(prob_upper(j)*prob_upper(k),u/(1+u)^2);
            weighted = weighted + product*H(t);
        end
        local_kappa(ti) = min(max(H)/(2*lam),2*weighted/lam)+1e-10;
    end
    gaps = nu(2,1)-nu(:,2)'; gaps(2) = 0;
    edges = sum((V(pairs(:,1),:)-V(pairs(:,2),:)).^2,2);
    [edge2,edge_id] = max(edges); nodes = nodes+1;
    ready = all(local_kappa < 0.85);
    if focus_s > 0
        ready = ready && all(gaps([1,3,4]) > 0) && rhogap > 0;
    end
    if ready || sqrt(edge2) <= 0.125 || depth >= 18
        kappa = max(kappa,local_kappa); gap_lower = min(gap_lower,gaps);
        radius_gap = min(radius_gap,rhogap); leaves = leaves+1;
        volume = abs(det(V(2:4,1:3)-V(1,1:3))); volume_sum = volume_sum+volume;
        deepest = max(deepest,depth);
        leaf_rows(end+1,:) = [depth,volume,min(gaps([1,3,4])),rhogap,sqrt(edge2),local_kappa]; %#ok<AGROW>
    else
        a = pairs(edge_id,1); b = pairs(edge_id,2); midpoint = (V(a,:)+V(b,:))/2;
        V1 = V; V2 = V; V1(a,:) = midpoint; V2(b,:) = midpoint;
        pending(end+1:end+2) = {V1,V2}; depths(end+1:end+2) = depth+1;
    end
end
assert(abs(volume_sum-1)<1e-10,'Simplex cover volume is inconsistent.');
cert = struct('alpha',alpha,'focus_s',focus_s,'lambda',lambdas, ...
    'kappa',kappa,'q',1-p.beta+p.beta*kappa,'certified',kappa<1, ...
    'scalar_D_uniform_alpha',scalar_D,'action_L',action_L, ...
    'endpoint_range',endpoint_range,'SP_gap_lower',gap_lower, ...
    'SC_radius_gap_lower',radius_gap,'num_leaves',leaves,'num_nodes',nodes, ...
    'max_depth',deepest,'cover_volume',volume_sum,'leaf_bounds',leaf_rows);

    function [nu, grad, rhogap] = enclose_payoff(V)
        C = zeros(4,2); R = zeros(4,2);
        dC = zeros(4,6,2); dR = zeros(4,6,2);
        for jj = 1:4
            for kk = 1:3
                mu = V*K{kk}(jj,:)'; a = min(mu); b = max(mu);
                C(jj,:) = C(jj,:)+theta(kk)*polynomial_range(polys{jj,kk,1},a,b);
                R(jj,:) = R(jj,:)+theta(kk)*polynomial_range(polys{jj,kk,2},a,b);
                cp = polynomial_range(polys{jj,kk,3},a,b);
                rp = polynomial_range(polys{jj,kk,4},a,b);
                for direction_idx = 1:6
                    dm = K{kk}(jj,pairs(direction_idx,1))-K{kk}(jj,pairs(direction_idx,2));
                    dC(jj,direction_idx,:) = reshape(squeeze(dC(jj,direction_idx,:))'+theta(kk)*sort(dm*cp),1,1,2);
                    dR(jj,direction_idx,:) = reshape(squeeze(dR(jj,direction_idx,:))'+theta(kk)*sort(dm*rp),1,1,2);
                end
            end
        end
        rhogap = R(1,1)-max(R(2:4,2));
        if focus_s == 0
            P = R; dP = dR;
        else
            [~,star] = max(R(:,1)); others = setdiff(1:4,star);
            unique_peak = R(star,1)>max([R(others,2);0.01]);
            peak = [max([R(:,1);0.01]),max([R(:,2);0.01])];
            if unique_peak
                peak = R(star,:); peak_grad = squeeze(dR(star,:,:));
            else
                peak_grad = [min([dR(:,:,1);zeros(1,6)],[],1)', ...
                    max([dR(:,:,2);zeros(1,6)],[],1)'];
            end
            P = zeros(4,2); dP = zeros(4,6,2);
            for jj = 1:4
                if unique_peak && jj == star
                    P(jj,:) = R(jj,:); dP(jj,:,:) = dR(jj,:,:); continue;
                end
                ratio = [max(0,R(jj,1)/peak(2)),min(1,R(jj,2)/peak(1))];
                power = ratio.^focus_s; P(jj,:) = interval_product(R(jj,:),power);
                for direction_idx = 1:6
                    first = (focus_s+1)*interval_product(power,squeeze(dR(jj,direction_idx,:))');
                    second = focus_s*interval_product(ratio.^(focus_s+1),peak_grad(direction_idx,:));
                    dP(jj,direction_idx,:) = reshape(first-second([2,1]),1,1,2);
                end
            end
        end
        nu = C-(1-alpha)*P(:,[2,1]);
        grad = cat(3,dC(:,:,1)-(1-alpha)*dP(:,:,2),dC(:,:,2)-(1-alpha)*dP(:,:,1));
    end
end

function z = polynomial_range(c,a,b)
% Bernstein convex-hull enclosure of a polynomial on [a,b]. Ascending c.
n = numel(c)-1; power = zeros(1,n+1);
for i = 0:n
    for j = i:n
        power(i+1) = power(i+1)+c(j+1)*nchoosek(j,i)*a^(j-i)*(b-a)^i;
    end
end
bernstein = zeros(1,n+1);
for k = 0:n
    for i = 0:k
        bernstein(k+1) = bernstein(k+1)+power(i+1)*nchoosek(k,i)/nchoosek(n,i);
    end
end
pad = 1e-12*(1+sum(abs(c))); z = [min(bernstein)-pad,max(bernstein)+pad];
end

function z = interval_product(a,b)
products = [a(1)*b,a(2)*b];
pad = 1e-12*(1+max(abs(products))); z = [min(products)-pad,max(products)+pad];
end
