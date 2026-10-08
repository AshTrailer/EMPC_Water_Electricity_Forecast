function test_results = test_basic_mpc(include_full)
%TEST_BASIC_MPC Compatibility entry point for Basic 1.3 tests.
if nargin < 1, include_full = false; end
test_results.unit = test_basic_1_3_unit();
if include_full
    test_results.full = test_basic_1_3_full();
end
end
