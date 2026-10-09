# Source Import Checklist

## What was present in the supplied materials

- Vivado/XSim behavioral simulation log.
- Phase-notes PDF describing AXI4-Lite protocol and project architecture.
- A report template with proposed architecture and placeholders.

## What was not present

The actual Verilog/SystemVerilog source code was not attached. A simulator log proves which modules were compiled and shows test output, but it does not contain their complete source definitions. This ZIP therefore intentionally does not invent RTL or UVM code.

## Copy these actual files from the Vivado project

### RTL → `rtl/`

Copy the `.v` files that define the compiled modules, whose module names in the log include:

- `axi4lite_write`
- `axi4lite_read`
- `axi4lite_reg_bank`
- `axi4lite_slave_top`

Actual filenames should be taken from Vivado's Design Sources; do not assume module names equal filenames.

### Testbench / UVM → `tb/`

The log explicitly references these files:

- `axi4lite_if.sv` — likely belongs under `tb/sv/` or the project's chosen interface folder.
- `tb_top.sv` — simulation top; usually `tb/sv/`.
- `axi4lite_test.sv` — UVM test; `tb/uvm/tests/`.
- `axi4lite_driver.sv` — UVM driver; `tb/uvm/`.
- `axi4lite_sequence.sv` — UVM sequence; `tb/uvm/sequences/`.

Copy any additional UVM classes required by the top-level compile list (transaction, sequencer, monitor, agent, environment, scoreboard, coverage, packages, etc.). The log doesn't give a complete source manifest, so verify the original Vivado simulation fileset and include dependencies.

## Before committing

1. Keep only actual source and intentionally shared documentation; exclude `.Xil/`, `.sim/`, generated simulator snapshots, cache, and huge waveform/database outputs unless intentionally publishing selected evidence.
2. Make sure the source is yours or permitted to publish.
3. Open `rtl/` and `tb/` locally and check that source files, not only `.gitkeep`, are present.
4. Run behavioral simulation again from the original Vivado project after the copy to confirm the copied source matches the passing project.
5. Then commit the source and this documentation/results overlay.
