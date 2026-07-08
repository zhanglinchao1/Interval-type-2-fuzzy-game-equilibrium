% test_mallozzi_vidalpuga_2023_reproduction.m
% Mallozzi and Vidal-Puga (FSS 2023) 复现的验收测试。
% 逐条断言原文算例中明确陈述的均衡判定结果。

clear; clc;
root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir);

run(fullfile(root_dir, 'run_mallozzi_vidalpuga_2023_reproduction.m'));

%% Example 3.1: (down,right) 是 lNe 但不是 tNe (原文 Sec.3)
% 行 up=1,down=2; 列 left=1,right=2
assert(ismember_profile(res31.loose_nash, [2 2]), ...
    'Example 3.1 says (down,right) is a loose Nash equilibrium.');
assert(~ismember_profile(res31.tight_nash, [2 2]), ...
    'Example 3.1 says (down,right) is NOT a tight Nash equilibrium.');
% 该例完整 loose Nash 集为 {(up,right),(down,right)}, tight Nash 集为空
assert_profiles_equal(res31.loose_nash, [1 2; 2 2], 'Example 3.1 loose Nash');
assert(isempty(res31.tight_nash), 'Example 3.1 has no tight Nash equilibrium.');

%% Example 5.1: loose Hurwicz Nash 严格小于 loose Nash (原文 Fig.4)
expected_lne_51 = [1 1; 1 2; 2 1; 3 1];
expected_lhne_51 = [2 1; 3 1];
assert_profiles_equal(res51.loose_nash, expected_lne_51, 'Example 5.1 loose Nash');
assert_profiles_equal(res51.loose_hurwicz_nash, expected_lhne_51, ...
    'Example 5.1 loose Hurwicz Nash');
assert_profiles_equal(res51.interior_hurwicz_nash, expected_lhne_51, ...
    'Example 5.1 interior Hurwicz Nash');

%% Example 5.2: (up,left) 是 lHNe(eta=0) 但非 lNe、非 iHNe (原文 Fig.5)
assert(~ismember_profile(res52.loose_nash, [1 1]), ...
    'Example 5.2 says (up,left) is not a loose Nash equilibrium.');
assert(ismember_profile(res52.loose_hurwicz_nash, [1 1]), ...
    'Example 5.2 says (up,left) is a loose Hurwicz Nash equilibrium.');
assert(~ismember_profile(res52.interior_hurwicz_nash, [1 1]), ...
    'Example 5.2 rules out (up,left) as an interior Hurwicz equilibrium.');

%% Example 6.1: 无稳定纯均衡, 需混合策略, 混合 iHNe 为 p=q=1/2 (原文 Fig.9)
% 原文 prose 称"无 lNe 也无 lHNe", 但按 Def 5.2 字面定义(允许边界 eta), 4 个
% 纯组合各以 eta=0 或 1 满足 lHNe(与原文 Example 5.2 承认的边界 lHNe 同构),
% 故代码报告 lHNe=4。原文真正成立且有意义的论断是: 无 lNe、无 tNe、无 *interior*
% Hurwicz Nash, 因而必须借助混合策略。下面断言这些忠实于定义的结果。
assert(isempty(res61pure.tight_nash), 'Example 6.1 has no tight Nash equilibrium.');
assert(isempty(res61pure.loose_nash), 'Example 6.1 has no loose Nash equilibrium.');
assert(isempty(res61pure.interior_hurwicz_nash), ...
    'Example 6.1 has no interior (stable) Hurwicz Nash equilibrium.');
% 任何 lHNe 都必须是边界 eta(非 interior): lHNe \ iHNe == lHNe
assert(size(res61pure.loose_hurwicz_nash, 1) >= 1 && ...
    isempty(res61pure.interior_hurwicz_nash), ...
    'Example 6.1 loose Hurwicz Nash equilibria must all be boundary-eta.');
assert(abs(res61.p_row1 - 0.5) < 1e-10, 'Example 6.1 expected p=1/2.');
assert(abs(res61.q_col1 - 0.5) < 1e-10, 'Example 6.1 expected q=1/2.');
assert(res61.mixed_residual < 1e-10, 'Example 6.1 mixed residual must be zero.');

%% Sec.6 三角(alpha-依赖)判例: (2,0,2) 与 (3,2,0) 都不是 iHNe (原文末)
% 该断言检验代码对非区间(alpha 变化)模糊收益的处理路径。
assert(isempty(res62.interior_hurwicz_nash), ...
    'Sec.6 triangular case: neither profile is an interior Hurwicz Nash equilibrium.');
assert(isempty(res62.loose_hurwicz_nash), ...
    'Sec.6 triangular case: no loose Hurwicz Nash equilibrium (alpha-crossover at 0.5).');
assert(size(res62.loose_nash, 1) == 2, ...
    'Sec.6 triangular case: both profiles are loose Nash (payoffs incomparable).');

fprintf('Mallozzi-VidalPuga 2023 reproduction checks passed.\n');

% ----------------------------------------------------------------------
function assert_profiles_equal(actual, expected, label)
actual = sortrows(actual);
expected = sortrows(expected);
if ~isequal(actual, expected)
    disp(actual);
    disp(expected);
    error('%s profiles do not match the paper statement.', label);
end
end

function tf = ismember_profile(profiles, profile)
if isempty(profiles)
    tf = false;
    return;
end
tf = any(all(profiles == profile, 2));
end
