%% RUN_BASIC_MPC_TESTS Run all Basic 1.2 rolling-MPC checks
clear; clc;

basic_root = fileparts(mfilename('fullpath'));
addpath(fullfile(basic_root, 'tests'));
basic_test_results = test_basic_mpc();
