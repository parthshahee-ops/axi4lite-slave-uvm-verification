# Simulation Results

## Evidence source

Summarized from the supplied Vivado/XSim log (`sim/logs/vivado_xsim.log`). The log contains multiple simulation runs; this summary uses the latest final `run all` regression summary near the end of the log.

## Final recorded regression

| Metric | Recorded result |
|---|---:|
| Transactions | 1,000 |
| Passed | 1,000 |
| Failed | 0 |
| UVM errors | 0 |
| UVM warnings | 0 |
| UVM fatals | 0 |
| Functional coverage | 100.00% |
| Simulation result | PASS |

## Functional coverage breakdown

The final log lists each of these testbench coverpoints at 100.00%:

| Coverpoint | Coverage |
|---|---:|
| `cp_op` | 100.00% |
| `cp_addr_type` | 100.00% |
| `cp_reg_type` | 100.00% |
| `cp_wstrb_exact` | 100.00% |
| `cp_wstrb_categories` | 100.00% |
| `cp_write_order` | 100.00% |
| `cp_bready_bp` | 100.00% |
| `cp_rready_bp` | 100.00% |
| `cp_resp` | 100.00% |
| `cp_write_ro_err` | 100.00% |
| `cp_write_inv_err` | 100.00% |
| `cp_read_inv_err` | 100.00% |

These percentages are the testbench's reported functional coverage. The supplied log does **not** report line, branch, toggle, or FSM code coverage, and does not include a coverage database.

## Behaviors visible in the records

- Successful write/read-back transactions for mapped addresses including `0x00`, `0x08`, `0x0C`, `0x10`, and `0x1C`.
- Read of `0x04` returned `0x00000001`; read of `0x14` returned `0x00000005`; read of `0x18` returned `0x00010000`.
- Writes to `0x04`, `0x14`, and `0x18` returned `SLVERR`, consistent with the test's read-only-register checks.
- Read and write accesses to `0x20` returned `SLVERR` in the recorded cases.
- Read and write accesses to unaligned address `0x02` returned `SLVERR` in the recorded cases.
- Several byte-strobe patterns were exercised at `0x1C`. The log shows read-back values consistent with byte-lane updates for `WSTRB=0001`, `0010`, `0100`, and `1000`, as well as full-word writes.

## Earlier recorded runs

An earlier 1,000-transaction regression reports 1,000 passed, 0 failed, no UVM errors/warnings/fatals, and 88.89% functional coverage. The later `run all` record reports 100.00% functional coverage. Keep both records if documenting coverage progression; do not describe the earlier result as the final result.

## Compile note

Earlier compile/elaboration records include warnings about the argument name `rm` in an override of `compose_report_message` not matching the superclass argument name `report_message` in `axi4lite_test.sv` / `clean_report_server`. The final regression summary has zero UVM warnings, but that does not by itself prove the compile-time warning was fixed. Consider aligning the override argument name with the superclass signature, then recompile to verify.

## Limitations

- This summary does not independently rerun the simulation; it records what the supplied log reports.
- The actual RTL/UVM source files and project files were not attached, so the reported behavior cannot be independently inspected or reproduced from this ZIP alone.
- No code-coverage percentage, formal verification result, or assertion-pass count is inferred from the functional-coverage summary.
