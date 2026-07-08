function out = mallozzi_vidalpuga_2023_solver(mode, varargin)
%MALLOZZI_VIDALPUGA_2023_SOLVER Reproduce Hurwicz fuzzy-game checks.
%   This dispatcher implements the finite fuzzy interval game notions used
%   by Mallozzi and Vidal-Puga (FSS 2023): loose/tight Nash equilibrium,
%   loose/interior Hurwicz Nash equilibrium, and a fixed-Hurwicz 2x2 mixed
%   solver for scalarized interval payoffs.

switch lower(mode)
    case 'interval_payoff'
        out = interval_payoff(varargin{:});
    case 'triangular_payoff'
        out = triangular_payoff(varargin{:});
    case 'pure_equilibria'
        out = pure_equilibria(varargin{:});
    case 'fixed_hurwicz_2x2'
        out = fixed_hurwicz_2x2(varargin{:});
    otherwise
        error('Unknown mode: %s', mode);
end
end

function payoff = interval_payoff(lower_bound, upper_bound)
validateattributes(lower_bound, {'numeric'}, {'nonempty'});
validateattributes(upper_bound, {'numeric'}, {'size', size(lower_bound)});
if any(lower_bound(:) > upper_bound(:))
    error('Each interval must satisfy lower_bound <= upper_bound.');
end
payoff.lo0 = lower_bound;
payoff.lo1 = zeros(size(lower_bound));
payoff.hi0 = upper_bound;
payoff.hi1 = zeros(size(lower_bound));
end

function payoff = triangular_payoff(center, left_spread, right_spread)
validateattributes(center, {'numeric'}, {'nonempty'});
validateattributes(left_spread, {'numeric'}, {'size', size(center), 'nonnegative'});
validateattributes(right_spread, {'numeric'}, {'size', size(center), 'nonnegative'});
payoff.lo0 = center - left_spread;
payoff.lo1 = left_spread;
payoff.hi0 = center + right_spread;
payoff.hi1 = -right_spread;
end

function result = pure_equilibria(game, opts)
if nargin < 2
    opts = struct();
end
tol = get_opt(opts, 'tol', 1e-10);
validate_game(game);

counts = game.action_counts(:)';
num_players = numel(counts);
num_profiles = prod(counts);

profiles = zeros(num_profiles, num_players);
is_tne = false(num_profiles, 1);
is_lne = false(num_profiles, 1);
is_lhne = false(num_profiles, 1);
is_ihne = false(num_profiles, 1);
eta_bounds = cell(num_profiles, 1);

for idx = 1:num_profiles
    profile = ind_to_profile(idx, counts);
    profiles(idx, :) = profile;

    tight_ok = true;
    loose_ok = true;
    lb = zeros(1, num_players);
    ub = ones(1, num_players);

    for player = 1:num_players
        current_action = profile(player);
        for action = 1:counts(player)
            if action == current_action
                continue;
            end
            dev_profile = profile;
            dev_profile(player) = action;

            current = get_entry(game.payoffs{player}, profile);
            deviated = get_entry(game.payoffs{player}, dev_profile);

            if ~fuzzy_leq(deviated, current, tol)
                tight_ok = false;
            end
            if fuzzy_lt(current, deviated, tol)
                loose_ok = false;
            end

            [lb(player), ub(player)] = update_eta_interval( ...
                lb(player), ub(player), current, deviated, tol);
        end
    end

    is_tne(idx) = tight_ok;
    is_lne(idx) = loose_ok;
    eta_feasible = all(lb <= ub + tol);
    is_lhne(idx) = eta_feasible;
    is_ihne(idx) = eta_feasible && all(lb < 1 - tol & ub > tol);
    eta_bounds{idx} = [lb(:), ub(:)];
end

result.profiles = profiles;
result.tight_nash = profiles(is_tne, :);
result.hurwicz_nash = result.tight_nash;
result.loose_nash = profiles(is_lne, :);
result.loose_hurwicz_nash = profiles(is_lhne, :);
result.interior_hurwicz_nash = profiles(is_ihne, :);
result.eta_bounds = eta_bounds;
result.flags = table(is_tne, is_lne, is_lhne, is_ihne, ...
    'VariableNames', {'TightNash', 'LooseNash', ...
    'LooseHurwiczNash', 'InteriorHurwiczNash'});
end

function result = fixed_hurwicz_2x2(game, eta, alpha)
validate_game(game);
if numel(game.action_counts) ~= 2 || any(game.action_counts ~= [2 2])
    error('fixed_hurwicz_2x2 expects a two-player 2x2 game.');
end
validateattributes(eta, {'numeric'}, {'vector', 'numel', 2, '>=', 0, '<=', 1});
validateattributes(alpha, {'numeric'}, {'scalar', '>=', 0, '<=', 1});

A = hurwicz_matrix(game.payoffs{1}, eta(1), alpha);
B = hurwicz_matrix(game.payoffs{2}, eta(2), alpha);

[pure_profiles, pure_residuals] = pure_scalar_nash(A, B);
[p, q, interior_ok] = interior_mixed_2x2(A, B);
mixed_residual = scalar_residual_2x2(A, B, p, q);

result.player1_matrix = A;
result.player2_matrix = B;
result.p_row1 = p;
result.q_col1 = q;
result.mixed_profile = [p, 1 - p; q, 1 - q];
result.interior_mixed_exists = interior_ok;
result.mixed_residual = mixed_residual;
result.pure_profiles = pure_profiles;
result.pure_residuals = pure_residuals;
end

function validate_game(game)
if ~isfield(game, 'payoffs') || ~iscell(game.payoffs)
    error('game.payoffs must be a cell array with one payoff tensor per player.');
end
if ~isfield(game, 'action_counts')
    error('game.action_counts is required.');
end
counts = game.action_counts(:)';
if numel(counts) ~= numel(game.payoffs)
    error('Number of payoff tensors must match number of players.');
end
for i = 1:numel(game.payoffs)
    payoff = game.payoffs{i};
    required = {'lo0', 'lo1', 'hi0', 'hi1'};
    for j = 1:numel(required)
        if ~isfield(payoff, required{j})
            error('Payoff tensor %d lacks field %s.', i, required{j});
        end
    end
    if ~isequal(size(payoff.lo0), counts)
        error('Payoff tensor %d has incompatible size.', i);
    end
end
end

function value = get_opt(opts, name, default_value)
if isfield(opts, name)
    value = opts.(name);
else
    value = default_value;
end
end

function profile = ind_to_profile(idx, counts)
subs = cell(1, numel(counts));
[subs{:}] = ind2sub(counts, idx);
profile = cellfun(@double, subs);
end

function entry = get_entry(payoff, profile)
subs = num2cell(profile);
entry.lo0 = payoff.lo0(subs{:});
entry.lo1 = payoff.lo1(subs{:});
entry.hi0 = payoff.hi0(subs{:});
entry.hi1 = payoff.hi1(subs{:});
end

function [lo, hi] = alpha_cut(entry, alpha)
lo = entry.lo0 + entry.lo1 * alpha;
hi = entry.hi0 + entry.hi1 * alpha;
end

function tf = fuzzy_leq(F, G, tol)
tf = true;
for alpha = [0 1]
    [flo, fhi] = alpha_cut(F, alpha);
    [glo, ghi] = alpha_cut(G, alpha);
    if flo > glo + tol || fhi > ghi + tol
        tf = false;
        return;
    end
end
end

function tf = fuzzy_lt(F, G, tol)
if ~fuzzy_leq(F, G, tol)
    tf = false;
    return;
end
strict = false;
for alpha = [0 1]
    [flo, fhi] = alpha_cut(F, alpha);
    [glo, ghi] = alpha_cut(G, alpha);
    strict = strict || flo < glo - tol || fhi < ghi - tol;
end
tf = strict;
end

function [lb, ub] = update_eta_interval(lb, ub, current, deviated, tol)
for alpha = [0 1]
    [clo, chi] = alpha_cut(current, alpha);
    [dlo, dhi] = alpha_cut(deviated, alpha);
    a = clo - dlo;
    b = (chi - dhi) - a;
    if abs(b) <= tol
        if a < -tol
            lb = 1;
            ub = 0;
            return;
        end
    elseif b > 0
        lb = max(lb, -a / b);
    else
        ub = min(ub, a / (-b));
    end
end
lb = max(lb, 0);
ub = min(ub, 1);
end

function M = hurwicz_matrix(payoff, eta, alpha)
lo = payoff.lo0 + payoff.lo1 * alpha;
hi = payoff.hi0 + payoff.hi1 * alpha;
M = (1 - eta) .* lo + eta .* hi;
end

function [profiles, residuals] = pure_scalar_nash(A, B)
profiles = [];
residuals = [];
for r = 1:2
    for c = 1:2
        gain1 = max(A(:, c)) - A(r, c);
        gain2 = max(B(r, :)) - B(r, c);
        residual = max([gain1, gain2, 0]);
        if residual <= 1e-10
            profiles = [profiles; r, c]; %#ok<AGROW>
            residuals = [residuals; residual]; %#ok<AGROW>
        end
    end
end
end

function [p, q, ok] = interior_mixed_2x2(A, B)
den_q = A(1, 1) - A(1, 2) - A(2, 1) + A(2, 2);
den_p = B(1, 1) - B(2, 1) - B(1, 2) + B(2, 2);
if abs(den_q) <= 1e-12 || abs(den_p) <= 1e-12
    p = NaN;
    q = NaN;
    ok = false;
    return;
end
q = (A(2, 2) - A(1, 2)) / den_q;
p = (B(2, 2) - B(2, 1)) / den_p;
ok = p >= -1e-10 && p <= 1 + 1e-10 && q >= -1e-10 && q <= 1 + 1e-10;
p = min(max(p, 0), 1);
q = min(max(q, 0), 1);
end

function residual = scalar_residual_2x2(A, B, p, q)
if isnan(p) || isnan(q)
    residual = Inf;
    return;
end
row_payoffs = A * [q; 1 - q];
col_payoffs = [p, 1 - p] * B;
value1 = [p, 1 - p] * row_payoffs;
value2 = col_payoffs * [q; 1 - q];
residual = max([max(row_payoffs) - value1, max(col_payoffs) - value2, 0]);
end
