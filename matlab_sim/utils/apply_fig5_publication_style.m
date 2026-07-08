function apply_fig5_publication_style(fig_handle)
%APPLY_FIG5_PUBLICATION_STYLE Apply the global MATLAB figure text style.
%   All generated plot text uses Times New Roman at 12 pt before export.

    if nargin < 1 || isempty(fig_handle)
        fig_handle = gcf;
    end

    global_font_size = 12;
    global_font_name = 'Times New Roman';

    set(fig_handle, 'Color', 'w');

    font_objs = findall(fig_handle, '-property', 'FontSize');
    for idx = 1:numel(font_objs)
        try
            font_objs(idx).FontSize = global_font_size;
            if isprop(font_objs(idx), 'FontName')
                font_objs(idx).FontName = global_font_name;
            end
            if isprop(font_objs(idx), 'FontWeight')
                font_objs(idx).FontWeight = 'normal';
            end
        catch
            % Some graphics proxy objects expose FontSize but reject writes.
        end
    end

    axes_objs = findall(fig_handle, 'Type', 'Axes');
    for idx = 1:numel(axes_objs)
        ax = axes_objs(idx);
        try
            ax.FontSize = global_font_size;
            ax.FontName = global_font_name;
            ax.LineWidth = max(ax.LineWidth, 0.9);
            ax.XLabel.FontSize = global_font_size;
            ax.YLabel.FontSize = global_font_size;
            ax.Title.FontSize = global_font_size;
            ax.XLabel.FontName = global_font_name;
            ax.YLabel.FontName = global_font_name;
            ax.Title.FontName = global_font_name;
            ax.XLabel.FontWeight = 'bold';
            ax.YLabel.FontWeight = 'bold';
            ax.Title.FontWeight = 'normal';
        catch
        end
    end

    drawnow;
end
