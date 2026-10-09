# AXI4-Lite Slave Verification using SystemVerilog and UVM

This repository contains the RTL for an AXI4-Lite slave, a flat SystemVerilog/UVM testbench, project documentation, and captured simulation evidence.

## Repository layout

```text
axi4lite-slave-uvm-verification/
├── README.md
├── rtl/
│   ├── top_module.v
│   ├── read_path.v
│   ├── write_path.v
│   └── register_bank.v
├── tb/
│   ├── axi4lite_if.sv
│   ├── tb_top.sv
│   ├── axi4lite_seq_item.sv
│   ├── axi4lite_sequence.sv
│   ├── axi4lite_sequencer.sv
│   ├── axi4lite_driver.sv
│   ├── axi4lite_monitor.sv
│   ├── axi4lite_agent.sv
│   ├── axi4lite_env.sv
│   ├── axi4lite_scoreboard.sv
│   └── axi4lite_test.sv
├── docs/
│   ├── AXI4-Lite_Slave_Verification_Report.md
│   └── Overview.md
└── results/
    ├── logs.txt
    └── waveform screenshots
```

## Contents

- `rtl/`: AXI4-Lite slave RTL.
- `tb/`: UVM interface, testbench top, transaction, sequence, sequencer, driver, monitor, agent, environment, scoreboard, and test.
- `docs/`: original design notes and review/report documents.
- `results/`: supplied simulation logs and waveform screenshots.

## Running the simulation

The supplied log indicates the project was simulated with AMD/Xilinx Vivado XSim and UVM 1.2. To rerun, create or open a Vivado project, add the four RTL files as design sources and all files in `tb/` as simulation sources, ensure UVM 1.2 is enabled, and select `tb_top` as the simulation top.

The exact source ordering and simulator setup may need to be configured in Vivado. No project-specific Vivado project file or portable simulator script was supplied in this upload.

## Interpreting results

`results/logs.txt` preserves the uploaded phase-wise output. The waveforms are visual evidence for channel handshakes and write execution. Treat the log as the record of the runs it contains; do not infer that every scenario described in the report was run successfully unless the log explicitly demonstrates it.

The detailed report and review files are preserved as supplied. Some sections may contain template fields or verification claims that should be reconciled against the actual source and run logs before being used as sign-off evidence.

## Notes

- Source files were renamed to remove upload suffixes such as `(1)`; the source contents were not intentionally rewritten.
- This package is a source-and-evidence bundle, not a generated Vivado project.
