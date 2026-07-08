% test_dong_wan_2024_reproduction.m
% Dong and Wan (2024) 复现的验收测试。
%
% 断言"良定且可稳健复现"的量:
%   1. T2IVIFHAWA 聚合算子对原文 Example 2 (gamma=2) 逐位精确;
%   2. minimax 策略 z* 复现 Table 4;
%   3. 期望支付 E 复现 Table 4;
%   4. maximin / minimax 解满足模型(Eq.17)约束(可行性)。
%
% 不断言 maximin 策略 y* 逐位相等: 原文该目标规划退化(解非唯一), Table 4 的
% y* 是 LINGO 返回的某个顶点(甚至违反其自身约束, 见 run 脚本诊断), 因此只校验
% y* 为可行的 GP 最优解, 而非与 Table 4 数值相等。

clear; clc;

root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);

%% 1. 算子层: Example 2 (gamma=2) 逐位精确
M = [0.60 0.80 0.50 0.70 0.10 0.20 0.10 0.30;
     0.80 0.90 0.80 0.80 0.10 0.10 0.05 0.10;
     0.05 0.20 0.20 0.25 0.63 0.75 0.55 0.74];
op_got = t2ivif_hawa(M, [0.32 0.41 0.27], 2);
op_ref = [0.595 0.766 0.592 0.662 0.173 0.228 0.125 0.259];
op_err = max(abs(op_got - op_ref));
fprintf('operator_err = %0.6g\n', op_err);
assert(op_err <= 1e-3, 'T2IVIFHAWA operator does not reproduce Example 2.');

%% 2-4. 博弈层
opts = struct('delta', 0.5, 'tau', 0.9, 'gamma', 3, ...
    'random_starts', 16, 'display', 'off');
result = dong_wan_2024_t2ivif_solver('paper', opts);

ref_z = [0.1493 0.3655 0.4852];
ref_expected = [0.5570 0.6853 0.4258 0.6218 0.1657 0.2545 0.2442 0.3398];

err_z = max(abs(result.minimax.strategy - ref_z));
err_expected = max(abs(result.expected_payoff - ref_expected));
fprintf('err_z=%0.6g, err_expected=%0.6g\n', err_z, err_expected);

% 可行性: 两侧目标规划解均满足模型约束
assert(result.maximin.exit_check <= 1e-5, 'Maximin constraints are violated.');
assert(result.minimax.exit_check <= 1e-5, 'Minimax constraints are violated.');

% minimax 策略与期望支付可稳健复现
assert(err_z <= 5e-3, 'Player PII strategy z* does not reproduce Table 4.');
assert(err_expected <= 1e-2, 'Expected payoff E does not reproduce Table 4.');

% maximin 策略: 仅校验为合法混合策略且各优先级正偏差极小(GP 最优)
y = result.maximin.strategy;
assert(abs(sum(y) - 1) <= 1e-6 && all(y >= -1e-9), 'y* is not a valid mixed strategy.');
assert(max(result.maximin.positive_deviation) <= 1e-3, 'y* is not GP-optimal (large positive deviation).');

fprintf('Dong and Wan 2024 reproduction test passed.\n');
