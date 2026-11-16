function [alpha, y, logs, trace] = sec5_1_10_logged_run(bank, counts, q, cfg, mode)
%SEC5_1_10_LOGGED_RUN Simulation harness; expose only executed observations.
    n = size(bank, 1); b = cfg.block_size; held = cfg.default_index;
    alpha = zeros(n, 1); y = alpha;
    logs.counts = zeros(n, 4); logs.log_behavior = zeros(n, 1);
    trace = zeros(0, 2+2*numel(cfg.candidates));
    for first = 1:b:n
        endpast = first-1;
        update = endpast >= cfg.initial_count;
        if strcmp(mode, 'once'); update = endpast == cfg.initial_count; end
        if strcmp(mode, 'periodic')
            update = update && mod(endpast-cfg.initial_count, cfg.cycle_length) == 0;
        end
        if update
            past = max(1, first-cfg.memory_length):endpast;
            [held, scores, ess] = sec5_1_10_logged_select(logs.counts(past, :), ...
                logs.log_behavior(past), y(past), q, cfg);
            trace(end+1, :) = [endpast, held, scores, ess]; %#ok<AGROW>
        end
        times = first:min(first+b-1, n);
        alpha(times) = cfg.candidates(held);
        y(times) = bank(times, held);
        logs.counts(times, :) = counts(times, :, held);
        logs.log_behavior(times) = counts(times, :, held)*log(q(held, :)');
    end
end
