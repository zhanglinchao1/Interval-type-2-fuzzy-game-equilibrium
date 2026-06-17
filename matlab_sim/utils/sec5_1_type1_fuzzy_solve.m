function [pi_star, history] = sec5_1_type1_fuzzy_solve(params, delta, theta)
%SEC5_1_TYPE1_FUZZY_SOLVE 论文 §5.1 实验一对照方法: 一型模糊博弈
%   使用名义隶属度中心值（δ=0），不考虑区间二型不确定性
%   对比中验证: 在有扰动环境中评估一型方法的脆弱性
%
%   输入:
%       params - 参数结构体
%       delta  - 仅保留接口一致性（不使用）
%       theta  - 3×1 收益层权重
%   输出:
%       pi_star - N×4 矩阵
%       history - 收敛历史

    [pi_star, history] = sec4_3_1_wfbri_solve(params, 0, theta);
end
