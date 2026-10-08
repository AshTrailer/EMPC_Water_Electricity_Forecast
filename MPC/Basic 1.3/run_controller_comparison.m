%% RUN_CONTROLLER_COMPARISON Fair rolling Multi-pump versus P1-only run.
% Both controllers use identical price, demand, initial level, bounds,
% horizon and simulation length. Final level and pumped volume are reported
% because no terminal-level equality is imposed.
clear; clc;
basic_root = fileparts(mfilename('fullpath'));
addpath(fullfile(basic_root,'tests'), fullfile(basic_root,'simulation'));
comparison_results = test_basic_1_3_full();
comparison_plot_file = fullfile(basic_root, ...
    'Basic_1_3_controller_comparison.png');
plot_controller_comparison(comparison_results, comparison_plot_file);
