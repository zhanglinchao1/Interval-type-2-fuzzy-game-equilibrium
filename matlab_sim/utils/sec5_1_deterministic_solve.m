function [pi_star, history] = sec5_1_deterministic_solve(params, theta)
%SEC5_1_DETERMINISTIC_SOLVE 论文 §5.1 实验一对照方法: 确定性博弈
%   使用 δ=0（无区间二型不确定性），等价于经典确定性收益博弈
%
%   输入:
%       params - 参数结构体
%       theta  - 3×1 收益层权重
%   输出:
%       pi_star - N×4 矩阵
%       history - 收敛历史

    [pi_star, history] = sec4_3_1_wfbri_solve(params, 0, theta);
end
