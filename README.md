# AXI4-Lite Slave Verification using SystemVerilog & UVM

A learning and verification project focused on designing a memory-mapped AXI4-Lite slave and verifying its behavior using SystemVerilog, UVM, assertions, constrained-random stimulus, and coverage analysis.

> **Project status:** In development. Planned features and results in this README are goals, not claims of completed verification. This README will be updated as implementation and testing progress.

## Objectives

- Implement a 32-bit AXI4-Lite slave with a memory-mapped register bank.
- Handle the five independent AXI4-Lite channels: AW, W, B, AR, and R.
- Support byte-strobe (`WSTRB`) writes and correct `VALID`/`READY` handshaking.
- Build a reusable UVM testbench with sequences, sequencer, driver, monitor, agent, scoreboard, environment, and tests.
- Exercise channel ordering, backpressure, reset behavior, and invalid/read-only accesses.
- Add SystemVerilog Assertions (SVA), functional coverage, and regression testing.

## Planned Scope

| Item | Planned configuration |
|---|---|
| Protocol | AXI4-Lite |
| Address width | 32 bits |
| Data width | 32 bits |
| Outstanding transactions | One write and one read |
| Response behavior | `OKAY` and `SLVERR` |
| Verification | SystemVerilog, UVM, SVA, simulation and coverage |

The final register map, reset behavior, supported simulator, and test results will be documented after they are confirmed against the implementation.

## Verification Focus

- Basic reset, register reads, writes, and read-back
- Independent AW and W channel ordering (AW first, W first, and simultaneous)
- Full, partial, sparse, and zero `WSTRB` values
- Backpressure on write and read responses
- Invalid addresses and writes to read-only registers
- VALID/payload stability while waiting for READY
- Reset scenarios and randomized regression
- Functional coverage and coverage-gap analysis

## Repository Layout

```text
.
├── rtl/                   # AXI4-Lite slave RTL
├── tb/
│   ├── sv/                # Basic SystemVerilog testbench
│   └── uvm/               # UVM environment and components
│       ├── sequences/
│       └── tests/
├── assertions/            # SystemVerilog Assertions
├── sim/
│   ├── scripts/           # Simulator scripts and run instructions
│   ├── logs/              # Selected text logs (avoid generated clutter)
│   └── waves/              # Optional waveform files; large files may be excluded
├── coverage/              # Coverage reports and summaries
├── docs/                  # Design notes, verification plan, register map
└── results/
    ├── screenshots/       # Simulation and coverage screenshots
    └── waveforms/         # Exported waveform images
```

## Current Status

- [ ] RTL implementation completed and reviewed
- [ ] Basic SystemVerilog smoke test passes
- [ ] UVM components integrated
- [ ] Directed tests pass
- [ ] Constrained-random tests run reproducibly
- [ ] Protocol assertions enabled and checked
- [ ] Functional coverage reviewed
- [ ] Regression results documented
- [ ] Final screenshots and waveforms added

Check items only when supported by actual code and simulation evidence.

## Getting Started

This repository is currently a project scaffold. Add the RTL and testbench sources as they are implemented. Simulator commands will be documented in [`docs/BUILD_AND_RUN.md`](docs/BUILD_AND_RUN.md) once the simulator and project setup are finalized.

## Documentation

- [Project plan and verification checklist](docs/PROJECT_PLAN.md)
- [Build and run notes](docs/BUILD_AND_RUN.md)
- [Results template](results/RESULTS_TEMPLATE.md)

## Results

Simulation outcomes, pass/fail summaries, coverage percentages, and screenshots will be added after the corresponding runs have actually been completed. No coverage or pass-rate figures are claimed at this stage.

## Tools

Planned: SystemVerilog, UVM, and a simulator that supports the required UVM/SVA features. The exact tool/version will be recorded after it is confirmed.

## License

A license has not yet been selected. Add a license file before presenting the repository as open source.
