%% RUN_BASIC_MPC_TESTS 一键运行基础 MPC 的全部检查
clear; clc;

basic_root = fileparts(mfilename('fullpath'));
addpath(fullfile(basic_root, 'tests'));
basic_test_results = test_basic_mpc();
