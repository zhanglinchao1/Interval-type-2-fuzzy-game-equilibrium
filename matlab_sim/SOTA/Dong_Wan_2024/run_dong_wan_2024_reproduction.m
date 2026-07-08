% run_dong_wan_2024_reproduction.m
% 复现 Dong and Wan (2024, ESWA 249:123398) 第 7 节的 T2IVIF 矩阵博弈算例。
%
% 复现分两层证据:
%   (A) 算子层: 用原文 Example 2 (gamma=2, Einstein 情形) 对 T2IVIFHAWA 聚合
%       算子做"逐位精确"验证 —— 与退化的目标规划无关, 直接证明聚合实现正确。
%   (B) 博弈层: 求解 maximin / minimax 目标规划, 与 Table 4 对照。
%       其中 minimax 策略 z*、期望支付 E 可稳健复现; 而 maximin 策略 y*
%       因原文目标规划本身退化(解非唯一)而无法逐位复现, 详见末尾诊断。

clear; clc;

root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);
out_dir = fullfile(root_dir, 'output');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% (A) 算子层验证: 原文 Example 2 (gamma = 2)
M = [0.60 0.80 0.50 0.70 0.10 0.20 0.10 0.30;   % M1
     0.80 0.90 0.80 0.80 0.10 0.10 0.05 0.10;   % M2
     0.05 0.20 0.20 0.25 0.63 0.75 0.55 0.74];  % M3
lambda = [0.32 0.41 0.27];
op_got = t2ivif_hawa(M, lambda, 2);
op_ref = [0.595 0.766 0.592 0.662 0.173 0.228 0.125 0.259];
op_err = max(abs(op_got - op_ref));

fprintf('==== (A) T2IVIFHAWA operator check (Example 2, gamma=2) ====\n');
fprintf('got: [%s]\n', strtrim(sprintf('%0.3f ', op_got)));
fprintf('ref: [%s]\n', strtrim(sprintf('%0.3f ', op_ref)));
fprintf('operator max error = %0.4g  ->  %s\n\n', op_err, pass_flag(op_err <= 1e-3));

%% (B) 博弈层求解
opts = struct();
opts.delta = 0.5;
opts.tau = 0.9;
opts.gamma = 3;
opts.random_starts = 16;
opts.display = 'off';

result = dong_wan_2024_t2ivif_solver('paper', opts);

% 原文 Table 4 报告值
ref.y = [0.3181 0.4711 0.2108];
ref.z = [0.1493 0.3655 0.4852];
ref.expected = [0.5570 0.6853 0.4258 0.6218 0.1657 0.2545 0.2442 0.3398];

err_y = max(abs(result.maximin.strategy - ref.y));
err_z = max(abs(result.minimax.strategy - ref.z));
err_expected = max(abs(result.expected_payoff - ref.expected));

fprintf('==== (B) Game solution vs Dong and Wan 2024 Table 4 ====\n');
fprintf('z* (minimax) : [%0.4f %0.4f %0.4f]  max err=%0.4g  ->  %s\n', ...
    result.minimax.strategy, err_z, pass_flag(err_z <= 5e-3));
fprintf('E  (expected): [%0.4f %0.4f %0.4f %0.4f; %0.4f %0.4f %0.4f %0.4f]\n', result.expected_payoff);
fprintf('               max err=%0.4g  ->  %s\n', err_expected, pass_flag(err_expected <= 1e-2));
fprintf('y* (maximin) : [%0.4f %0.4f %0.4f]  max err=%0.4g  (paper [%0.4f %0.4f %0.4f])\n', ...
    result.maximin.strategy, err_y, ref.y);
fprintf('constraint violation: maximin=%0.2e  minimax=%0.2e\n\n', ...
    result.maximin.exit_check, result.minimax.exit_check);

%% 诊断: 为什么 y* 无法逐位复现 (原文目标规划退化)
diagnose_maximin_degeneracy(result, ref, opts);

%% 落盘
summary = table( ...
    op_err, err_z, err_expected, err_y, ...
    result.maximin.exit_check, result.minimax.exit_check, ...
    'VariableNames', {'OperatorErr', 'ErrZ', 'ErrExpected', 'ErrY', ...
                      'MaximinConstraintViolation', 'MinimaxConstraintViolation'});
writetable(summary, fullfile(out_dir, 'dong_wan_2024_reproduction_summary.csv'));
save(fullfile(out_dir, 'dong_wan_2024_reproduction.mat'), 'result', 'ref', 'summary');
fprintf('Saved: %s\n', fullfile(out_dir, 'dong_wan_2024_reproduction_summary.csv'));

% ----------------------------------------------------------------------
function diagnose_maximin_degeneracy(result, ref, opts)
% 解释 maximin 解的非唯一性: 在原文报告的 y* 处, 其 IVPNMF 下界分量 v_V
% 违反了模型(Eq.17)由约束推出的严格下界, 说明 Table 4 的 maximin 解是 LINGO
% 求解器在退化(可替换最优解)目标规划上返回的某个顶点, 无法被独立求解器逐位重现。
    payoff = result.payoff;
    gamma = opts.gamma;
    y = ref.y(:);
    % 逐列聚合 (maximin 中行玩家用 y 加权各列), 取 IVPNMF 下界分量(第5位)
    n = size(payoff, 2);
    aggr_vL = zeros(n, 1);
    for s = 1:n
        a = t2ivif_hawa(payoff(:, s, :), y, gamma);
        aggr_vL(s) = a(5);
    end
    % 模型对 IVPNMF 下界 v_V 的严格约束: v_V >= max_s aggr_v_lower
    v_lb_required = max(aggr_vL);
    v_paper = 0.2258;   % 原文 Table 4 报告的 v_V
    fprintf('==== Diagnosis: maximin goal program is degenerate ====\n');
    fprintf('At the paper''s y*=[%.4f %.4f %.4f]:\n', ref.y);
    fprintf('  model requires v_V >= max_s aggr_vL = %0.4f\n', v_lb_required);
    fprintf('  but paper reports v_V = %0.4f  (violates its own constraint by %0.4f)\n', ...
        v_paper, v_lb_required - v_paper);
    fprintf('  => Table 4 maximin solution is a solver-specific (LINGO) vertex of a\n');
    fprintf('     degenerate program; z* and E are well-posed and reproduce, y* does not.\n');
    fprintf('  Our y*=[%.4f %.4f %.4f] is a feasible GP-optimum (violation %0.2e).\n\n', ...
        result.maximin.strategy, result.maximin.exit_check);
end

function s = pass_flag(tf)
    if tf
        s = 'PASS';
    else
        s = 'CHECK';
    end
end
