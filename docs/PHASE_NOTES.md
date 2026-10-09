# Extracted Project / Phase Notes

This file distills the relevant design intent from the supplied 25-page phase-notes PDF. Items here describe the planned or documented architecture; where behavior is called out as verified, consult `results/RESULTS.md` for the exact log evidence.

## Interface and scope

- AXI4-Lite memory-mapped slave; log identifies `tb_top` as simulation top.
- 32-bit address and data path are described in the project notes.
- Five independent channels: AW, W, B, AR and R.
- VALID/READY transfer occurs at a rising edge when both signals are high.
- WSTRB provides per-byte write enables for the 32-bit data path.
- Expected response codes used in the notes: `OKAY` for successful mapped accesses; `SLVERR` for invalid/unmapped addresses and writes to read-only registers.

## Write-control intent

The notes describe independently accepting AW and W, storing address/data/strobes, and executing the write only after both channels have been received. The controller should handle either AW-first or W-first order. Once `BVALID` is asserted, the response and `BVALID` should remain stable until `BREADY` handshakes.

## Read-control intent

Capture AR, decode the address, select read data / response, and hold `RVALID`, `RDATA` and `RRESP` stable while the response is backpressured (`RREADY=0`).

## Register behavior visible in simulation records

| Address | Observed behavior in log | Caution |
|---|---|---|
| `0x00` | Full write/read-back succeeds | Register name not proven by log alone |
| `0x04` | Read returns `0x00000001`; write returns `SLVERR` | Consistent with read-only status register |
| `0x08` | `0xDEADBEEF` write/read-back succeeds | Phase notes call this `DATA_IN` |
| `0x0C` | `0xCAF EF00D`-style test value written/read back (`0xCAF EF00D` without spacing is `0xCAFEF00D`) | Register name not proven by log alone |
| `0x10` | Write/read-back succeeds | Register name not proven by log alone |
| `0x14` | Read returns `0x00000005`; write returns `SLVERR` | Consistent with read-only register |
| `0x18` | Read returns `0x00010000`; write returns `SLVERR` | Consistent with read-only version register |
| `0x1C` | Full and byte-lane writes/read-backs succeed | Register name not proven by log alone |
| `0x20` | Read/write return `SLVERR` | Treated as unmapped in recorded tests |
| `0x02` | Read/write return `SLVERR` | Unaligned address in recorded tests |

The notes contain a proposed eight-register map, but explicitly mark several fields as TBD. Do not publish the proposed register names/access attributes as final specifications without checking the RTL.

## Verification features named in the log

- Sanity write and read-back.
- Mapped and invalid address accesses.
- Writes to addresses treated as read-only.
- WSTRB full-word and partial-byte updates.
- Functional coverage for operation, address type, register type, WSTRB, write ordering, B/R backpressure, response type and error cases.
- 1,000-transaction regression with final reported functional coverage of 100%.

## Source files to import

The log references `axi4lite_if.sv`, `tb_top.sv`, `axi4lite_test.sv`, `axi4lite_driver.sv`, and `axi4lite_sequence.sv`. It also shows modules named `axi4lite_write`, `axi4lite_read`, `axi4lite_reg_bank`, and `axi4lite_slave_top`. The source text itself was not contained in the log/PDF, so it cannot be reconstructed faithfully from those records.
