% Reproduce the SOMG examples from Kumar and Garg (Ann. Oper. Res., 2025).
% This script implements the paper's two-level fuzzy set approach for
% triangular fuzzy payoff matrix games with fuzzy goals and fuzzy payoffs.

clear; clc;
root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);
out_dir = fullfile(root_dir, 'output');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

example41 = zeros(2, 2, 3);
example41(:, :, 1) = [175 150; 80 175];
example41(:, :, 2) = [180 156; 90 180];
example41(:, :, 3) = [190 158; 100 190];
res41 = kumar_garg_2025_solver('solve_somg', example41);

water = zeros(3, 3, 3);
water(:, :, 1) = [165 145 110; 75 165 160; 145 160 90];
water(:, :, 2) = [170 151 140; 86 170 165; 155 165 100];
water(:, :, 3) = [180 153 170; 90 180 175; 165 175 110];
res43 = kumar_garg_2025_solver('solve_somg', water);

case_name = ["Example 4.1"; "Water 4.3"];
vbar = [res41.vbar; res43.vbar];
v = [res41.v; res43.v];
lambda = [res41.player1.lambda; res43.player1.lambda];
eta = [res41.player2.eta; res43.player2.eta];
runtime_note = ["two-level fmincon LP"; "two-level fmincon LP"];
paper_v2_note = [ ...
    "paper V2=(0.1632,0.8368,0.2593) is a misprint; two-level optimum is (0.1864,0.8136,0.2498)"; ...
    "matches paper V2 (0.3232,0,0.6767,0.3993) within rounding"];
summary = table(case_name, vbar, v, lambda, eta, runtime_note, paper_v2_note, ...
    'VariableNames', {'CaseName', 'Vbar', 'V', 'LambdaV1', 'EtaV2', ...
    'Solver', 'PaperV2Note'});

writetable(summary, fullfile(out_dir, 'kumar_garg_2025_reproduction_summary.csv'));
save(fullfile(out_dir, 'kumar_garg_2025_reproduction.mat'), ...
    'res41', 'res43', 'summary');

disp(summary);
disp('Example 4.1 V1 strategy and lambda:');
disp([res41.player1.strategy, res41.player1.lambda]);
disp('Example 4.1 V2 strategy and eta:');
disp([res41.player2.strategy, res41.player2.eta]);
disp('Water 4.3 V1 strategy and lambda:');
disp([res43.player1.strategy, res43.player1.lambda]);
disp('Water 4.3 V2 strategy and eta:');
disp([res43.player2.strategy, res43.player2.eta]);

% ---- 诊断: Example 4.1 的 V2 在原文中报告有误 ----
% 原文(§4.1)只给结论 (y1,y2,eta)=(0.1632,0.8368,0.2593), 未展示 V2 的两层推导。
% 本求解器严格按原文自身的两层模型(55)-(56)求解, 得到 (0.1864,0.8136,0.2498)。
% 三项独立证据表明出错的是原文而非代码:
%   1) Level I 最优点由约束相等解析求得: (66+24*y1)/102.67 = 90*(1-y1)/106.67
%      => y1 = 0.18644, 与求解器一致;
%   2) 同一段 V2 代码对水资源 3x3 算例给出 (0.3232,0,0.6767,0.3993), 与原文
%      Eq.(64)后报告的 V2 逐位吻合, 反证 V2 两层实现正确;
%   3) 将原文 y=(0.1632,0.8368) 代入定理 5 的精确分式收益, 行成就度最小值为
%      0.2275 (<其自报 0.2593), 即原文 (y, eta) 自相矛盾。
y_paper = [0.1632, 0.8368];
ach_paper = example41_v2_achievement(example41, res41.vbar, res41.v, y_paper);
ach_code = example41_v2_achievement(example41, res41.vbar, res41.v, ...
    res41.player2.strategy);
fprintf('\n==== Diagnosis: Example 4.1 V2 paper value is inconsistent ====\n');
fprintf('  paper  y*=[%.4f %.4f]: exact min-row achievement eta = %.4f (paper claims 0.2593)\n', ...
    y_paper, ach_paper);
fprintf('  solver y*=[%.4f %.4f]: exact min-row achievement eta = %.4f (two-level optimum)\n', ...
    res41.player2.strategy, ach_code);
fprintf('  => solver value is strictly better and self-consistent; paper V2 is a misprint.\n');

function eta = example41_v2_achievement(tfn, vbar, v, y)
% 按定理 5 的精确分式收益(无两层近似)计算 V2 各行成就度并取最小值。
% 对每一行 i: frac_i = (vbar - sum_j a^l_ij y_j) / (sum_j (a_ij - a^l_ij) y_j + (vbar - v))
% V2 的成就度 eta = min_i frac_i (各行成就度的下确界)。
lower = tfn(:, :, 1);
modal = tfn(:, :, 2);
y = y(:);
num = vbar - lower * y;
den = (modal - lower) * y + (vbar - v);
eta = min(num ./ den);
end
