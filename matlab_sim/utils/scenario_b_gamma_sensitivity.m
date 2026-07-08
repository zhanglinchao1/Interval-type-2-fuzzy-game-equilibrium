function [wide, dominance] = scenario_b_gamma_sensitivity(raw_table, ...
    gamma_list, proposed_name)
%SCENARIO_B_GAMMA_SENSITIVITY  CE_gamma 风险权重敏感性 (Scenario B, §5.1).
%   对已保存的逐种子 (ExpectedPayoff, WorstCaseQ5) 做精确 CE_gamma 线性变换
%       CE_gamma = (1-gamma)*E[U] + gamma*WC_Q5,
%   检验主文头条 CE_0.55 是否依赖单一 gamma 选取。CE 关于 (E,WC) 线性, 故无需
%   重跑仿真即可在多个 gamma 下复算排名与配对显著性。
%
%   输入:
%       raw_table     - run_scenario_b_sota 产出的逐种子表 (含 Method/Seed/
%                       Class/ExpectedPayoff/WorstCaseQ5)
%       gamma_list    - 风险权重向量 (如 [0.30 0.40 0.55 0.70 0.85])
%       proposed_name - 本文方法名 (默认 'Proposed IT2-W-FBRI')
%   输出:
%       wide      - 每方法在各 gamma 下 CE_gamma 的均值与 95% CI (宽表,
%                   供 supplementary 排名表)
%       dominance - 每 (gamma, learner) 的 Proposed-learner 配对差与 95% CI,
%                   仅针对 Class=='Learning' 的对手, 用于"对所有学习法占优"判定

    if nargin < 3 || isempty(proposed_name)
        proposed_name = 'Proposed IT2-W-FBRI';
    end

    methods = unique(raw_table.Method, 'stable');
    seeds = unique(raw_table.Seed);
    ng = numel(gamma_list);

    % --- wide: method x gamma 的 CE 均值 + CI ---
    classes = cell(numel(methods), 1);
    wide = table(methods, 'VariableNames', {'Method'});
    ce_cols = zeros(numel(methods), ng);
    ci_cols = zeros(numel(methods), ng);
    for m = 1:numel(methods)
        mask = strcmp(raw_table.Method, methods{m});
        E = raw_table.ExpectedPayoff(mask);
        WC = raw_table.WorstCaseQ5(mask);
        classes{m} = raw_table.Class{find(mask, 1)};
        for g = 1:ng
            ce = (1 - gamma_list(g)) * E + gamma_list(g) * WC;
            ce_cols(m, g) = mean(ce);
            ci_cols(m, g) = ci95_local(ce);
        end
    end
    wide.Class = classes;
    for g = 1:ng
        gname = sprintf('CE_g%03d', round(gamma_list(g) * 100));
        wide.(gname) = ce_cols(:, g);
        wide.([gname '_CI95']) = ci_cols(:, g);
    end

    % --- dominance: Proposed - each external SOTA, paired over seeds, per gamma ---
    % 外部 SOTA 对手 = 非本文 Proposed、非家族端点(Worst-case): 即收敛赛道
    % (OGDA/OMWU/EG) + 鲁棒赛道 (RQE/CVaR-game)。
    learner_idx = find(~strcmp(classes, 'Proposed') & ...
        ~strcmp(classes, 'Family endpoint'));
    rows = cell(numel(learner_idx) * ng, 6);
    r = 1;
    for g = 1:ng
        gamma = gamma_list(g);
        for li = 1:numel(learner_idx)
            base = methods{learner_idx(li)};
            diffs = NaN(numel(seeds), 1);
            for s = 1:numel(seeds)
                pm = strcmp(raw_table.Method, proposed_name) & ...
                    raw_table.Seed == seeds(s);
                bm = strcmp(raw_table.Method, base) & ...
                    raw_table.Seed == seeds(s);
                if any(pm) && any(bm)
                    ce_p = (1 - gamma) * raw_table.ExpectedPayoff(pm) + ...
                        gamma * raw_table.WorstCaseQ5(pm);
                    ce_b = (1 - gamma) * raw_table.ExpectedPayoff(bm) + ...
                        gamma * raw_table.WorstCaseQ5(bm);
                    diffs(s) = ce_p - ce_b;
                end
            end
            d = diffs(~isnan(diffs));
            half = ci95_local(d);
            lo = mean(d) - half;
            hi = mean(d) + half;
            rows(r, :) = {gamma, base, mean(d), lo, hi, ~(lo <= 0 && hi >= 0)};
            r = r + 1;
        end
    end
    dominance = cell2table(rows, 'VariableNames', ...
        {'Gamma', 'Learner', 'ProposedMinusLearnerCE', 'CI95Low', ...
         'CI95High', 'CIExcludesZero'});
end

function c = ci95_local(x)
    x = x(~isnan(x));
    if numel(x) <= 1
        c = 0;
    else
        c = 1.96 * std(x) / sqrt(numel(x));
    end
end
