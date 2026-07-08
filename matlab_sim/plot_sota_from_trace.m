% plot_sota_from_trace.m
% Redraw the Module-5 SOTA convergence figure (fig5-16) from the persisted
% trace MAT file without rerunning the full algorithm-level experiment.

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(script_dir, 'utils'));
tbl_dir = fullfile(script_dir, 'table');
img_dir = fullfile(script_dir, 'image');

if ~exist('output_suffix', 'var')
    output_suffix = '';
end

trace_path = fullfile(tbl_dir, ['table5_6_sota_trace' output_suffix '.mat']);

if exist(trace_path, 'file')
    S = load(trace_path, 'trace_for_plot');
    plot_sota_residuals(S.trace_for_plot, img_dir, output_suffix);
else
    fprintf('[MISS] %s\n', trace_path);
end
