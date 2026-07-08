function cfg = scenario_b_config(mode)
%SCENARIO_B_CONFIG  Canonical risk-coupled Scenario B environment (single source of truth).
%
%   返回 Scenario B(系统性风险耦合压力场景) 的规范环境参数, 供 exp_5_1_2
%   (α-family Pareto/CE 前沿) 与 exp_5_1_6 (算法层 SOTA 对比) 共同引用,
%   从而保证两个实验使用完全一致、可复现的 Scenario B 环境。
%
%   双场景 (验证二维悲观族 Γ_{α,s} 自适应风险几何, 见论文 §V):
%     mode='concentrated' (v1, 默认): 风险集中——尾部冲击只打激进共享 SC，用于
%        检验 FOU 聚焦 (s>0) 是否能把悲观预算集中到高暴露策略。
%     mode='dispersed' (v2): 风险分散——尾部冲击按各策略暴露 fou_scale 随机命中任意
%        策略 (无免费安全策略)，用于检验聚焦收益是否随风险几何改变，并允许前沿
%        数据选择 s=0 或 s>0；不预设二维族必然优于专用风险基线。
%
%   口径说明:
%     本文件只固定"环境/博弈压力"参数(决定收益地形与系统性尾部风险);
%     风险偏好权重 gamma_ce 属各实验的报告口径(exp_5_1_2 用 0.50 描绘 α 前沿,
%     exp_5_1_6 用 0.55 报告 SOTA 的 CE), 不在此统一固定。
%
%   输入:
%     mode - (可选) 'concentrated'(默认, v1) 或 'dispersed'(v2)
%   输出字段(struct cfg):
%     fou_scale      - 1x4, 各策略(SC,SP,DC,DP)的 FOU 缩放系数 / 暴露权重
%     shock_strength - 标量, 系统性冲击严重度
%     p_shock        - 标量, 冲击发生概率 (v1=0.08; v2=0.20 以分散后维持威慑)
%     sigma_small    - 标量, 良性扰动标准差
%     delta          - 标量, Scenario B 的 FOU 半带宽
%     shock_mode     - 'concentrated'/'dispersed', 决定冲击目标分布 (供 payoff_stats)

if nargin < 1 || isempty(mode)
    mode = 'concentrated';
end

cfg.fou_scale      = [1.60, 1.15, 0.85, 0.70];
cfg.shock_strength = 0.30;
cfg.sigma_small    = 0.01;
cfg.delta          = 0.20;

switch mode
    case 'concentrated'        % v1: 风险集中, 冲击只打 SC
        cfg.shock_mode = 'concentrated';
        cfg.p_shock    = 0.08;
    case 'dispersed'           % v2: 风险分散, 冲击按暴露随机命中
        cfg.shock_mode = 'dispersed';
        cfg.p_shock    = 0.20;
    otherwise
        error('scenario_b_config: unknown mode "%s" (use concentrated/dispersed)', mode);
end
end
