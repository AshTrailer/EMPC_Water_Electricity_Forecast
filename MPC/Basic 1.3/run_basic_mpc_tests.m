%% RUN_BASIC_MPC_TESTS Run short Basic 1.3 checks and one 288-step MILP.
clear; clc;
basic_root = fileparts(mfilename('fullpath'));
addpath(fullfile(basic_root,'tests'));
basic_test_results = test_basic_1_3_unit();
