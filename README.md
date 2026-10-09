# AXI4-Lite Slave Verification using SystemVerilog & UVM

A 32-bit AXI4-Lite slave and UVM-based verification project developed and simulated in AMD/Xilinx Vivado Simulator (XSim).

## Verified from the supplied simulation records

The latest recorded `run all` regression reports:

- 1,000 transactions; 1,000 passed; 0 failed.
- 0 UVM errors, warnings, or fatals in the regression summary.
- 100.00% reported **functional coverage** for the project's listed coverpoints.
- The simulator log shows successful writes and read-backs, `OKAY` responses for mapped accesses, `SLVERR` for tested read-only writes, invalid addresses and an unaligned address, and byte-lane updates for several WSTRB patterns.

See [`results/RESULTS.md`](results/RESULTS.md) for the detailed evidence and limitations. These are functional-coverage results reported by the testbench, not code-coverage results.

## Tools indicated by the logs

- AMD/Xilinx Vivado 2026.1
- XSim behavioral simulator
- UVM 1.2
- Simulation top: `tb_top`

## RTL / testbench structure observed in the compile log

The compile log names these modules: `axi4lite_write`, `axi4lite_read`, `axi4lite_reg_bank`, `axi4lite_slave_top`, and `tb_top`. It also identifies `axi4lite_if.sv`, `tb_top.sv`, `axi4lite_test.sv`, `axi4lite_driver.sv`, and `axi4lite_sequence.sv` in compile/runtime messages.

**Important:** This ZIP is a documentation-and-results overlay, not a source-code archive. The uploaded material included simulation logs and phase notes, but not the actual `.v` / `.sv` source files. Those source files must be copied from the Vivado project into `rtl/` and `tb/` before this repository can be independently rebuilt. See [`docs/SOURCE_IMPORT_CHECKLIST.md`](docs/SOURCE_IMPORT_CHECKLIST.md).

## Repository layout

- `rtl/` — place the actual synthesizable Verilog source files here.
- `tb/uvm/` — place the actual UVM classes here.
- `docs/` — phase notes, build information and source-import checklist.
- `results/` — summarized results from the supplied simulation log.
- `sim/logs/` — sanitized XSim log record.

## Reproduce the simulation

Open the original Vivado project and run behavioral simulation with `tb_top` as the simulation top. Exact compile scripts, project files and the source tree were not included in the uploaded logs, so this repository does not yet provide a standalone command-line reproduction flow.
