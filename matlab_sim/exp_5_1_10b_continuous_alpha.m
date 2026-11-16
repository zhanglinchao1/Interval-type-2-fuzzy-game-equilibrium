% R2-1: continuous alpha selection using recent executed-policy feedback.
% Full run from matlab_sim: exp_5_1_10b_continuous_alpha
% Smoke check (no output files): quick_mode=true; exp_5_1_10b_continuous_alpha
% Frozen protocol: dev_plan.md Section 12.3. No manuscript changes.
clearvars -except quick_mode;
if ~exist('quick_mode', 'var'); quick_mode = false; end
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
cfg.candidates = 0:.25:1; cfg.gamma = .55;
cfg.block_size = 10; cfg.initial_count = 100; cfg.cycle_length = 3000;
cfg.memory_length = 1000; cfg.exploration_probability = .10;
cfg.horizons = [12000, 300]; cfg.seeds = 2001:2020;
cfg.scenarios = {'concentrated', 'dispersed', ...
    'concentrated_to_dispersed', 'dispersed_to_concentrated'};
cfg.methods = {'Fixed 0.5', 'Calibrate once', 'Periodic calibration', ...
    'Continuous W1000', 'Once short pilot', 'Periodic short pilot', ...
    'Continuous W300', 'Continuous W3000'};
cfg.policies = {'Fixed 0.5', 'Calibrate once', 'Periodic calibration', ...
    'Continuous', 'Calibrate once', 'Periodic calibration', 'Continuous', 'Continuous'};
cfg.probes = [100, 100, 100, 10, 10, 10, 10, 10];
cfg.windows = [1000, 1000, 1000, 1000, 1000, 1000, 300, 3000];
cfg.response_blocks = 5; cfg.seconds_per_observation = 2;
if quick_mode; cfg.horizons = [800, 300]; cfg.seeds = 2001; end
verify_controllers(cfg, script_dir);

% Independent, previously completed stationary runs define evaluation targets.
old = readtable(fullfile(script_dir, 'table', 'table5_10_alpha_calibration.csv'), ...
    'TextType', 'string');
reference = old(old.SamplesPerAlpha == 100 & startsWith(old.Method, "Fixed "), ...
    {'Scenario', 'Method', 'CE'});
target = zeros(1, 2);
for j = 1:2
    g = reference(reference.Scenario == string(cfg.scenarios{j}), :);
    [~, best] = max(g.CE); target(j) = sscanf(g.Method(best), 'Fixed %f');
end
fprintf('Evaluation-only targets from independent seeds: C=%.2f, D=%.2f\n', target);

p = config_params(); env_c = scenario_b_config('concentrated');
env_d = scenario_b_config('dispersed'); p = scenario_b_env(p, env_c.fou_scale);
p.N = 50; p.lambda = .20; p.beta = .3; p.eps_tol = 1e-9;
p.rng_seed = 42; p.R_max = 1000;
cfg.delta = env_c.delta; cfg.focus_s = 0; cfg.lambda = p.lambda;
cfg.beta = p.beta; cfg.N = p.N;
profiles = cell(1, numel(cfg.candidates));
for a = 1:numel(cfg.candidates)
    [profiles{a}, h] = sec5_1_alpha_robust_solve( ...
        p, cfg.delta, p.theta, cfg.candidates(a), cfg.focus_s);
    assert(h.converged && h.fixed_point_residual < 1e-8);
end
rows = {}; example = struct(); total_clock = tic;
for seed = cfg.seeds
    seed_clock = tic; p.rng_seed = seed;
    bank_c = zeros(max(cfg.horizons), numel(cfg.candidates)); bank_d = bank_c;
    for a = 1:numel(cfg.candidates)
        p.shock_mode = 'concentrated';
        [~, ~, bank_c(:, a)] = scenario_b_payoff_stats(profiles{a}, ...
            cfg.delta, p.theta, p, max(cfg.horizons), ...
            env_c.p_shock, env_c.sigma_small, env_c.shock_strength);
        p.shock_mode = 'dispersed';
        [~, ~, bank_d(:, a)] = scenario_b_payoff_stats(profiles{a}, ...
            cfg.delta, p.theta, p, max(cfg.horizons), ...
            env_d.p_shock, env_d.sigma_small, env_d.shock_strength);
    end
    assert(all(isfinite([bank_c(:); bank_d(:)])));
    for horizon = cfg.horizons
        change_rng = RandStream('mt19937ar', 'Seed', seed+91000);
        switch_at = cfg.block_size*floor((.4+.2*rand(change_rng)) ...
            *horizon/cfg.block_size);
        for sc = 1:numel(cfg.scenarios)
            if sc == 1; bank = bank_c(1:horizon, :);
            elseif sc == 2; bank = bank_d(1:horizon, :);
            elseif sc == 3
                bank = [bank_c(1:switch_at, :); bank_d(switch_at+1:horizon, :)];
            else
                bank = [bank_d(1:switch_at, :); bank_c(switch_at+1:horizon, :)];
            end
            goal_alpha = target(1+(sc == 2 || sc == 3));
            for m = 1:numel(cfg.methods)
                run_cfg = cfg; run_cfg.memory_length = cfg.windows(m);
                controller_clock = tic;
                [a_log, y_log, explore, decisions, rec] = sec5_1_10_run_policy( ...
                    bank, cfg.policies{m}, cfg.probes(m), run_cfg, seed);
                elapsed = toc(controller_clock); after = y_log(switch_at+1:end);
                [reached, delay, capped] = response_time(a_log, switch_at, goal_alpha, cfg);
                if sc <= 2; reached = NaN; delay = NaN; capped = NaN; end
                rec_idx = sub2ind(size(bank), (1:horizon)', 1+round(4*rec));
                % Offline opportunity-cost diagnostic, never a controller input.
                alternative = bank(rec_idx);
                trial_cost = sum(alternative(explore)-y_log(explore))/horizon;
                first_decision = NaN;
                if ~isempty(decisions); first_decision = decisions(1, 1); end
                rows(end+1, :) = {cfg.scenarios{sc}, seed, horizon, cfg.methods{m}, ...
                    mean(y_log), quantile(y_log, .05), score(y_log, cfg.gamma), ...
                    mean(after), quantile(after, .05), score(after, cfg.gamma), ...
                    mean(explore), sum(diff(a_log) ~= 0), elapsed, switch_at, ...
                    goal_alpha, reached, delay, capped, ...
                    mean(rec(switch_at+1:end) == goal_alpha), ...
                    mean(a_log(switch_at+1:end) == goal_alpha), trial_cost, ...
                    first_decision, a_log(end)}; %#ok<SAGROW>
                if seed == cfg.seeds(1)
                    key = sprintf('h%d_s%d_m%d', horizon, sc, m);
                    example.(key) = struct('alpha', a_log, 'payoff', y_log, ...
                        'exploration', explore, 'recommended', rec, 'switch_at', switch_at);
                end
            end
        end
    end
    fprintf('[seed %d] all horizons/scenarios/methods: %.1f s\n', seed, toc(seed_clock));
end
raw = cell2table(rows, 'VariableNames', {'Scenario', 'Seed', 'Horizon', 'Method', ...
    'MeanPayoff', 'Q5', 'CE', 'PostMean', 'PostQ5', 'PostCE', ...
    'ExplorationFraction', 'Switches', 'ControllerSeconds', 'SwitchAt', 'TargetAlpha', ...
    'ResponseReached', 'ResponseDelayObs', 'CappedDelayObs', ...
    'PostRecommendedTargetShare', 'PostDeployedTargetShare', ...
    'ExplorationOpportunityCost', 'FirstDecisionAt', 'FinalAlpha'});
assert(height(raw) == numel(cfg.seeds)*numel(cfg.horizons)*numel(cfg.scenarios)*numel(cfg.methods));
assert(all(abs(raw.CE-((1-cfg.gamma)*raw.MeanPayoff+cfg.gamma*raw.Q5)) < 1e-12));
[summary, paired] = summarize_online(raw, cfg);
disp(summary(contains(summary.Scenario, '_to_') & ...
    ismember(summary.Method, cfg.methods(1:4)), :));
disp(paired(contains(paired.Scenario, '_to_') & ...
    ismember(paired.Baseline, cfg.methods(1:3)), :));
fprintf('[PASS] Complete paired design and CE identity. Total %.1f s\n', toc(total_clock));
if ~quick_mode
    out = fullfile(script_dir, 'table');
    writetable(raw, fullfile(out, 'table5_10b_continuous_alpha_raw.csv'));
    writetable(summary, fullfile(out, 'table5_10b_continuous_alpha.csv'));
    writetable(paired, fullfile(out, 'table5_10b_continuous_alpha_paired.csv'));
    save(fullfile(out, 'table5_10b_continuous_alpha.mat'), ...
        'cfg', 'raw', 'summary', 'paired', 'reference', 'target', 'example');
    make_online_figure(summary, paired, cfg, fullfile(script_dir, 'image'));
end

function verify_controllers(cfg, script_dir)
    old = load(fullfile(script_dir, 'table', 'table5_10_alpha_calibration.mat'), ...
        'cfg', 'example');
    for sc = 1:4
        for m = 1:numel(old.cfg.methods)
            e = old.example.(sprintf('scenario%d_method%d', sc, m));
            bank = zeros(numel(e.payoff), numel(cfg.candidates));
            idx = sub2ind(size(bank), (1:size(bank, 1))', 1+round(4*e.alpha));
            bank(idx) = e.payoff;
            [a, y, cal] = sec5_1_10_run_policy(bank, old.cfg.methods{m}, ...
                old.cfg.primary_probe, old.cfg, old.cfg.seeds(1));
            assert(isequal(a, e.alpha) && isequal(y, e.payoff) && isequal(cal, e.calibration));
        end
    end
    probe = cfg; probe.initial_count = 20; probe.memory_length = 100;
    r = RandStream('mt19937ar', 'Seed', 107); bank = rand(r, 800, 5);
    [a, y, cal, d, rec] = sec5_1_10_run_policy(bank, 'Continuous', 10, probe, 111);
    altered = 100+rand(r, size(bank));
    idx = sub2ind(size(bank), (1:size(bank, 1))', 1+round(4*a));
    altered(idx) = y;
    [aa, yy, cc, dd, rr] = sec5_1_10_run_policy(altered, 'Continuous', 10, probe, 111);
    assert(isequal(a, aa) && isequal(y, yy) && isequal(cal, cc));
    assert(isequal(d, dd) && isequal(rec, rr));
    altered = bank; altered(401:end, :) = 100;
    [aa, yy, ~, ~, rr] = sec5_1_10_run_policy(altered, 'Continuous', 10, probe, 111);
    assert(isequal(a(1:400), aa(1:400)) && isequal(y(1:400), yy(1:400)));
    assert(isequal(rec(1:400), rr(1:400)));
    probe.exploration_probability = 0; probe.memory_length = 1000;
    bank = .6*ones(800, 5); bank(1:200, 1) = .9; bank(201:end, 1) = .1;
    [a, ~, cal] = sec5_1_10_run_policy(bank, 'Continuous', 10, probe, 111);
    assert(all(a(101:200) == 0) && any(a(211:250) ~= 0));
    assert(~any(cal(71:end)));  % The response came from operating feedback.
    probe.memory_length = 100;
    [~, ~, cal] = sec5_1_10_run_policy(bank, 'Continuous', 10, probe, 111);
    assert(any(cal(171:end))); % Expired candidates receive fresh observations.
    fprintf('[PASS] 28 saved baseline trajectories, feedback isolation, causality, operating feedback, refresh.\n');
end

function [reached, delay, capped] = response_time(deployed, switch_at, target, cfg)
    reached = 0; delay = NaN; capped = numel(deployed)-switch_at;
    width = cfg.response_blocks*cfg.block_size;
    for first = switch_at+1:cfg.block_size:numel(deployed)-width+1
        if all(deployed(first:first+width-1) == target)
            reached = 1; delay = first-1-switch_at; capped = delay; return;
        end
    end
end

function v = score(y, gamma)
    v = (1-gamma)*mean(y)+gamma*quantile(y, .05);
end

function [summary, paired] = summarize_online(raw, cfg)
    sr = {}; pr = {}; stream = RandStream('mt19937ar', 'Seed', 20261108);
    for horizon = cfg.horizons
        for sc = 1:numel(cfg.scenarios)
            group = raw(raw.Horizon == horizon & strcmp(raw.Scenario, cfg.scenarios{sc}), :);
            for m = 1:numel(cfg.methods)
                g = group(strcmp(group.Method, cfg.methods{m}), :);
                sr(end+1, :) = {cfg.scenarios{sc}, horizon, cfg.methods{m}, height(g), ...
                    mean(g.MeanPayoff), mean(g.Q5), mean(g.CE), mean(g.PostCE), ...
                    mean(g.ExplorationFraction), mean(g.Switches), ...
                    sum(g.ResponseReached, 'omitnan'), median(g.ResponseDelayObs, 'omitnan'), ...
                    mean(g.CappedDelayObs, 'omitnan'), mean(g.PostDeployedTargetShare), ...
                    mean(g.ExplorationOpportunityCost), mean(g.ControllerSeconds), ...
                    median(g.FirstDecisionAt, 'omitnan')}; %#ok<AGROW>
            end
            adaptive = sortrows(group(strcmp(group.Method, 'Continuous W1000'), :), 'Seed');
            for m = [1:3, 5:8]
                base = sortrows(group(strcmp(group.Method, cfg.methods{m}), :), 'Seed');
                assert(isequal(adaptive.Seed, base.Seed));
                d = adaptive.CE-base.CE; [lo, hi] = boot_ci(d, stream);
                pd = adaptive.PostCE-base.PostCE; [pl, ph] = boot_ci(pd, stream);
                md = adaptive.MeanPayoff-base.MeanPayoff; [ml, mh] = boot_ci(md, stream);
                pr(end+1, :) = {cfg.scenarios{sc}, horizon, cfg.methods{m}, ...
                    mean(d), lo, hi, mean(pd), pl, ph, mean(md), ml, mh, ...
                    mean(adaptive.ExplorationFraction-base.ExplorationFraction), ...
                    mean(adaptive.Switches-base.Switches), ...
                    mean(adaptive.CappedDelayObs-base.CappedDelayObs, 'omitnan')}; %#ok<AGROW>
            end
        end
    end
    summary = cell2table(sr, 'VariableNames', {'Scenario', 'Horizon', 'Method', 'Seeds', ...
        'MeanPayoff', 'Q5', 'CE', 'PostCE', 'ExplorationFraction', 'MeanSwitches', ...
        'Responded', 'MedianResponseObs', 'MeanCappedResponseObs', ...
        'PostDeployedTargetShare', 'ExplorationOpportunityCost', ...
        'ControllerSeconds', 'MedianFirstDecisionObs'});
    paired = cell2table(pr, 'VariableNames', {'Scenario', 'Horizon', 'Baseline', ...
        'DeltaCE', 'CI_Low', 'CI_High', 'DeltaPostCE', 'PostCI_Low', 'PostCI_High', ...
        'DeltaMean', 'MeanCI_Low', 'MeanCI_High', 'DeltaExplorationFraction', ...
        'AdditionalSwitches', 'DeltaCappedResponseObs'});
end

function [lo, hi] = boot_ci(x, stream)
    n = numel(x); draws = randi(stream, n, n, 5000);
    means = mean(x(draws), 1); bounds = quantile(means, [.025, .975]);
    lo = bounds(1); hi = bounds(2);
end

function make_online_figure(summary, paired, cfg, image_dir)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 740]);
    tiledlayout(2, 2, 'TileSpacing', 'compact');
    labels = {'Fixed 0.5', 'Once', 'Periodic', 'Continuous'};
    for h = 1:numel(cfg.horizons)
        horizon = cfg.horizons(h); nexttile; hold on;
        for s = 1:2
            scenario = cfg.scenarios{s+2}; means = zeros(1, 3); lower = means; upper = means;
            for j = 1:3
                g = paired(paired.Horizon == horizon & strcmp(paired.Scenario, scenario) ...
                    & strcmp(paired.Baseline, cfg.methods{j}), :);
                means(j) = g.DeltaCE; lower(j) = g.CI_Low; upper(j) = g.CI_High;
            end
            errorbar((1:3)+.12*(s-1.5), means, means-lower, upper-means, 'o-', 'LineWidth', 1.2);
        end
        yline(0, 'k:'); xlim([.5, 3.5]); xticks(1:3); xticklabels(labels(1:3));
        ylabel('Full-horizon CE difference'); grid on;
        title(sprintf('Continuous minus baseline; T = %g min', horizon*2/60));
        legend({'C to D', 'D to C'}, 'Location', 'best');
    end
    nexttile; values = zeros(4, 2);
    for s = 1:2
        for j = 1:4
            g = summary(summary.Horizon == max(cfg.horizons) & ...
                strcmp(summary.Scenario, cfg.scenarios{s+2}) & strcmp(summary.Method, cfg.methods{j}), :);
            values(j, s) = 100*g.ExplorationFraction;
        end
    end
    bar(values); xticks(1:4); xticklabels(labels); ylabel('Trial / exploration fraction (%)');
    title('Long horizon: all trial windows counted'); legend({'C to D', 'D to C'}, 'Location', 'best'); grid on;
    nexttile; hold on;
    for s = 1:2
        values = zeros(1, 4);
        for j = 1:4
            g = summary(summary.Horizon == max(cfg.horizons) & ...
                strcmp(summary.Scenario, cfg.scenarios{s+2}) & strcmp(summary.Method, cfg.methods{j}), :);
            values(j) = 100*g.Responded/g.Seeds;
        end
        plot(1:4, values, 'o-', 'LineWidth', 1.2);
    end
    xticks(1:4); xticklabels(labels); ylim([0, 105]); ylabel('Sustained target deployment (%)');
    title('Long horizon: response success, including failures'); grid on;
    legend({'C to D', 'D to C'}, 'Location', 'best');
    set(findall(fig, '-property', 'FontName'), 'FontName', 'Times New Roman');
    exportgraphics(fig, fullfile(image_dir, 'fig5_22_continuous_alpha.png'), 'Resolution', 200);
    exportgraphics(fig, fullfile(image_dir, 'fig5_22_continuous_alpha.pdf'), 'ContentType', 'vector');
    close(fig);
end
