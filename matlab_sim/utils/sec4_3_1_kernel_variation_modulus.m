function [D_theta, info] = sec4_3_1_kernel_variation_modulus(params, theta, delta)
%SEC4_3_1_KERNEL_VARIATION_MODULUS Exact variation modulus for Proposition 2.
%   The implemented payoff clips uniform-FOU endpoints to [0,1]. These
%   clipping breakpoints partition the mean-field simplex into finitely many
%   polytopes. On each polytope and at each endpoint tau=1-alpha in {0,1},
%   every strategy-gap gradient is affine. Its variation therefore attains
%   the global maximum at a polytope vertex.
%
%   D_theta is the exact local-mean modulus. It is the global modulus used by
%   Theorem 1 only for complete leave-one-out interaction, whose weighted
%   indegree factor chi_A equals one:
%       kappa = D_theta/(2*lambda),
%       q_th  = (1-beta) + beta*kappa.
%
%   info.D_saturation_free stores the corresponding exact modulus when no
%   endpoint is clipped. It is used only by results that explicitly assume
%   the saturation-free uniform-FOU regime.

    if nargin < 3 || isempty(delta)
        if isfield(params, 'delta') && ~isempty(params.delta)
            delta = params.delta;
        else
            delta = 0;
        end
    end

    if isfield(params, 'interaction_model') && ...
            ~strcmp(params.interaction_model, 'complete_leave_one_out')
        error('sec4_3_1_kernel_variation_modulus:unsupportedTopology', ...
            ['D_theta requires multiplication by the interaction topology ', ...
             'factor outside the complete leave-one-out model.']);
    end
    if isfield(params, 'adjacency') && ~isempty(params.adjacency)
        error('sec4_3_1_kernel_variation_modulus:unsupportedAdjacency', ...
            'The reported D_theta certificate does not cover adjacency input.');
    end

    if isfield(params, 'payoff_aggregation') && ~isempty(params.payoff_aggregation)
        aggregation = lower(params.payoff_aggregation);
    else
        aggregation = 'concave_quadratic';
    end
    if ~ismember(aggregation, {'linear', 'concave_quadratic', 'concave'})
        error('sec4_3_1_kernel_variation_modulus:badAggregation', ...
            'Unknown payoff aggregation "%s".', aggregation);
    end
    if isfield(params, 'fou_modulation') && params.fou_modulation
        error('sec4_3_1_kernel_variation_modulus:bellFOU', ...
            ['This exact polyhedral certificate applies to uniform FOUs. ' ...
             'Use the bell-FOU radius bound for modulated endpoints.']);
    end

    M = {params.trust_matrix, params.delay_matrix, params.res_matrix};
    num_k = numel(M);
    num_s = size(M{1}, 1);
    theta = theta(:);
    if numel(theta) ~= num_k
        error('sec4_3_1_kernel_variation_modulus:badTheta', ...
            'theta must contain one weight per payoff kernel.');
    end

    delta = delta(:);
    if isscalar(delta)
        delta = repmat(delta, num_k, 1);
    end
    if numel(delta) ~= num_k || any(delta < 0) || any(delta > 0.5)
        error('sec4_3_1_kernel_variation_modulus:badDelta', ...
            'delta must be a scalar or a K-vector in [0,0.5].');
    end

    strategy_scale = ones(num_s, 1);
    if isfield(params, 'fou_strategy_scale') && ...
            ~isempty(params.fou_strategy_scale)
        strategy_scale = params.fou_strategy_scale(:);
        if numel(strategy_scale) ~= num_s || any(strategy_scale < 0)
            error('sec4_3_1_kernel_variation_modulus:badScale', ...
                'fou_strategy_scale must contain one nonnegative value per strategy.');
        end
    end
    delta_eff = strategy_scale * delta';
    if any(delta_eff(:) > 0.5)
        error('sec4_3_1_kernel_variation_modulus:scaledDelta', ...
            'Scaled uniform-FOU half-widths must not exceed 0.5.');
    end

    W = zeros(num_s);
    for k = 1:num_k
        W = W + theta(k) * M{k};
    end
    [D_kernel, linear_pair] = local_linear_modulus(W);

    [D_sf, sf_arg] = local_saturation_free_modulus( ...
        M, theta, delta_eff, aggregation);
    [D_clip, clip_arg, enum_info] = local_clipped_modulus( ...
        M, theta, delta_eff, aggregation);

    D_theta = D_clip;
    info.W = W;
    info.argmax_pair = clip_arg.pair;
    info.argmax_x = clip_arg.x;
    info.argmax_tau = clip_arg.tau;
    info.argmax_regions = clip_arg.regions;
    info.D_clip = D_clip;
    info.D_saturation_free = D_sf;
    info.saturation_free_arg = sf_arg;
    info.D_kernel = D_kernel;
    info.linear_argmax_pair = linear_pair;
    info.L_g = 1 + double(~strcmp(aggregation, 'linear'));
    info.D_Lg_bound = info.L_g * D_kernel;
    info.D_box = NaN;
    info.aggregation = aggregation;
    info.delta_eff = delta_eff;
    info.certificate = 'exact_polyhedral_vertices';
    info.num_candidate_vertices = enum_info.num_candidate_vertices;
    info.num_full_dimensional_cells = enum_info.num_full_dimensional_cells;
end

function [D_kernel, argmax_pair] = local_linear_modulus(W)
    num_s = size(W, 1);
    D_kernel = 0;
    argmax_pair = [1, 1];
    for j = 1:num_s
        for jp = (j + 1):num_s
            d_row = W(j, :) - W(jp, :);
            half_range = 0.5 * (max(d_row) - min(d_row));
            if half_range > D_kernel
                D_kernel = half_range;
                argmax_pair = [j, jp];
            end
        end
    end
end

function [D_sf, arg] = local_saturation_free_modulus( ...
        M, theta, delta_eff, aggregation)
    num_s = size(M{1}, 1);
    num_k = numel(M);
    D_sf = 0;
    arg = struct('pair', [1, 1], 'x', zeros(1, num_s), 'tau', 0);
    for j = 1:num_s
        for jp = 1:num_s
            if j == jp; continue; end
            for r = 1:num_s
                x = zeros(num_s, 1);
                x(r) = 1;
                for tau = [0, 1]
                    grad_j = zeros(1, num_s);
                    grad_jp = zeros(1, num_s);
                    for k = 1:num_k
                        mu_j = M{k}(j, :) * x;
                        mu_jp = M{k}(jp, :) * x;
                        if strcmp(aggregation, 'linear')
                            slope_j = 1;
                            slope_jp = 1;
                        else
                            slope_j = 2 - 2 * mu_j + 2 * tau * delta_eff(j, k);
                            slope_jp = 2 - 2 * mu_jp + 2 * tau * delta_eff(jp, k);
                        end
                        grad_j = grad_j + theta(k) * slope_j * M{k}(j, :);
                        grad_jp = grad_jp + theta(k) * slope_jp * M{k}(jp, :);
                    end
                    gap_grad = grad_j - grad_jp;
                    half_range = 0.5 * (max(gap_grad) - min(gap_grad));
                    if half_range > D_sf
                        D_sf = half_range;
                        arg = struct('pair', [j, jp], 'x', x', 'tau', tau);
                    end
                end
            end
        end
    end
end

function [D_clip, arg, enum_info] = local_clipped_modulus( ...
        M, theta, delta_eff, aggregation)
    num_s = size(M{1}, 1);
    num_k = numel(M);
    num_memberships = 2 * num_k;
    D_clip = 0;
    arg = struct('pair', [1, 1], 'x', zeros(1, num_s), ...
        'tau', 0, 'regions', ones(1, num_memberships));
    total_vertices = 0;
    total_cells = 0;

    for j = 1:num_s
        for jp = 1:num_s
            if j == jp; continue; end

            rows = zeros(num_memberships, num_s);
            widths = zeros(num_memberships, 1);
            for k = 1:num_k
                rows(k, :) = M{k}(j, :);
                widths(k) = delta_eff(j, k);
                rows(num_k + k, :) = M{k}(jp, :);
                widths(num_k + k) = delta_eff(jp, k);
            end
            candidate_vertices = local_arrangement_vertices(rows, widths);
            total_vertices = total_vertices + size(candidate_vertices, 1);

            num_region_codes = 3^num_memberships;
            for code_idx = 0:(num_region_codes - 1)
                regions = local_decode_regions(code_idx, num_memberships);
                [A, b] = local_region_inequalities(rows, widths, regions);
                inside = all(A * candidate_vertices' <= b + 1e-10, 1);
                cell_vertices = candidate_vertices(inside, :);
                if size(cell_vertices, 1) < num_s || ...
                        rank(cell_vertices(2:end, :) - cell_vertices(1, :), 1e-9) ...
                        < num_s - 1
                    continue;
                end
                total_cells = total_cells + 1;

                for tau = [0, 1]
                    for v_idx = 1:size(cell_vertices, 1)
                        x = cell_vertices(v_idx, :)';
                        grad_j = zeros(1, num_s);
                        grad_jp = zeros(1, num_s);
                        for k = 1:num_k
                            mu_j = M{k}(j, :) * x;
                            mu_jp = M{k}(jp, :) * x;
                            slope_j = local_cell_slope(mu_j, widths(k), ...
                                regions(k), tau, aggregation);
                            slope_jp = local_cell_slope(mu_jp, widths(num_k + k), ...
                                regions(num_k + k), tau, aggregation);
                            grad_j = grad_j + theta(k) * slope_j * M{k}(j, :);
                            grad_jp = grad_jp + theta(k) * slope_jp * M{k}(jp, :);
                        end
                        gap_grad = grad_j - grad_jp;
                        half_range = 0.5 * (max(gap_grad) - min(gap_grad));
                        if half_range > D_clip + 1e-12
                            D_clip = half_range;
                            arg = struct('pair', [j, jp], 'x', x', ...
                                'tau', tau, 'regions', regions);
                        end
                    end
                end
            end
        end
    end

    enum_info.num_candidate_vertices = total_vertices;
    enum_info.num_full_dimensional_cells = total_cells;
end

function vertices = local_arrangement_vertices(rows, widths)
    num_s = size(rows, 2);
    eq_rows = eye(num_s);
    eq_rhs = zeros(num_s, 1);
    for p = 1:size(rows, 1)
        eq_rows = [eq_rows; rows(p, :); rows(p, :)]; %#ok<AGROW>
        eq_rhs = [eq_rhs; widths(p); 1 - widths(p)]; %#ok<AGROW>
    end

    combos = nchoosek(1:size(eq_rows, 1), num_s - 1);
    vertices = zeros(size(combos, 1), num_s);
    count = 0;
    for c = 1:size(combos, 1)
        E = [ones(1, num_s); eq_rows(combos(c, :), :)];
        if rank(E, 1e-11) < num_s
            continue;
        end
        rhs = [1; eq_rhs(combos(c, :))];
        x = E \ rhs;
        if all(x >= -1e-10) && all(x <= 1 + 1e-10)
            x(abs(x) < 1e-12) = 0;
            x(abs(x - 1) < 1e-12) = 1;
            x = x / sum(x);
            count = count + 1;
            vertices(count, :) = x';
        end
    end
    vertices = vertices(1:count, :);
    vertices = unique(round(vertices, 12), 'rows');
end

function regions = local_decode_regions(code_idx, count)
    regions = zeros(1, count);
    value = code_idx;
    for p = 1:count
        regions(p) = mod(value, 3) + 1;
        value = floor(value / 3);
    end
end

function [A, b] = local_region_inequalities(rows, widths, regions)
    num_s = size(rows, 2);
    A = -eye(num_s);
    b = zeros(num_s, 1);
    for p = 1:size(rows, 1)
        row = rows(p, :);
        width = widths(p);
        switch regions(p)
            case 1  % low: mu <= delta
                A = [A; row]; %#ok<AGROW>
                b = [b; width]; %#ok<AGROW>
            case 2  % middle: delta <= mu <= 1-delta
                A = [A; -row; row]; %#ok<AGROW>
                b = [b; -width; 1 - width]; %#ok<AGROW>
            case 3  % high: mu >= 1-delta
                A = [A; -row]; %#ok<AGROW>
                b = [b; -(1 - width)]; %#ok<AGROW>
        end
    end
end

function slope = local_cell_slope(mu, width, region, tau, aggregation)
    weight_lower = (1 + tau) / 2;
    weight_upper = (1 - tau) / 2;
    if strcmp(aggregation, 'linear')
        switch region
            case 1
                slope = weight_upper;
            case 2
                slope = 1;
            case 3
                slope = weight_lower;
        end
        return;
    end

    switch region
        case 1
            slope = weight_upper * (2 - 2 * (mu + width));
        case 2
            slope = 2 - 2 * mu + 2 * tau * width;
        case 3
            slope = weight_lower * (2 - 2 * (mu - width));
    end
end
