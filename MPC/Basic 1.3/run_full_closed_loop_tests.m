%% RUN_FULL_CLOSED_LOOP_TESTS Run both 24-hour rolling controllers.
clear; clc;
basic_root = fileparts(mfilename('fullpath'));
addpath(fullfile(basic_root,'tests'));
full_test_results = test_basic_1_3_full();
