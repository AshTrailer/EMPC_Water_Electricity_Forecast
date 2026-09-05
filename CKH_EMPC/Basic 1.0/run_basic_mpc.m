%% RUN_BASIC_MPC 基础约束水箱 MPC 的演示入口
clear; close all; clc;

basic_root = fileparts(mfilename('fullpath'));
addpath(basic_root);
addpath(fullfile(basic_root, 'controller'));
addpath(fullfile(basic_root, 'interfaces'));
addpath(fullfile(basic_root, 'scenarios'));
addpath(fullfile(basic_root, 'simulation'));

config = basic_mpc_config();
basic_results = simulate_basic_mpc(config, 'periodic', 72, true);

fprintf('基础 MPC 已完成，共运行 %d 小时。\n', ...
    numel(basic_results.u_actual));
fprintf('水位范围：%.3f 至 %.3f m。\n', ...
    min(basic_results.level), max(basic_results.level));
fprintf('MPC期望指令范围：%.3f 至 %.3f。\n', ...
    min(basic_results.u_request), max(basic_results.u_request));
fprintf('Decision实际指令范围：%.3f 至 %.3f。\n', ...
    min(basic_results.u_actual), max(basic_results.u_actual));
