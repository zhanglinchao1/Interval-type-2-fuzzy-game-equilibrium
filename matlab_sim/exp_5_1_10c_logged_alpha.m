% R2-1: logged joint actions for alpha selection, sampled-action execution.
% Default: development seeds. confirm_mode=true selects the locked holdout.
% report_only=true regenerates tables/figure from the selected saved MAT file.
clearvars -except quick_mode confirm_mode report_only;
if ~exist('quick_mode', 'var'); quick_mode = false; end
if ~exist('confirm_mode', 'var'); confirm_mode = false; end
if ~exist('report_only', 'var'); report_only = false; end
script_dir = fileparts(mfilename('fullpath')); addpath(fullfile(script_dir, 'utils'));
cfg.candidates = 0:.25:1; cfg.gamma = .55; cfg.block_size = 10;
cfg.initial_count = 100; cfg.initial_alpha = .5; cfg.default_index = 3;
cfg.cycle_length = 3000; cfg.memory_length = 300;
cfg.min_ess = 50; cfg.ess_fraction = .2; cfg.exploration_probability = .1;
cfg.horizons = [12000, 300]; cfg.seeds = 3001:3010; cfg.sizes = [50, 200];
cfg.scenarios = {'concentrated', 'dispersed', 'concentrated_to_dispersed', 'dispersed_to_concentrated'};
cfg.methods = {'Fixed 0', 'Fixed 0.25', 'Fixed 0.5', 'Fixed 0.75', 'Fixed 1', ...
    'Calibrate once', 'Periodic calibration', 'Continuous W1000', ...
    'Once short pilot', 'Periodic short pilot', 'Logged once', 'Logged periodic', 'Logged rolling'};
cfg.policies = {'Fixed 0', 'Fixed 0.25', 'Fixed 0.5', 'Fixed 0.75', 'Fixed 1', ...
    'Calibrate once', 'Periodic calibration', 'Continuous', ...
    'Calibrate once', 'Periodic calibration', 'once', 'periodic', 'rolling'};
cfg.probes = [0, 0, 0, 0, 0, 100, 100, 10, 10, 10];
suffix = '_development';
if confirm_mode; cfg.seeds = 4001:4040; suffix = ''; end
if quick_mode; cfg.seeds = 3001; cfg.horizons = [800, 300]; cfg.sizes = 50; end
envs = {scenario_b_config('concentrated'), scenario_b_config('dispersed')};
p = scenario_b_env(config_params(), envs{1}.fou_scale);
p.lambda = .20; p.beta = .3; p.eps_tol = 1e-9; p.R_max = 1000;
stem = fullfile(script_dir, 'table', ['table5_10c_logged_alpha', suffix]);
if report_only
    saved = load([stem, '.mat'], 'cfg', 'raw', 'solver', 'example');
    cfg = saved.cfg; raw = saved.raw; solver = saved.solver; example = saved.example;
else
verify_logged(cfg, p, envs, script_dir);
p.eps_tol = 1e-12; % Resolve the symmetric equilibrium before action sampling.
rows = {}; example = struct(); solver = []; total_clock = tic;
for N = cfg.sizes
    p.N = N; p.rng_seed = 42; profiles = cell(1, 5); q = zeros(5, 4);
    for a = 1:5
        watch = tic;
        [profiles{a}, h] = sec5_1_alpha_robust_solve(p, envs{1}.delta, p.theta, cfg.candidates(a), 0);
        solver(end+1, :) = [N, cfg.candidates(a), h.iterations, h.fixed_point_residual, toc(watch)]; %#ok<SAGROW>
        assert(h.converged && h.fixed_point_residual < 1e-8);
        assert(max(abs(profiles{a}-mean(profiles{a}, 1)), [], 'all') < 1e-10);
        q(a, :) = mean(profiles{a}, 1);
        profiles{a} = repmat(q(a, :), N, 1);
    end
    % Development only: original reference; confirmation uses development data.
    target = [0, 1];
    if confirm_mode
        ref = readtable(fullfile(script_dir, 'table', 'table5_10c_logged_alpha_development_raw.csv'));
        for sc = 1:2
            g = ref(ref.N == N & ref.Horizon == 12000 & strcmp(ref.Scenario, cfg.scenarios{sc}), :);
            means = arrayfun(@(a) mean(g.CE(strcmp(g.Method, cfg.methods{a}))), 1:5);
            [~, best] = max(means); target(sc) = cfg.candidates(best);
        end
    end
    for seed = cfg.seeds
        watch = tic; p.rng_seed = seed;
        [bc, cc] = sec5_1_10_sampled_bank(profiles, p, envs{1}, max(cfg.horizons));
        [bd, cd] = sec5_1_10_sampled_bank(profiles, p, envs{2}, max(cfg.horizons));
        for horizon = cfg.horizons
            st = RandStream('mt19937ar', 'Seed', seed+91000);
            switch_at = cfg.block_size*floor((.4+.2*rand(st))*horizon/cfg.block_size);
            for sc = 1:4
                if sc == 1; bank = bc(1:horizon, :); counts = cc(1:horizon, :, :);
                elseif sc == 2; bank = bd(1:horizon, :); counts = cd(1:horizon, :, :);
                elseif sc == 3
                    bank = [bc(1:switch_at, :); bd(switch_at+1:horizon, :)];
                    counts = cat(1, cc(1:switch_at, :, :), cd(switch_at+1:horizon, :, :));
                else
                    bank = [bd(1:switch_at, :); bc(switch_at+1:horizon, :)];
                    counts = cat(1, cd(1:switch_at, :, :), cc(switch_at+1:horizon, :, :));
                end
                for m = 1:numel(cfg.methods)
                    watch_controller = tic; logs = struct(); trace = []; min_ess = NaN;
                    if m <= 10
                        legacy_cfg = cfg; legacy_cfg.memory_length = 1000;
                        [alpha, y, trials] = sec5_1_10_run_policy(bank, cfg.policies{m}, cfg.probes(m), legacy_cfg, seed);
                        first_decision = NaN;
                        if m >= 6; first_decision = cfg.initial_count+5*cfg.probes(m); end
                    else
                        [alpha, y, logs, trace] = sec5_1_10_logged_run(bank, counts, q, cfg, cfg.policies{m});
                        trials = false(horizon, 1); first_decision = cfg.initial_count;
                        if ~isempty(trace); min_ess = min(trace(:, 8:end), [], 'all'); end
                    end
                    seconds = toc(watch_controller); post = y(switch_at+1:end);
                    target_alpha = target(1+(sc == 2 || sc == 3));
                    [hit, delay, capped] = response(alpha, switch_at, target_alpha, cfg.block_size);
                    if sc <= 2; hit = NaN; delay = NaN; capped = NaN; end
                    rows(end+1, :) = {N, seed, cfg.scenarios{sc}, horizon, cfg.methods{m}, ...
                        mean(y), quantile(y, .05), ce(y, cfg.gamma), ce(post, cfg.gamma), ...
                        mean(trials), sum(diff(alpha) ~= 0), seconds, switch_at, target_alpha, ...
                        hit, delay, capped, mean(alpha(switch_at+1:end) == target_alpha), ...
                        min_ess, first_decision}; %#ok<SAGROW>
                    if seed == cfg.seeds(1)
                        key = sprintf('n%d_h%d_s%d_m%d', N, horizon, sc, m);
                        example.(key) = struct('alpha', alpha, 'payoff', y, 'trials', trials, ...
                            'logs', logs, 'trace', trace, 'q', q, 'switch_at', switch_at);
                    end
                end
            end
        end
        fprintf('[N=%d seed=%d] %.1f s\n', N, seed, toc(watch));
    end
end
raw = cell2table(rows, 'VariableNames', {'N', 'Seed', 'Scenario', 'Horizon', 'Method', ...
    'MeanPayoff', 'Q5', 'CE', 'PostCE', 'TrialFraction', 'Switches', 'ControllerSeconds', ...
    'SwitchAt', 'TargetAlpha', 'ResponseReached', 'ResponseDelayObs', 'CappedDelayObs', ...
    'PostTargetShare', 'MinESS', 'FirstDecisionObs'});
assert(height(raw) == numel(cfg.sizes)*numel(cfg.seeds)*2*4*numel(cfg.methods));
assert(max(abs(raw.CE-((1-cfg.gamma)*raw.MeanPayoff+cfg.gamma*raw.Q5))) < 1e-12);
fprintf('[PASS] Complete design, full-horizon accounting. Total %.1f s.\n', toc(total_clock));
end
% A scheduled decision beyond the observation horizon has not occurred.
raw.FirstDecisionObs(raw.FirstDecisionObs > raw.Horizon) = NaN;
paired = paired_results(raw, cfg);
summary = summarize_logged(raw, cfg);
disp(paired(paired.N == 50 & contains(paired.Scenario, '_to_') & strcmp(paired.Baseline, 'Fixed 0.5'), :));
if ~quick_mode
    writetable(raw, [stem, '_raw.csv']); writetable(paired, [stem, '_paired.csv']);
    writetable(summary, [stem, '.csv']);
    save([stem, '.mat'], 'cfg', 'raw', 'paired', 'summary', 'solver', 'example');
    make_logged_figure(summary, paired, cfg, script_dir, confirm_mode);
end

function v = ce(y, gamma)
    v = (1-gamma)*mean(y)+gamma*quantile(y, .05);
end

function [hit, delay, capped] = response(alpha, switch_at, target, b)
    hit = 0; delay = NaN; capped = numel(alpha)-switch_at;
    for first = switch_at+1:b:numel(alpha)-5*b+1
        if all(alpha(first:first+5*b-1) == target)
            hit = 1; delay = first-switch_at-1; capped = delay; return;
        end
    end
end

function paired = paired_results(raw, cfg)
    rows = {}; st = RandStream('mt19937ar', 'Seed', 20261109);
    for N = cfg.sizes
        for h = cfg.horizons
            for sc = cfg.scenarios
                g = raw(raw.N == N & raw.Horizon == h & strcmp(raw.Scenario, sc{1}), :);
                adaptive = sortrows(g(strcmp(g.Method, 'Logged rolling'), :), 'Seed');
                for m = 1:numel(cfg.methods)-1
                    base = sortrows(g(strcmp(g.Method, cfg.methods{m}), :), 'Seed');
                    assert(isequal(base.Seed, adaptive.Seed));
                    d = adaptive.CE-base.CE;
                    draws = randi(st, numel(d), numel(d), 5000);
                    ci = quantile(mean(d(draws), 1), [.025, .975]);
                    rows(end+1, :) = {N, h, sc{1}, cfg.methods{m}, mean(d), ci(1), ci(2), ...
                        mean(adaptive.PostCE-base.PostCE), mean(adaptive.MeanPayoff-base.MeanPayoff)}; %#ok<AGROW>
                end
            end
        end
    end
    paired = cell2table(rows, 'VariableNames', {'N', 'Horizon', 'Scenario', 'Baseline', ...
        'DeltaCE', 'CI_Low', 'CI_High', 'DeltaPostCE', 'DeltaMean'});
end

function summary = summarize_logged(raw, cfg)
    rows = {};
    for N = cfg.sizes
        for h = cfg.horizons
            for sc = cfg.scenarios
                for method = cfg.methods
                    g = raw(raw.N == N & raw.Horizon == h & ...
                        strcmp(raw.Scenario, sc{1}) & strcmp(raw.Method, method{1}), :);
                    rows(end+1, :) = {N, h, sc{1}, method{1}, height(g), ...
                        mean(g.MeanPayoff), mean(g.Q5), mean(g.CE), mean(g.PostCE), ...
                        mean(g.TrialFraction), mean(g.Switches), mean(g.ControllerSeconds), ...
                        sum(g.ResponseReached, 'omitnan'), median(g.ResponseDelayObs, 'omitnan'), ...
                        mean(g.CappedDelayObs, 'omitnan'), mean(g.PostTargetShare), ...
                        median(g.FirstDecisionObs, 'omitnan')}; %#ok<AGROW>
                end
            end
        end
    end
    summary = cell2table(rows, 'VariableNames', {'N', 'Horizon', 'Scenario', 'Method', ...
        'Seeds', 'MeanPayoff', 'Q5', 'CE', 'PostCE', 'TrialFraction', 'MeanSwitches', ...
        'ControllerSeconds', 'Responded', 'MedianResponseObs', 'MeanCappedResponseObs', ...
        'PostTargetShare', 'MedianFirstDecisionObs'});
end

function make_logged_figure(summary, paired, cfg, script_dir, enabled)
    if ~enabled; return; end
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 760]);
    tiledlayout(2, 2, 'TileSpacing', 'compact');
    methods = {'Fixed 0.5', 'Calibrate once', 'Periodic calibration', 'Logged rolling'};
    labels = {'Fixed 0.5', 'Once', 'Periodic', 'Logged rolling'};
    for h = cfg.horizons
        nexttile; hold on;
        for s = 1:2
            g = paired(paired.N == 50 & paired.Horizon == h & ...
                strcmp(paired.Scenario, cfg.scenarios{s+2}), :);
            y = zeros(1, 3); lo = y; hi = y;
            for m = 1:3
                row = g(strcmp(g.Baseline, methods{m}), :);
                y(m) = 1000*row.DeltaCE; lo(m) = 1000*row.CI_Low; hi(m) = 1000*row.CI_High;
            end
            errorbar((1:3)+.12*(s-1.5), y, y-lo, hi-y, 'o-', 'LineWidth', 1.2);
        end
        yline(0, 'k:'); xlim([.5, 3.5]); xticks(1:3); xticklabels(labels(1:3)); grid on;
        ylabel('Full-horizon CE difference (x 10^{-3})');
        title({'Logged rolling minus baseline', sprintf('N = 50, T = %g min (2-s windows)', h/30)});
        legend({'C to D', 'D to C'}, 'Location', 'best');
    end
    nexttile; hit = zeros(4, 2); trial = zeros(4, 2); switches = zeros(4, 2);
    for s = 1:2
        for m = 1:4
            g = summary(summary.N == 50 & summary.Horizon == 12000 & ...
                strcmp(summary.Scenario, cfg.scenarios{s+2}) & strcmp(summary.Method, methods{m}), :);
            hit(m, s) = 100*g.Responded/g.Seeds; trial(m, s) = 100*g.TrialFraction;
            switches(m, s) = g.MeanSwitches;
        end
    end
    bar(hit(2:4, :)); xticks(1:3); xticklabels(labels(2:4)); ylim([0, 105]); grid on;
    ylabel('Sustained reference deployment (%)'); title('Long horizon: reference held for 50 windows');
    legend({'C to D', 'D to C'}, 'Location', 'northwest');
    nexttile; yyaxis left; bar(mean(trial, 2)); ylabel('Dedicated trial fraction (%)');
    yyaxis right; plot(1:4, mean(switches, 2), 'ko-', 'LineWidth', 1.2);
    set(gca, 'YColor', 'k');
    ylabel('Mean parameter switches'); xticks(1:4); xticklabels(labels); grid on;
    title('Long horizon: trial and switching costs');
    set(findall(fig, '-property', 'FontName'), 'FontName', 'Times New Roman');
    exportgraphics(fig, fullfile(script_dir, 'image', 'fig5_23_logged_alpha.png'), 'Resolution', 200);
    exportgraphics(fig, fullfile(script_dir, 'image', 'fig5_23_logged_alpha.pdf'), 'ContentType', 'vector');
    close(fig);
end

function verify_logged(cfg, p, envs, script_dir)
    % Exact joint-propensity identity, including opponents, on all 4^3 actions.
    [a, b, c] = ndgrid(1:4); action = [a(:), b(:), c(:)];
    counts = zeros(64, 4);
    for j = 1:4; counts(:, j) = sum(action == j, 2); end
    behavior = [.1, .2, .3, .4]; target = [.4, .3, .2, .1];
    pb = exp(counts*log(behavior')); pt = exp(counts*log(target'));
    weights = exp(counts*log(target'./behavior'));
    rewards = sin(action(:, 1)+2*action(:, 2)+action(:, 3).^2);
    assert(max(abs(pb.*weights-pt)) < 1e-14);
    for y = unique(rewards)'
        assert(abs(sum(pb.*weights.*(rewards <= y))-sum(pt.*(rewards <= y))) < 1e-13);
    end
    % The refactored shock sampler must reproduce saved original trajectories.
    old = load(fullfile(script_dir, 'table', 'table5_10_alpha_calibration.mat'), 'example');
    p.N = 50; p.rng_seed = 42;
    pi = sec5_1_alpha_robust_solve(p, envs{1}.delta, p.theta, .5, 0);
    p.rng_seed = 1001;
    for sc = 1:2
        p.shock_mode = envs{sc}.shock_mode;
        [~, ~, y] = scenario_b_payoff_stats(pi, envs{sc}.delta, p.theta, p, 200, ...
            envs{sc}.p_shock, envs{sc}.sigma_small, envs{sc}.shock_strength);
        saved = old.example.(sprintf('scenario%d_method3', sc)).payoff;
        assert(max(abs(y-saved(1:200))) < 1e-12);
    end
    q = repmat(behavior, 5, 1); st = RandStream('mt19937ar', 'Seed', 2026);
    y = rand(st, 64, 1);
    [~, score] = sec5_1_10_logged_select(counts, counts*log(behavior'), y, q, cfg);
    assert(max(abs(score-ce(y, cfg.gamma))) < 1e-12);
    q = [behavior; .8*behavior+.2*target; .5*(behavior+target); .2*behavior+.8*target; target];
    bank = rand(st, 400, 5); cnt = zeros(400, 4, 5);
    for a = 1:5
        u = rand(st, 400, 3); cuts = cumsum(q(a, :));
        actions = 1+(u > cuts(1))+(u > cuts(2))+(u > cuts(3));
        for j = 1:4; cnt(:, j, a) = sum(actions == j, 2); end
    end
    [alpha, y, logs, trace] = sec5_1_10_logged_run(bank, cnt, q, cfg, 'rolling');
    changed = 10+bank; changed_counts = 3*ones(size(cnt));
    for t = 1:400
        a = 1+round(4*alpha(t)); changed(t, a) = y(t);
        changed_counts(t, :, a) = logs.counts(t, :);
    end
    [aa, yy, ll, tt] = sec5_1_10_logged_run(changed, changed_counts, q, cfg, 'rolling');
    assert(isequal(alpha, aa) && isequal(y, yy) && isequal(logs, ll) && isequal(trace, tt));
    changed = bank; changed(201:end, :) = 10;
    [aa, yy] = sec5_1_10_logged_run(changed, cnt, q, cfg, 'rolling');
    assert(isequal(alpha(1:200), aa(1:200)) && isequal(y(1:200), yy(1:200)));
    fprintf('[PASS] Joint-action identity, original sampler regression, equal-weight quantile, feedback isolation and causality.\n');
end
