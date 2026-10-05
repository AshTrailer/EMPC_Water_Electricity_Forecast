# Basic 1.3: Three-Pump Economic MPC

Basic 1.3 implements a rolling-horizon economic MPC for one water tank and three fixed-flow pumps. At every five-minute control interval, it solves a mixed-integer linear program (MILP), executes only the first pump command, updates the measured tank level, and solves again with a new 24-hour horizon.

This version extends Basic 1.2 from one binary pump to three independently controlled binary pumps. The controller chooses among all eight pump combinations while enforcing hard tank-level limits and accounting for electricity and switching costs.

## Control workflow

```text
Historical price window + Richmond demand profile + current tank level
                              |
                              v
              24-hour three-pump MILP (intlinprog)
                              |
                              v
                First pump-state command [P1 P2 P3]
                              |
                              v
                  Mock Decision module execution
                              |
                              v
                    Tank-level state update
                              |
                              +---- repeat every five minutes
```

## Model

The tank model is

```text
x(k+1) = x(k) + dt/A * (q(k) - d(k))
q(k)   = q1*u1(k) + q2*u2(k) + q3*u3(k)
```

where each pump command `uj(k)` is binary. The optimization minimizes electricity cost and pump transitions:

```text
J = sum_k price(k) * energy(k) + switch_cost * sum_{k,j} |uj(k)-uj(k-1)|
```

Tank-level bounds are hard constraints at every predicted step. There is no terminal-level equality or flow-tracking penalty.

## Default configuration

| Item | Value |
|---|---:|
| Control interval | 5 minutes |
| Prediction horizon | 288 steps (24 hours) |
| Tank area | 1000 m^2 |
| Tank-level bounds | 1.40 to 3.37 m |
| Initial level | 2.30 m |
| Pump flows | 0.050, 0.030, 0.020 m^3/s |
| Pump powers | 43, 27, 19 kW |
| Switching penalty | 0.20 AUD per pump transition |
| Historical test day | 2026-02-09, VIC1 |

The pump values are synthetic test parameters and are not claimed to be measured Richmond pump data. Water demand uses the configured Richmond Pruned hourly multiplier pattern with a base demand of 0.025 m^3/s. AEMO `TOTALDEMAND` is electrical demand and is not used as water demand.

## Requirements

- MATLAB with Optimization Toolbox
- `intlinprog`

## Run

Open this directory in MATLAB and run:

```matlab
run_basic_mpc
```

This performs a 24-hour closed-loop simulation with 288 rolling MILP solves and writes `Basic_1_3_multi_pump_closed_loop.png`.

Run the short deterministic checks and one complete 288-step optimization:

```matlab
run_basic_mpc_tests
```

Run the full closed-loop comparison between all three pumps and P1 only:

```matlab
run_controller_comparison
```

or run the same full tests without regenerating the comparison plot:

```matlab
run_full_closed_loop_tests
```

The full comparison performs 288 rolling optimizations for each controller and can take substantially longer than the unit test.

## Main files

| Path | Purpose |
|---|---|
| `basic_mpc_config.m` | Tank, pump, demand, horizon, solver, and cost parameters |
| `controller/constrained_tank_mpc.m` | Builds and solves the three-pump MILP |
| `controller/pump_state_to_mode.m` | Maps three binary pump states to modes 0-7 |
| `simulation/simulate_basic_mpc.m` | Runs the rolling closed-loop simulation |
| `interfaces/mpc_to_decision_request.m` | Packages the first MPC action for Decision |
| `interfaces/mock_decision_optimizer.m` | Ideal temporary executor for the requested pump state |
| `scenarios/load_historical_price_data.m` | Loads and validates the bundled VIC1 price data |
| `scenarios/make_richmond_demand_series.m` | Expands the hourly water-demand profile to five-minute data |
| `tests/test_basic_1_3_unit.m` | Deterministic mode, cost, constraint, and horizon checks |
| `tests/test_basic_1_3_full.m` | Full three-pump versus P1-only closed-loop validation |

## Outputs

The simulation records pump requests and execution, flow, power, tank level, energy cost, switching cost, solver status, solve time, rolling-window indices, and mass-balance residuals. The included PNG files show the multi-pump closed-loop result and the controller comparison.

## Current limitations

- Historical future prices are supplied as perfect forecasts. This validates the controller, timing, and constraints; it does not validate the live price predictor.
- The Decision module is a mock executor that follows the requested pump states exactly.
- Pump flow and power are fixed and do not vary with head or efficiency curves.
- The demand profile and pump parameters are scenario values, not field-validated plant measurements.
- No terminal inventory constraint is imposed, so cost comparisons must report final level and pumped volume alongside total cost.
