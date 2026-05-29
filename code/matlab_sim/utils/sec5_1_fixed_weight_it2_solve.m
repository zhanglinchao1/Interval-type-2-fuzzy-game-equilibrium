function [pi_star, history] = sec5_1_fixed_weight_it2_solve(params, delta)
%SEC5_1_FIXED_WEIGHT_IT2_SOLVE 论文 §5.1 实验一对照方法: 固定权重 IT2
%   使用区间二型收益但固定 θ 为均匀分布（不通过治理调整权重）
%
%   输入:
%       params - 参数结构体
%       delta  - 不确定性半带宽
%   输出:
%       pi_star - N×4 矩阵
%       history - 收敛历史

    theta_fixed = ones(3,1) / 3;
    [pi_star, history] = sec4_3_1_wfbri_solve(params, delta, theta_fixed);
end
