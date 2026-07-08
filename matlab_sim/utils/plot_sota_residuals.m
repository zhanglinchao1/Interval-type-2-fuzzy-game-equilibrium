function plot_sota_residuals(trace_for_plot, img_dir, output_suffix)
%PLOT_SOTA_RESIDUALS  算法层 SOTA 收敛残差轨迹 (良性核, N=50, seed=42)。
%   trace_for_plot 为 struct, 每个字段含 .method 与 .residual。
%   抽取为共享工具, 供 exp_5_1_6 与 plot_sota_from_trace 复用,
%   使图例/样式调整无需重跑全部实验。
    fields = fieldnames(trace_for_plot);
    if isempty(fields); return; end
    fig = figure('Name', 'Algorithm-level SOTA convergence', ...
        'Position', [100, 100, 620, 400]);
    hold on;
    for i = 1:numel(fields)
        tr = trace_for_plot.(fields{i});
        r = 1:numel(tr.residual);
        [color, ~, line_style] = sota_method_style(tr.method);
        line_width = 1.8;
        if strcmp(tr.method, 'Proposed IT2-W-FBRI')
            line_width = 2.3;
        end
        plot(r, tr.residual, 'LineWidth', line_width, ...
            'Color', color, 'LineStyle', line_style, ...
            'DisplayName', tr.method);
    end
    % 停止阈值参考线 (eps_tol=1e-4): 为 "reach threshold" 提供视觉锚点,
    % 与正文 stopping-threshold 措辞及 exp_5_1_6 收敛判据 e_pi<=eps_tol 一致
    % (见 que.md [G4])。用灰色虚线、不进图例, 仅作判读基准。
    yline(1e-4, '--', '\epsilon_{tol}=10^{-4}', ...
        'Color', [0.4 0.4 0.4], 'LineWidth', 1.3, ...
        'HandleVisibility', 'off', 'Interpreter', 'tex', ...
        'LabelHorizontalAlignment', 'left', ...
        'LabelVerticalAlignment', 'bottom', 'FontSize', 10);
    hold off;
    set(gca, 'YScale', 'log');
    xlabel('Iteration r', 'FontSize', 12);
    ylabel('Strategy residual', 'FontSize', 12);
    legend('Location', 'northeast', 'FontSize', 11, 'Box', 'on');
    grid on;
    ax = gca;
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end
    % 统一字体规范 (Times New Roman / 字号), 与其它 Fig.5 系列图保持一致
    apply_fig5_publication_style(fig);
    exportgraphics(fig, fullfile(img_dir, ...
        ['fig5_16_sota_convergence' output_suffix '.pdf']), ...
        'ContentType', 'vector', 'BackgroundColor', 'white');
    exportgraphics(fig, fullfile(img_dir, ...
        ['fig5_16_sota_convergence' output_suffix '.png']), ...
        'Resolution', 200, 'BackgroundColor', 'white');
end
