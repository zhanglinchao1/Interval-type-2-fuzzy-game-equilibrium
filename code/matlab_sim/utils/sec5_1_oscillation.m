function osc = sec5_1_oscillation(x_hist, T_w)
%SEC5_1_OSCILLATION 论文 §5.1 实验三 策略震荡幅度 (末窗口平均, 公式 (5.1.3))
%   Osc(x; T_w) = (1/T_w) Σ_{t=T-T_w}^{T-1} ||x(t+1)-x(t)||_1
%
%   设计: 末窗口而非全窗口, 排除瞬态影响, 只衡量稳态附近的振荡。
%         缺省 T_w 为全长 T-1 (向后兼容旧调用)。
%
%   输入:
%       x_hist - T×4 矩阵, 策略分布时间序列
%       T_w    - (可选) 末窗口长度, 默认 T-1 (全窗口); 实验三推荐 round(0.2*T)
%   输出:
%       osc    - 标量, 末窗口平均震荡幅度

    T = size(x_hist, 1);
    if T < 2
        osc = 0;
        return;
    end

    diffs = sum(abs(diff(x_hist, 1, 1)), 2);   % (T-1)×1
    if nargin < 2 || isempty(T_w) || T_w >= T - 1
        osc = mean(diffs);
    else
        T_w = max(1, round(T_w));
        osc = mean(diffs(end - T_w + 1:end));
    end
end
