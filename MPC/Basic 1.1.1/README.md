# Basic 1.1.1

Price-driven receding-horizon control for one tank and one fixed-flow binary pump.

- Five-minute intervals and a 24-hour prediction horizon.
- Hard tank-level bounds and electricity plus switching costs.
- Exact dynamic programming for the single-pump model.
- Historical VIC1 prices bundled for reproducible offline validation.
- Mock Decision executor; real pump-combination integration remains future work.

## Run

In MATLAB, open this directory and run `run_basic_mpc`.
Run `run_basic_mpc_tests` for deterministic and historical integration checks.
Run `run_two_day_comparison` for the two-day offline schedule comparison.

Historical future prices are supplied as known inputs in these experiments. This is an offline perfect-price-information benchmark, not a live predictor integration. Water demand is a separate constant scenario, not AEMO electrical demand. No terminal inventory target is imposed.

The existing PDF is retained under its original filename `mpc_basic_1_1.pdf`; the MATLAB source defines this version's behavior.
