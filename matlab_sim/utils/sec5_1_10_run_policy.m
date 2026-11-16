function [a_log, y_log, cal_log, decisions, recommended] = ...
    sec5_1_10_run_policy(bank, method, n_probe, cfg, seed)
%SEC5_1_10_RUN_POLICY Simulation harness with executed-feedback-only selection.
%   Only this harness owns the potential-outcome bank. Neither selection rule
%   receives unexecuted outcomes, regime labels, or a change-point location.
    n = size(bank, 1); k = numel(cfg.candidates); b = cfg.block_size;
    a_log = zeros(n, 1); y_log = a_log; recommended = a_log;
    cal_log = false(n, 1); held = 0;
    if isfield(cfg, 'initial_alpha'); held = cfg.initial_alpha; end
    decisions = zeros(ceil(n/b), 3+k); decision_count = 0;
    fixed = startsWith(method, 'Fixed');
    continuous = strcmp(method, 'Continuous');
    if fixed; held = sscanf(method, 'Fixed %f'); end
    schedule_rng = RandStream('mt19937ar', 'Seed', seed+73000);
    cal_alpha = zeros(k*n_probe, 1); cal_y = cal_alpha; order = [];
    if continuous; order = randperm(schedule_rng, k); end
    for first = 1:b:n
        times = first:min(first+b-1, n); calibrating = false;
        if continuous && first > cfg.initial_count
            phase = (first-cfg.initial_count-1)/b;
            if phase < k
                chosen = cfg.candidates(order(phase+1));
                calibrating = true;
            else
                past = max(1, first-cfg.memory_length):first-1;
                counts = arrayfun(@(a) sum(a_log(past) == a), cfg.candidates);
                missing = find(counts == 0, 1);
                if ~isempty(missing)
                    chosen = cfg.candidates(missing);
                    calibrating = true;
                else
                    [held, estimates] = sec5_1_10_select_alpha( ...
                        a_log(past), y_log(past), cfg.candidates, cfg.gamma);
                    chosen = held;
                    if rand(schedule_rng) < cfg.exploration_probability
                        chosen = cfg.candidates(randi(schedule_rng, k));
                        calibrating = true;
                    end
                    decision_count = decision_count+1;
                    decisions(decision_count, :) = [first-1, held, ...
                        max(estimates), estimates];
                end
            end
        elseif ~fixed && ~continuous && first > cfg.initial_count
            offset = mod(first-cfg.initial_count-1, cfg.cycle_length);
            round_id = floor((first-cfg.initial_count-1)/cfg.cycle_length);
            active = strcmp(method, 'Periodic calibration') || round_id == 0;
            if active && offset == 0
                cal_alpha = zeros(k*n_probe, 1); cal_y = cal_alpha;
                order = zeros(1, k*n_probe/b);
                for r = 1:n_probe/b
                    order((r-1)*k+(1:k)) = randperm(schedule_rng, k);
                end
            end
            calibrating = active && offset < k*n_probe;
            if calibrating; chosen = cfg.candidates(order(offset/b+1));
            else; chosen = held; end
        else
            chosen = held;
        end
        col = find(cfg.candidates == chosen, 1);
        y = bank(times, col);  % The only outcomes exposed to the controller.
        a_log(times) = chosen; y_log(times) = y; cal_log(times) = calibrating;
        recommended(times) = held;
        if calibrating && ~continuous
            idx = offset+(1:numel(times));
            cal_alpha(idx) = chosen; cal_y(idx) = y;
            if offset+numel(times) == k*n_probe
                [held, estimates, counts] = sec5_1_10_select_alpha( ...
                    cal_alpha, cal_y, cfg.candidates, cfg.gamma);
                assert(all(counts == n_probe));
                decision_count = decision_count+1;
                decisions(decision_count, :) = [times(end), held, ...
                    max(estimates), estimates];
            end
        end
    end
    decisions = decisions(1:decision_count, :);
end
