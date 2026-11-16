% Reviewer 2, comment 1: calibration using executed-policy feedback.
% Full run from matlab_sim: exp_5_1_10_alpha_calibration
% Smoke check, no output files: quick_mode=true; exp_5_1_10_alpha_calibration
% Reuses W-FBRI and Scenario-B payoff generation. The simulator privately
% caches potential outcomes; the selector sees ONLY deployed-policy rewards.
% Startup/calibration observations are included in full-horizon metrics.
% Scope: memoryless mean-field payoff simulation, without physical queue,
% reputation carryover, communication cost, or a time-varying-graph proof.

clearvars -except quick_mode;
if ~exist('quick_mode', 'var'); quick_mode = false; end
script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
cfg.candidates = 0:0.25:1; cfg.gamma = .55;
cfg.n_probe = [50, 100, 300]; cfg.primary_probe = 100;
cfg.block_size = 10; cfg.initial_count = 100;
cfg.cycle_length = 3000; cfg.horizon = 12000;
cfg.seeds = 1001:1020;
cfg.scenarios = {'concentrated', 'dispersed', ...
    'concentrated_to_dispersed', 'dispersed_to_concentrated'};
cfg.methods = {'Fixed 0', 'Fixed 0.25', 'Fixed 0.5', 'Fixed 0.75', ...
    'Fixed 1', 'Calibrate once', 'Periodic calibration'};
if quick_mode
    cfg.n_probe = [10, 20]; cfg.primary_probe = 20;
    cfg.initial_count = 20; cfg.cycle_length = 200;
    cfg.horizon = 800; cfg.seeds = 1001;
end
assert(all(mod(cfg.n_probe, cfg.block_size) == 0));
assert(max(cfg.n_probe)*numel(cfg.candidates) < cfg.cycle_length);

p = config_params();
env_c = scenario_b_config('concentrated');
env_d = scenario_b_config('dispersed');
p = scenario_b_env(p, env_c.fou_scale);
p.N = 50; p.lambda = .20; p.beta = .3; p.eps_tol = 1e-9;
p.rng_seed = 42; p.R_max = 1000;
cfg.delta = env_c.delta; cfg.focus_s = 0;
cfg.lambda = p.lambda; cfg.beta = p.beta; cfg.N = p.N;
profiles = cell(1, numel(cfg.candidates));
solver_rows = zeros(numel(cfg.candidates), 5);
for a = 1:numel(cfg.candidates)
    solver_clock = tic;
    [profiles{a}, h] = sec5_1_alpha_robust_solve( ...
        p, cfg.delta, p.theta, cfg.candidates(a), cfg.focus_s);
    elapsed = toc(solver_clock);
    assert(h.converged && h.fixed_point_residual < 1e-8);
    solver_rows(a, :) = [cfg.candidates(a), h.iterations, ...
        h.fixed_point_residual, h.eps_ne, elapsed];
end
solver_table = array2table(solver_rows, 'VariableNames', ...
    {'Alpha', 'Rounds', 'FixedPointResidual', 'Exploitability', 'SolveSeconds'});
verify_feedback_boundary(cfg);
fprintf('[PASS] Feedback isolation, future-prefix invariance, sample counts.\n');

rows = {}; decisions = {}; example = struct(); reference_rows = {};
for seed = cfg.seeds
    seed_clock = tic;
    p.rng_seed = seed;
    % Potential outcomes are private simulator data, never selector inputs.
    bank_c = zeros(cfg.horizon, numel(cfg.candidates)); bank_d = bank_c;
    for a = 1:numel(cfg.candidates)
        p.shock_mode = 'concentrated';
        [e, q, bank_c(:, a)] = scenario_b_payoff_stats( ...
            profiles{a}, cfg.delta, p.theta, p, cfg.horizon, ...
            env_c.p_shock, env_c.sigma_small, env_c.shock_strength);
        assert(abs(e-mean(bank_c(:, a))) < 1e-12);
        assert(abs(q-quantile(bank_c(:, a), .05)) < 1e-12);
        p.shock_mode = 'dispersed';
        [~, ~, bank_d(:, a)] = scenario_b_payoff_stats( ...
            profiles{a}, cfg.delta, p.theta, p, cfg.horizon, ...
            env_d.p_shock, env_d.sigma_small, env_d.shock_strength);
    end
    assert(all(isfinite([bank_c(:); bank_d(:)])));
    assert(min([bank_c(:); bank_d(:)]) >= 0 && max([bank_c(:); bank_d(:)]) <= 1);
    switch_rng = RandStream('mt19937ar', 'Seed', seed+91000);
    switch_at = cfg.block_size*floor((.4+.2*rand(switch_rng)) ...
        * cfg.horizon/cfg.block_size);
    for sc = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios{sc};
        if sc == 1
            bank = bank_c;
        elseif sc == 2
            bank = bank_d;
        elseif sc == 3
            bank = [bank_c(1:switch_at, :); bank_d(switch_at+1:end, :)];
        else
            bank = [bank_d(1:switch_at, :); bank_c(switch_at+1:end, :)];
        end
        for a = 1:numel(cfg.candidates)
            reference_rows(end+1, :) = {scenario, seed, cfg.candidates(a), ...
                score(bank(:, a), cfg.gamma), ...
                score(bank(switch_at+1:end, a), cfg.gamma)}; %#ok<SAGROW>
        end
        for n_probe = cfg.n_probe
            for m = 1:numel(cfg.methods)
                method = cfg.methods{m}; controller_clock = tic;
                [a_log, y_log, cal_log, decision_log] = sec5_1_10_run_policy( ...
                    bank, method, n_probe, cfg, seed);
                controller_seconds = toc(controller_clock);
                after = y_log(switch_at+1:end);
                rows(end+1, :) = {scenario, seed, n_probe, method, ...
                    mean(y_log), quantile(y_log, .05), score(y_log, cfg.gamma), ...
                    mean(after), quantile(after, .05), score(after, cfg.gamma), ...
                    mean(cal_log), sum(diff(a_log) ~= 0), a_log(end), ...
                    controller_seconds, switch_at}; %#ok<SAGROW>
                for d = 1:size(decision_log, 1)
                    decisions(end+1, :) = [{scenario, seed, n_probe, method}, ...
                        num2cell(decision_log(d, :))]; %#ok<SAGROW>
                end
                if seed == cfg.seeds(1) && n_probe == cfg.primary_probe
                    key = sprintf('scenario%d_method%d', sc, m);
                    example.(key) = struct('alpha', a_log, 'payoff', y_log, ...
                        'calibration', cal_log, 'switch_at', switch_at);
                end
            end
        end
    end
    fprintf('[seed %d] all scenarios/budgets completed, %.1f s\n', seed, toc(seed_clock));
end
raw = cell2table(rows, 'VariableNames', {'Scenario', 'Seed', 'SamplesPerAlpha', ...
    'Method', 'MeanPayoff', 'Q5', 'CE', 'PostMean', 'PostQ5', 'PostCE', ...
    'CalibrationFraction', 'Switches', 'FinalAlpha', 'ControllerSeconds', 'SwitchAt'});
choices = cell2table(decisions, 'VariableNames', {'Scenario', 'Seed', ...
    'SamplesPerAlpha', 'Method', 'DecisionAt', 'SelectedAlpha', 'SelectedScore', ...
    'Score0', 'Score025', 'Score05', 'Score075', 'Score1'});
reference = cell2table(reference_rows, 'VariableNames', ...
    {'Scenario', 'Seed', 'Alpha', 'FullCE', 'PostCE'});
[summary, paired] = summarize_results(raw, cfg);
assert(height(raw) == numel(cfg.seeds)*numel(cfg.scenarios) ...
    * numel(cfg.n_probe)*numel(cfg.methods));
fprintf('[PASS] Complete paired design; calibration observations included.\n');
disp(summary(summary.SamplesPerAlpha == cfg.primary_probe & ...
    ismember(summary.Method, {'Fixed 0', 'Fixed 0.5', 'Calibrate once', ...
    'Periodic calibration'}), :));
disp(paired(paired.SamplesPerAlpha == cfg.primary_probe, :));
if ~quick_mode
    out = fullfile(script_dir, 'table');
    writetable(raw, fullfile(out, 'table5_10_alpha_calibration_raw.csv'));
    writetable(summary, fullfile(out, 'table5_10_alpha_calibration.csv'));
    writetable(paired, fullfile(out, 'table5_10_alpha_calibration_paired.csv'));
    writetable(choices, fullfile(out, 'table5_10_alpha_calibration_choices.csv'));
    writetable(solver_table, fullfile(out, 'table5_10_alpha_calibration_solver.csv'));
    save(fullfile(out, 'table5_10_alpha_calibration.mat'), ...
        'cfg', 'raw', 'summary', 'paired', 'choices', 'reference', 'example', 'solver_table');
    make_figure(paired, example, cfg, fullfile(script_dir, 'image'));
    fprintf('Saved table5_10_alpha_calibration* and fig5_21_alpha_calibration.\n');
end

function verify_feedback_boundary(cfg)
    probe = cfg; probe.initial_count = 20; probe.cycle_length = 200;
    probe.horizon = 800; n_probe = 20;
    r = RandStream('mt19937ar', 'Seed', 107);
    bank = rand(r, probe.horizon, numel(cfg.candidates));
    [a, y, ~, d] = sec5_1_10_run_policy(bank, 'Periodic calibration', n_probe, probe, 111);
    altered = 100+rand(r, size(bank));
    idx = sub2ind(size(bank), (1:size(bank, 1))', 1+round(4*a));
    altered(idx) = y;                  % preserve only the actually observed data
    [aa, yy, ~, dd] = sec5_1_10_run_policy(altered, 'Periodic calibration', n_probe, probe, 111);
    assert(isequal(a, aa) && isequal(y, yy) && isequal(d, dd));
    altered = bank; altered(401:end, :) = 100;
    [aa, yy] = sec5_1_10_run_policy(altered, 'Periodic calibration', n_probe, probe, 111);
    assert(isequal(a(1:400), aa(1:400)) && isequal(y(1:400), yy(1:400)));
    obs_a = repelem(cfg.candidates, 20)'; obs_y = 1-abs(obs_a-.5);
    selected = sec5_1_10_select_alpha(obs_a, obs_y, cfg.candidates, cfg.gamma);
    assert(selected == .5);
end

function v = score(y, gamma)
    v = (1-gamma)*mean(y) + gamma*quantile(y, .05);
end

function [summary, paired] = summarize_results(raw, cfg)
    sr = {}; pr = {};
    boot_rng = RandStream('mt19937ar', 'Seed', 20261108);
    for sc = 1:numel(cfg.scenarios)
        for n_probe = cfg.n_probe
            group = raw(strcmp(raw.Scenario, cfg.scenarios{sc}) & ...
                raw.SamplesPerAlpha == n_probe, :);
            for m = 1:numel(cfg.methods)
                g = sortrows(group(strcmp(group.Method, cfg.methods{m}), :), 'Seed');
                [lo, hi] = boot_ci(g.CE, boot_rng);
                sr(end+1, :) = {cfg.scenarios{sc}, n_probe, cfg.methods{m}, ...
                    height(g), mean(g.MeanPayoff), mean(g.Q5), mean(g.CE), lo, hi, ...
                    mean(g.PostCE), mean(g.CalibrationFraction), mean(g.Switches), ...
                    mean(g.ControllerSeconds)}; %#ok<AGROW>
            end
            adaptive = sortrows(group(strcmp(group.Method, 'Periodic calibration'), :), 'Seed');
            for baseline = {'Fixed 0', 'Fixed 0.5', 'Fixed 1', 'Calibrate once'}
                base = sortrows(group(strcmp(group.Method, baseline{1}), :), 'Seed');
                assert(isequal(adaptive.Seed, base.Seed));
                delta = adaptive.CE-base.CE;
                [lo, hi] = boot_ci(delta, boot_rng);
                [pl, ph] = boot_ci(adaptive.PostCE-base.PostCE, boot_rng);
                pr(end+1, :) = {cfg.scenarios{sc}, n_probe, baseline{1}, ...
                    mean(delta), lo, hi, mean(adaptive.PostCE-base.PostCE), pl, ph, ...
                    mean(adaptive.Switches-base.Switches)}; %#ok<AGROW>
            end
        end
    end
    summary = cell2table(sr, 'VariableNames', {'Scenario', 'SamplesPerAlpha', ...
        'Method', 'Seeds', 'MeanPayoff', 'Q5', 'CE', 'CE_CI_Low', 'CE_CI_High', ...
        'PostCE', 'CalibrationFraction', 'MeanSwitches', 'ControllerSeconds'});
    paired = cell2table(pr, 'VariableNames', {'Scenario', 'SamplesPerAlpha', ...
        'Baseline', 'DeltaCE', 'CI_Low', 'CI_High', 'DeltaPostCE', ...
        'PostCI_Low', 'PostCI_High', 'AdditionalSwitches'});
end

function [lo, hi] = boot_ci(x, stream)
    n = numel(x); draws = randi(stream, n, n, 5000);
    means = mean(x(draws), 1); bounds = quantile(means, [.025, .975]);
    lo = bounds(1); hi = bounds(2);
end

function make_figure(paired, example, cfg, image_dir)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 430]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile; hold on; colors = lines(numel(cfg.n_probe));
    for j = 1:numel(cfg.n_probe)
        g = paired(paired.SamplesPerAlpha == cfg.n_probe(j) & ...
            strcmp(paired.Baseline, 'Calibrate once'), :);
        errorbar((1:4)+.12*(j-2), g.DeltaCE, g.DeltaCE-g.CI_Low, ...
            g.CI_High-g.DeltaCE, 'o-', 'Color', colors(j, :), 'LineWidth', 1.2);
    end
    yline(0, 'k:'); xlim([.6, 4.4]); xticks(1:4);
    xticklabels({'C', 'D', 'C to D', 'D to C'});
    ylabel('CE difference: periodic minus once'); grid on;
    legend(compose('n = %d per candidate', cfg.n_probe), 'Location', 'southoutside');
    title('(a) All observations included; paired 95% bootstrap CI');
    nexttile; hold on;
    once = example.scenario3_method6; periodic = example.scenario3_method7;
    sample = 1:cfg.block_size:cfg.horizon;
    stairs(sample, once.alpha(sample), '--', 'LineWidth', 1);
    stairs(sample, periodic.alpha(sample), '-', 'LineWidth', 1);
    xline(periodic.switch_at, 'k:', 'Hidden regime change');
    xlabel('Observation index'); ylabel('Deployed alpha'); ylim([-.05, 1.1]);
    title(sprintf('(b) C to D; seed %d; n = %d', cfg.seeds(1), cfg.primary_probe));
    legend({'Calibrate once', 'Periodic calibration'}, 'Location', 'southoutside');
    grid on; set(findall(fig, '-property', 'FontName'), 'FontName', 'Times New Roman');
    exportgraphics(fig, fullfile(image_dir, 'fig5_21_alpha_calibration.png'), 'Resolution', 200);
    exportgraphics(fig, fullfile(image_dir, 'fig5_21_alpha_calibration.pdf'), 'ContentType', 'vector');
    close(fig);
end
