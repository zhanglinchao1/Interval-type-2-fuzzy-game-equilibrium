% run_all.m - 一键运行论文 §5.1 MATLAB 算法层仿真
% 运行前请确保 matlab_sim/ 目录结构完整

clear; clc; close all;

%% 添加路径（基于脚本绝对路径，避免当前工作目录依赖）
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
cd(script_dir);  % 切换到脚本目录，保证 run() 能找到子脚本

fprintf('============================================================\n');
fprintf('  区间二型模糊博弈均衡 MATLAB 算法层仿真\n');
fprintf('  论文 §5.1 算法层实验\n');
fprintf('============================================================\n\n');

%% 环境验证
params = config_params();
fprintf('环境验证通过: N=%d, |S|=%d, K=%d\n\n', ...
    params.N, params.num_strategies, params.K);

%% 实验一: W-FBRI 收敛性与算法对比
fprintf('▶ 运行实验一 (论文 §5.1 实验一) ...\n');
run('exp_5_1_1_convergence.m');
fprintf('\n\n');

%% 实验一-b: 熵温度与非正则化可利用性
fprintf('▶ 运行实验一-b (lambda--exploitability 审计) ...\n');
run('exp_5_1_1b_lambda_exploitability.m');
fprintf('\n\n');

%% 实验二: α-cut 与 IT2 鲁棒性
fprintf('▶ 运行实验二 (论文 §5.1 实验二) ...\n');
run('exp_5_1_2_robustness.m');
fprintf('\n\n');

%% 实验三: 双时间尺度稳定性
fprintf('▶ 运行实验三 (论文 §5.1 实验三) ...\n');
run('exp_5_1_3_dual_timescale.m');
fprintf('\n\n');

%% 实验四: 均衡路径关于 α 的正则性 (定理 3 实证)
fprintf('▶ 运行实验四 (论文 §5.1 实验四) ...\n');
run('exp_5_1_4_alpha_path.m');
fprintf('\n\n');

%% 实验五: 外部基线对照 (KM/EKM 迭代 + Type-1 求解链)
fprintf('▶ 运行实验五 (论文 §5.1 实验五) ...\n');
run('exp_5_1_5_external_baselines.m');
fprintf('\n\n');

%% 实验六: 算法层 SOTA 对比
fprintf('▶ 运行实验六 (Module 5 算法层 SOTA 对比) ...\n');
run('exp_5_1_6_sota_algorithm_baselines.m');
fprintf('\n\n');

%% 实验七: 受限区间表示下的 IT2 中心分离 (Route C 曲率聚合证据)
fprintf('▶ 运行实验七 (论文 §5.1 实验七 中心分离) ...\n');
run('exp_5_1_7_it2_center_separation.m');
fprintf('\n\n');

%% 实验八: 模糊/区间博弈文献基线
fprintf('▶ 运行实验八 (模糊/区间博弈 SOTA 对比) ...\n');
run('exp_5_1_8_fuzzy_game_sota.m');

fprintf('\n============================================================\n');
fprintf('  全部实验完成！\n');
fprintf('  图片输出目录: %s\n', fullfile(script_dir, 'image'));
fprintf('  表格输出目录: %s\n', fullfile(script_dir, 'table'));
fprintf('============================================================\n');
