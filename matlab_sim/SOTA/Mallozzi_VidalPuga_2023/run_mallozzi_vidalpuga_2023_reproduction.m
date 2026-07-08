% run_mallozzi_vidalpuga_2023_reproduction.m
% 复现 Mallozzi and Vidal-Puga (FSS 458:94-107, 2023)《Equilibrium and
% dominance in fuzzy games》的核心判定结果。
%
% 该文以定义/定理为主, 不含数值最优化。本脚本在原文给出的算例上实现并校验
% 其发表的均衡概念:
%   - tight Nash (tNe, Def 3.1)            : 任何单方偏离都(弱)更差
%   - loose Nash (lNe, Def 3.1)            : 没有单方偏离(严格)更优
%   - Hurwicz Nash (HNe, Thm 5.1 = tNe)
%   - loose / interior Hurwicz Nash (Def 5.2/5.3): 存在 eta in [0,1] / (0,1)
%   - 混合 interior Hurwicz Nash (Sec 6)   : 对称模糊收益的混合均衡
%
% 覆盖算例: Example 3.1 (tNe!=lNe)、5.1、5.2、6.1。

clear; clc;
root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);
out_dir = fullfile(root_dir, 'output');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% Example 3.1: 展示 tight Nash 严格小于 loose Nash
example31 = build_example_3_1();
res31 = mallozzi_vidalpuga_2023_solver('pure_equilibria', example31);

% Example 5.1: loose Hurwicz Nash 严格小于 loose Nash
example51 = build_example_5_1();
res51 = mallozzi_vidalpuga_2023_solver('pure_equilibria', example51);

% Example 5.2: loose Hurwicz Nash (eta=0) 但非 loose Nash、非 interior
example52 = build_example_5_2();
res52 = mallozzi_vidalpuga_2023_solver('pure_equilibria', example52);

% Example 6.1: 无纯策略均衡, 但存在混合 interior Hurwicz Nash (p=q=1/2)
example61 = build_example_6_1();
res61pure = mallozzi_vidalpuga_2023_solver('pure_equilibria', example61);
res61 = mallozzi_vidalpuga_2023_solver( ...
    'fixed_hurwicz_2x2', example61, [0.5, 0.5], 0.5);

% Sec.6 三角收益判例: u1(up,center)=(2,0,2), u1(down,center)=(3,2,0)。
% 二者皆非 iHNe(原文末)。该例用于检验代码的 alpha-依赖路径与三角隶属。
example62 = build_example_6_2_triangular();
res62 = mallozzi_vidalpuga_2023_solver('pure_equilibria', example62);

%% 汇总
case_name = ["Example 3.1"; "Example 5.1"; "Example 5.2"; "Example 6.1"];
tight_nash_count = [size(res31.tight_nash, 1); size(res51.tight_nash, 1); ...
    size(res52.tight_nash, 1); size(res61pure.tight_nash, 1)];
loose_nash_count = [size(res31.loose_nash, 1); size(res51.loose_nash, 1); ...
    size(res52.loose_nash, 1); size(res61pure.loose_nash, 1)];
loose_hurwicz_count = [size(res31.loose_hurwicz_nash, 1); ...
    size(res51.loose_hurwicz_nash, 1); size(res52.loose_hurwicz_nash, 1); ...
    size(res61pure.loose_hurwicz_nash, 1)];
interior_hurwicz_count = [size(res31.interior_hurwicz_nash, 1); ...
    size(res51.interior_hurwicz_nash, 1); size(res52.interior_hurwicz_nash, 1); ...
    size(res61pure.interior_hurwicz_nash, 1)];
mixed_p = [NaN; NaN; NaN; res61.p_row1];
mixed_q = [NaN; NaN; NaN; res61.q_col1];
mixed_residual = [NaN; NaN; NaN; res61.mixed_residual];

summary = table(case_name, tight_nash_count, loose_nash_count, ...
    loose_hurwicz_count, interior_hurwicz_count, mixed_p, mixed_q, mixed_residual, ...
    'VariableNames', {'CaseName', 'TightNashCount', 'LooseNashCount', ...
    'LooseHurwiczCount', 'InteriorHurwiczCount', 'MixedP', 'MixedQ', 'MixedResidual'});

writetable(summary, fullfile(out_dir, 'mallozzi_vidalpuga_2023_reproduction_summary.csv'));
save(fullfile(out_dir, 'mallozzi_vidalpuga_2023_reproduction.mat'), ...
    'res31', 'res51', 'res52', 'res61', 'res61pure', 'res62', 'summary');

disp(summary);
fprintf('\n-- Example 3.1: (down,right) is lNe but not tNe --\n');
disp('loose Nash profiles (rows=[up;down], cols=[left;right]):');
disp(res31.loose_nash);
disp('tight Nash profiles:');
disp(res31.tight_nash);
fprintf('-- Example 5.1: loose Hurwicz Nash profiles --\n');
disp(res51.loose_hurwicz_nash);
fprintf('-- Example 5.2: loose Hurwicz Nash profiles --\n');
disp(res52.loose_hurwicz_nash);
fprintf('-- Sec.6 triangular case (alpha-dependent payoffs) --\n');
fprintf('(2,0,2) vs (3,2,0): pure (tNe/lNe/lHNe/iHNe) counts = (%d/%d/%d/%d)\n', ...
    size(res62.tight_nash, 1), size(res62.loose_nash, 1), ...
    size(res62.loose_hurwicz_nash, 1), size(res62.interior_hurwicz_nash, 1));
fprintf('-- Example 6.1: no stable pure equilibrium; mixed iHNe [row; col] --\n');
fprintf('pure (tNe/lNe/lHNe/iHNe) counts = (%d/%d/%d/%d)\n', ...
    size(res61pure.tight_nash, 1), size(res61pure.loose_nash, 1), ...
    size(res61pure.loose_hurwicz_nash, 1), size(res61pure.interior_hurwicz_nash, 1));
fprintf(['note: paper prose says "no lNe nor lHNe"; by Def 5.2 (boundary eta\n' ...
    '      allowed, as paper itself uses in Example 5.2) the 4 profiles are\n' ...
    '      boundary lHNe. The substantive, reproduced facts are: no lNe, no tNe,\n' ...
    '      no interior Hurwicz Nash -> mixing is required.\n']);
disp(res61.mixed_profile);

% ----------------------------------------------------------------------
function game = build_example_3_1()
% Fig.2: u1: up,left=3 up,right=[1,3] down,left=4 down,right=2
%        u2: up,left=3 up,right=4    down,left=1 down,right=2
p1_lo = [3 1; 4 2];
p1_hi = [3 3; 4 2];
p2_lo = [3 4; 1 2];
p2_hi = p2_lo;
game.action_counts = [2 2];
game.payoffs = { ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p1_lo, p1_hi), ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p2_lo, p2_hi)};
end

function game = build_example_5_1()
p1_lo = [1 1; 0 0; 3 3];
p1_hi = [4 4; 5 5; 3 3];
p2_lo = [1 1; 1 0; 1 0];
p2_hi = p2_lo;
game.action_counts = [3 2];
game.payoffs = { ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p1_lo, p1_hi), ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p2_lo, p2_hi)};
end

function game = build_example_5_2()
p1_lo = [0 0; 0 0];
p1_hi = [0 0; 1 0];
p2_lo = [1 0; 1 0];
p2_hi = p2_lo;
game.action_counts = [2 2];
game.payoffs = { ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p1_lo, p1_hi), ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p2_lo, p2_hi)};
end

function game = build_example_6_1()
p1_lo = [0 0; 0 0];
p1_hi = [0 1; 1 0];
p2_lo = [0 0; 0 0];
p2_hi = [1 0; 0 1];
game.action_counts = [2 2];
game.payoffs = { ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p1_lo, p1_hi), ...
    mallozzi_vidalpuga_2023_solver('interval_payoff', p2_lo, p2_hi)};
end

function game = build_example_6_2_triangular()
% A1={up,down}, A2={center}. 三角收益 (b,l,r):
%   u1(up,center)=(2,0,2) -> alpha-cut [2, 4-2a]; u1(down,center)=(3,2,0) -> [1+2a, 3]
% player 2 仅一个动作, 收益取常数(不影响均衡判定)。
center1 = [2; 3]; lspread1 = [0; 2]; rspread1 = [2; 0];
center2 = [0; 0]; spread2 = [0; 0];
game.action_counts = [2 1];
game.payoffs = { ...
    mallozzi_vidalpuga_2023_solver('triangular_payoff', center1, lspread1, rspread1), ...
    mallozzi_vidalpuga_2023_solver('triangular_payoff', center2, spread2, spread2)};
end
