function payoff8 = adapt_to_dong_wan(U_lo, U_hi)
%ADAPT_TO_DONG_WAN 把公共区间收益 [U_lo,U_hi] 适配为 Dong & Wan (2024) 的 m×n×8 T2IVIF 张量
%
%   用途 (que.md §2.2 适配器口径): 将本文 IT2 诱导的区间收益 [U_lo,U_hi] 以
%   **退化 IVIF**(次型 FOU 置零、犹豫度置零)的方式映射为 T2IVIF, 交给
%   dong_wan_2024_t2ivif_solver 求解。这样隔离并检验其 interval-payoff 求解能力,
%   不引入额外的次隶属度信息(保持公平归约)。
%
%   分量序 (见 t2ivif_hawa): [muL,muU, fL,fU, vL,vU, gL,gU]
%       IVPMF=[muL,muU]  主隶属度区间      ← [U_lo, U_hi]
%       IVSMF=[fL,fU]    次隶属度区间      ← [U_lo, U_hi] (次型展宽=0, 退化为主)
%       IVPNMF=[vL,vU]   主非隶属度区间    ← [1−U_hi, 1−U_lo] (犹豫度=0)
%       IVSNMF=[gL,gU]   次非隶属度区间    ← [1−U_hi, 1−U_lo]
%   合法性: U_lo≤U_hi ⇒ muL≤muU, vL≤vU; 且 muU+vL=1, muL+vU=1(标准 IVFS, 无犹豫)。
%
%   输入:
%       U_lo, U_hi - m×n, 区间收益下/上界(同尺寸)
%   输出:
%       payoff8    - m×n×8 T2IVIF 张量

    [m, n] = size(U_lo);
    payoff8 = zeros(m, n, 8);
    payoff8(:, :, 1) = U_lo;        % muL
    payoff8(:, :, 2) = U_hi;        % muU
    payoff8(:, :, 3) = U_lo;        % fL (次型展宽=0)
    payoff8(:, :, 4) = U_hi;        % fU
    payoff8(:, :, 5) = 1 - U_hi;    % vL (犹豫度=0)
    payoff8(:, :, 6) = 1 - U_lo;    % vU
    payoff8(:, :, 7) = 1 - U_hi;    % gL
    payoff8(:, :, 8) = 1 - U_lo;    % gU
end
