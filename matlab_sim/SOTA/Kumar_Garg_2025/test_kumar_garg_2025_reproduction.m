% Validation checks for the Kumar and Garg (2025) SOMG reproduction.

clear; clc;
root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);

run(fullfile(root_dir, 'run_kumar_garg_2025_reproduction.m'));

assert_close(res41.vbar, 181.6667, 5e-4, 'Example 4.1 vbar');
assert_close(res41.v, 90.00, 2e-3, 'Example 4.1 v');
assert_close(res41.player1.strategy, [0.7757, 0.2243], 6e-4, ...
    'Example 4.1 V1 strategy');
assert_close(res41.player1.lambda, 0.7851, 6e-4, 'Example 4.1 lambda');
assert_close(res41.player2.strategy, [0.1864, 0.8136], 8e-4, ...
    'Example 4.1 formula-derived V2 strategy');
assert_close(res41.player2.eta, 0.2498, 8e-4, 'Example 4.1 formula-derived eta');
assert(abs(res41.player2.eta - 0.2593) > 5e-3, ...
    'Example 4.1 paper-reported V2 discrepancy should be visible.');

assert_close(res43.vbar, 171.6667, 5e-4, 'Water 4.3 vbar');
assert_close(res43.v, 83.6667, 5e-4, 'Water 4.3 v');
assert_close(res43.player1.strategy, [0.7695, 0.2304, 0], 8e-4, ...
    'Water 4.3 V1 strategy');
assert_close(res43.player1.lambda, 0.7715, 8e-4, 'Water 4.3 lambda');
assert_close(res43.player2.strategy, [0.3232, 0, 0.6767], 1e-3, ...
    'Water 4.3 V2 strategy');
assert_close(res43.player2.eta, 0.3993, 1e-3, 'Water 4.3 eta');

fprintf('Kumar-Garg 2025 SOMG reproduction checks passed.\n');

function assert_close(actual, expected, tol, label)
if any(abs(actual(:) - expected(:)) > tol)
    disp(actual);
    disp(expected);
    error('%s does not match the paper within tolerance %.3g.', label, tol);
end
end
