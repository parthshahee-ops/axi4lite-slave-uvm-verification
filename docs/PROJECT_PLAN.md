# Project Plan and Verification Checklist

## Design scope
- AXI4-Lite slave peripheral
- 32-bit address and data buses
- Memory-mapped register bank
- One outstanding write and one outstanding read
- Independent read and write control paths

## Implementation sequence
1. Confirm the register map, access permissions, and reset values.
2. Implement reset and idle behavior.
3. Implement read address capture, address decode, and read response.
4. Implement independent AW/W capture and write execution.
5. Implement byte-lane updates using WSTRB.
6. Hold BVALID/RVALID and response payload stable until the relevant READY handshake.
7. Validate RTL with a small directed SystemVerilog testbench.
8. Integrate the UVM transaction, sequence, sequencer, driver, monitor, agent, scoreboard, environment, and tests.
9. Add directed scenarios and constrained-random stimulus.
10. Add protocol assertions and functional coverage.
11. Run reproducible regressions, investigate failures, and review coverage gaps.
12. Record only verified results and add supporting evidence.

## Verification matrix

| Feature | Planned test/evidence | Status |
|---|---|---|
| Reset values | Read resettable registers / inspect reset behavior | Not run |
| Basic write/read-back | Directed smoke test | Not run |
| WSTRB partial writes | Full, byte, half-word, sparse, zero strobes | Not run |
| AW/W ordering | AW-first, W-first, simultaneous arrival | Not run |
| B-channel backpressure | Hold BREADY low and check BVALID/BRESP | Not run |
| R-channel backpressure | Hold RREADY low and check RVALID/RDATA/RRESP | Not run |
| Invalid addresses | Read/write unmapped locations | Not run |
| Read-only register writes | Check SLVERR and unchanged register value | Not run |
| Assertions | VALID and payload stability, response hold, reset rules | Not run |
| Functional coverage | Review bins and cross coverage | Not run |
| Regression | Multiple seeds, logs, failures, coverage summary | Not run |

## Evidence discipline
- Do not add a passing status without a corresponding run/log.
- Record simulator name/version, test name, seed, result, and date.
- If a feature is not implemented or tested, label it planned or not run.
- Keep confidential, licensed, or employer-owned code/data out of a public repository.
