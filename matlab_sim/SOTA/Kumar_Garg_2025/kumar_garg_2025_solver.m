function out = kumar_garg_2025_solver(mode, varargin)
%KUMAR_GARG_2025_SOLVER Two-level fuzzy set approach for SOMG.
%   Implements the single-objective part of Kumar and Garg (Ann. Oper.
%   Res., 2025): triangular fuzzy payoffs, Yager first-index goals, and the
%   two-level LP construction for both players.

switch lower(mode)
    case 'solve_somg'
        out = solve_somg(varargin{:});
    case 'yager'
        out = yager_first_index(varargin{:});
    otherwise
        error('Unknown mode: %s', mode);
end
end

function result = solve_somg(tfn)
validateattributes(tfn, {'numeric'}, {'nonempty', '3d'});
if size(tfn, 3) ~= 3
    error('tfn must be an m-by-n-by-3 array: lower, modal, upper.');
end
lower = tfn(:, :, 1);
modal = tfn(:, :, 2);
upper = tfn(:, :, 3);
if any(lower(:) > modal(:)) || any(modal(:) > upper(:))
    error('Each triangular fuzzy number must satisfy lower <= modal <= upper.');
end

vbar_tilde = [max(lower(:)), max(modal(:)), max(upper(:))];
v_tilde = [min(lower(:)), min(modal(:)), min(upper(:))];
vbar = yager_first_index(vbar_tilde);
v = yager_first_index(v_tilde);

player1 = solve_player1(lower, modal, upper, vbar, v);
player2 = solve_player2(lower, modal, upper, vbar, v);

result.vbar_tilde = vbar_tilde;
result.v_tilde = v_tilde;
result.vbar = vbar;
result.v = v;
result.player1 = player1;
result.player2 = player2;
end

function value = yager_first_index(tfn)
value = mean(tfn, 2);
end

function sol = solve_player1(~, modal, upper, vbar, v)
[m, n] = size(modal);
spread = upper - modal;
num_vars = m + 1 + n + n;
idx_x = 1:m;
idx_d0 = m + 1;
idx_dm = m + (2:n + 1);
idx_dp = m + n + (2:n + 1);

f = zeros(num_vars, 1);
f(idx_d0) = 1;

A = [];
b = [];
for j = 1:n
    denom_const = sum(spread(:, j)) + vbar - v;
    row = zeros(1, num_vars);
    row(idx_dm(j)) = 1;
    row(idx_d0) = -denom_const;
    A = [A; row]; %#ok<AGROW>
    b = [b; 0]; %#ok<AGROW>

    row = zeros(1, num_vars);
    row(idx_x) = -spread(:, j)';
    row(idx_dm(j)) = 1;
    A = [A; row]; %#ok<AGROW>
    b = [b; vbar - v]; %#ok<AGROW>
end

Aeq = zeros(n + 1, num_vars);
beq = zeros(n + 1, 1);
Aeq(1, idx_x) = 1;
beq(1) = 1;
for j = 1:n
    Aeq(j + 1, idx_x) = modal(:, j)';
    Aeq(j + 1, idx_dm(j)) = 1;
    Aeq(j + 1, idx_dp(j)) = -1;
    beq(j + 1) = vbar;
end

lb = zeros(num_vars, 1);
ub = inf(num_vars, 1);
ub(idx_x) = 1;
x0 = feasible_start_player1(modal, vbar, idx_x, idx_d0, idx_dm, idx_dp, num_vars);
z = solve_lp_with_fmincon(f, A, b, Aeq, beq, lb, ub, x0);

x = z(idx_x)';
d0 = z(idx_d0);
dminus = z(idx_dm)';
denom = x * spread + vbar - v;
D = max(dminus ./ denom);
lambda = 1 - D;

sol.strategy = x;
sol.lambda = lambda;
sol.level1_D0 = d0;
sol.level2_D = D;
sol.Dminus = dminus;
sol.Dplus = z(idx_dp)';
sol.denominator = denom;
end

function sol = solve_player2(lower, modal, ~, vbar, v)
[m, n] = size(modal);
spread = modal - lower;
num_vars = n + 1 + m + m;
idx_y = 1:n;
idx_e0 = n + 1;
idx_em = n + (2:m + 1);
idx_ep = n + m + (2:m + 1);

f = zeros(num_vars, 1);
f(idx_e0) = 1;

A = [];
b = [];
for i = 1:m
    denom_const = sum(spread(i, :)) + vbar - v;
    row = zeros(1, num_vars);
    row(idx_em(i)) = 1;
    row(idx_e0) = -denom_const;
    A = [A; row]; %#ok<AGROW>
    b = [b; 0]; %#ok<AGROW>

    row = zeros(1, num_vars);
    row(idx_y) = -spread(i, :);
    row(idx_em(i)) = 1;
    A = [A; row]; %#ok<AGROW>
    b = [b; vbar - v]; %#ok<AGROW>
end

Aeq = zeros(m + 1, num_vars);
beq = zeros(m + 1, 1);
Aeq(1, idx_y) = 1;
beq(1) = 1;
for i = 1:m
    Aeq(i + 1, idx_y) = modal(i, :);
    Aeq(i + 1, idx_em(i)) = -1;
    Aeq(i + 1, idx_ep(i)) = 1;
    beq(i + 1) = v;
end

lb = zeros(num_vars, 1);
ub = inf(num_vars, 1);
ub(idx_y) = 1;
y0 = feasible_start_player2(modal, v, idx_y, idx_e0, idx_em, idx_ep, num_vars);
z = solve_lp_with_fmincon(f, A, b, Aeq, beq, lb, ub, y0);

y = z(idx_y)';
e0 = z(idx_e0);
eminus = z(idx_em)';
denom = spread * y' + vbar - v;
E = max(eminus ./ denom');
eta = 1 - E;

sol.strategy = y;
sol.eta = eta;
sol.level1_E0 = e0;
sol.level2_E = E;
sol.Eminus = eminus;
sol.Eplus = z(idx_ep)';
sol.denominator = denom';
end

function x0 = feasible_start_player1(modal, vbar, idx_x, idx_d0, idx_dm, idx_dp, num_vars)
m = size(modal, 1);
x = ones(1, m) / m;
dminus = max(0, vbar - x * modal);
dplus = max(0, x * modal - vbar);
x0 = zeros(num_vars, 1);
x0(idx_x) = x;
x0(idx_d0) = max([dminus, 0]);
x0(idx_dm) = dminus;
x0(idx_dp) = dplus;
end

function x0 = feasible_start_player2(modal, v, idx_y, idx_e0, idx_em, idx_ep, num_vars)
n = size(modal, 2);
y = ones(1, n) / n;
row_values = modal * y';
eminus = max(0, row_values' - v);
eplus = max(0, v - row_values');
x0 = zeros(num_vars, 1);
x0(idx_y) = y;
x0(idx_e0) = max([eminus, 0]);
x0(idx_em) = eminus;
x0(idx_ep) = eplus;
end

function z = solve_lp_with_fmincon(f, A, b, Aeq, beq, lb, ub, x0)
objective = @(x) f' * x;
options = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'Display', 'off', ...
    'MaxIterations', 2000, ...
    'MaxFunctionEvaluations', 50000, ...
    'OptimalityTolerance', 1e-11, ...
    'ConstraintTolerance', 1e-10, ...
    'StepTolerance', 1e-12);
[z, ~, exitflag] = fmincon(objective, x0, A, b, Aeq, beq, lb, ub, [], options);
if exitflag <= 0
    error('fmincon failed to solve the LP surrogate. Exitflag: %d.', exitflag);
end
z(abs(z) < 1e-10) = 0;
end
