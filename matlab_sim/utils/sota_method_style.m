function [color, marker, line_style] = sota_method_style(method)
%SOTA_METHOD_STYLE  Fixed visual styles for algorithm-level SOTA methods.
%   Keep method colors stable across Fig. 5-16 and Fig. 5-17.
    % 线型按赛道分组: 本文方法/收敛赛道 SOTA 实线, 鲁棒赛道 SOTA 虚线,
    % 家族端点参照点划; 便于在 Fig.5-16 中一眼区分"收敛 vs 鲁棒 vs 端点"。
    switch char(method)
        case 'Proposed IT2-W-FBRI'      % 本文方法: 蓝, 实线 (主角)
            color = [0.0000 0.4470 0.7410];
            marker = 'p';
            line_style = '-';
        % --- 收敛赛道 SOTA: 暖色系 + 实线 ---
        case 'OGDA'
            color = [0.8500 0.3250 0.0980];
            marker = 'o';
            line_style = '-';
        case 'Isobe-APP'                 % 收敛赛道: 正则化 mean-field last-iterate
            color = [0.9290 0.6940 0.1250];
            marker = 's';
            line_style = '-';
        case 'OMWU'                      % (降级引用, 不在主表; 样式保留供诊断脚本)
            color = [0.9290 0.6940 0.1250];
            marker = 's';
            line_style = '-';
        case 'Extragradient'             % (降级引用, 不在主表)
            color = [0.4940 0.1840 0.5560];
            marker = '^';
            line_style = '-';
        % --- 鲁棒赛道 SOTA: 冷色系 + 虚线 ---
        case 'RQE'
            color = [0.4660 0.6740 0.1880];
            marker = 'v';
            line_style = '--';
        case 'MF-RQE'                    % 鲁棒赛道: mean-field 风险厌恶 quantal
            color = [0.4940 0.1840 0.5560];
            marker = '^';
            line_style = '--';
        case 'CVaR-game'
            color = [0.3010 0.7450 0.9330];
            marker = '>';
            line_style = '--';
        case 'DRNE-VI'                   % 鲁棒赛道: 分布鲁棒 Nash via VI (CVaR 模糊集)
            color = [0.0000 0.5000 0.5000];
            marker = '<';
            line_style = '--';
        % --- 本文 Γ_{α,s} 家族端点参照: 暗红/黑, 点划 ---
        case 'Worst-case Robust'
            color = [0.6350 0.0780 0.1840];
            marker = 'd';
            line_style = ':';
        case 'Hurwicz-fixed'
            color = [0.0000 0.0000 0.0000];
            marker = 'x';
            line_style = ':';
        otherwise
            color = [0.3500 0.3500 0.3500];
            marker = 'o';
            line_style = '-';
    end
end
