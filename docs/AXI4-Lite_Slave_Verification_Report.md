# AXI4-Lite Slave Verification using SystemVerilog & UVM

## Table of Contents

1. [Abstract](#1-abstract)
2. [Introduction](#2-introduction)
3. [Background: AXI4-Lite Protocol](#3-background-axi4-lite-protocol)
4. [DUT Specification](#4-dut-specification)
5. [RTL Design and Architecture](#5-rtl-design-and-architecture)
6. [Verification Plan and Strategy](#6-verification-plan-and-strategy)
7. [UVM Testbench Architecture](#7-uvm-testbench-architecture)
8. [Constrained-Random Stimulus and Test Scenarios](#8-constrained-random-stimulus-and-test-scenarios)
9. [SystemVerilog Assertions](#9-systemverilog-assertions)
10. [Functional and Code Coverage](#10-functional-and-code-coverage)
11. [Regression and Coverage Closure](#11-regression-and-coverage-closure)
12. [Results](#12-results)
13. [Bugs Found and Lessons Learned](#13-bugs-found-and-lessons-learned)
14. [Conclusion and Future Work](#14-conclusion-and-future-work)
15. [Appendix](#15-appendix)

---

## 1. Abstract

This project presents the design and verification of an **AXI4-Lite slave peripheral** with a memory-mapped register bank, implemented in SystemVerilog and verified using a reusable **UVM** environment. The RTL supports independent write-address (AW), write-data (W), write-response (B), read-address (AR) and read-data (R) channels with full VALID/READY handshaking, byte-strobe (WSTRB) partial writes, and SLVERR responses for invalid or read-only accesses.

The verification environment includes constrained-random sequences, a driver, monitor, scoreboard with a register reference model, functional coverage, and SystemVerilog Assertions (SVA) for protocol compliance. Directed and randomized tests exercise backpressure, AW/W ordering, reset behavior, invalid addresses and response handling. Functional and code coverage were collected across randomized regressions and analyzed to identify and close verification gaps.

**Keywords:** AXI4-Lite, UVM, SystemVerilog, SVA, constrained-random verification, functional coverage, backpressure, WSTRB.

---

## 2. Introduction

### 2.1 Motivation

AXI4-Lite is the standard interface for control/status register (CSR) access in SoCs. Slaves that look correct under simple "VALID=1, READY=1" tests can still fail in real systems where either side stalls, channels arrive in different orders, or resets occur mid-transaction. This project targets those harder cases.

### 2.2 Objectives

- Design an AXI4-Lite slave with a register-mapped read/write interface.
- Build a reusable UVM environment (transaction, sequence, sequencer, driver, monitor, agent, scoreboard, environment, test).
- Verify behavior using constrained-random stimulus rather than only directed tests.
- Add protocol assertions for VALID/READY rules, reset and response handling.
- Measure functional and code coverage, and use coverage gaps to drive new tests.

### 2.3 Scope

| In scope | Out of scope |
| --- | --- |
| 32-bit data / 32-bit address AXI4-Lite slave | Full AXI4 (bursts, out-of-order, interleaving) |
| One outstanding write and one outstanding read | Multiple outstanding transactions |
| OKAY and SLVERR responses | Exclusive access (EXOKAY) |
| Simulation-based verification | Formal verification, FPGA/ASIC implementation |

### 2.4 Project Phases

| Phase | Description |
| --- | --- |
| 1 | Understand AXI4-Lite |
| 2 | Define peripheral and register map |
| 3 | Build RTL (reset → read → write → VALID/READY → backpressure → error responses) |
| 4 | Basic SystemVerilog testbench (isolate DUT bugs from UVM bugs) |
| 5 | Build UVM environment |
| 6 | Constrained-random testing |
| 7 | Add assertions |
| 8 | Add functional coverage |
| 9 | Regression |
| 10 | Coverage convergence |

---

## 3. Background: AXI4-Lite Protocol

AXI4-Lite is a simplified, non-bursting subset of AMBA AXI intended for simple control/status register communication. It removes burst tracking, out-of-order execution and data interleaving.

### 3.1 Five Independent Channels

| Channel | Direction | Signals |
| --- | --- | --- |
| **Write Address (AW)** | Master → Slave | `AWADDR`, `AWVALID`, `AWREADY` |
| **Write Data (W)** | Master → Slave | `WDATA`, `WSTRB`, `WVALID`, `WREADY` |
| **Write Response (B)** | Slave → Master | `BRESP`, `BVALID`, `BREADY` |
| **Read Address (AR)** | Master → Slave | `ARADDR`, `ARVALID`, `ARREADY` |
| **Read Data (R)** | Slave → Master | `RDATA`, `RRESP`, `RVALID`, `RREADY` |

### 3.2 VALID/READY Handshake

Every channel has its own handshake. The source drives the payload and asserts `VALID`; the destination asserts `READY` when it can accept. **A transfer occurs on a rising clock edge when both are HIGH.**

Rules (these become assertions in Section 9):

- A source must not wait for `READY` before asserting `VALID`.
- Once `VALID` is asserted, it and the payload must remain stable until the handshake completes.
- A destination may wait for `VALID` before asserting `READY`.

### 3.3 Backpressure

Backpressure is a flow-control mechanism where the receiver drives `READY` low to force the sender to wait. For example, if `BVALID=1` and `BREADY=0`, the slave must hold `BVALID` and `BRESP` until `BREADY` rises. It cannot withdraw the response.

```
Master                          Slave
AWVALID ────────────────►
AWREADY ◄────── 0 ──────        (slave busy)
   WAIT
AWVALID ────────────────►
AWREADY ◄────── 1 ──────
                 ↑
              transfer
```

Backpressure testing verifies that data and addresses are not lost, VALID remains asserted, responses are not lost, transactions do not complete prematurely, and the slave recovers when READY is asserted.

### 3.4 Write Strobes (WSTRB)

There is one `WSTRB` bit per byte of `WDATA` (4 bits for a 32-bit bus):

| WSTRB bit | Controls |
| --- | --- |
| `WSTRB[0]` | `WDATA[7:0]` (byte 0) |
| `WSTRB[1]` | `WDATA[15:8]` (byte 1) |
| `WSTRB[2]` | `WDATA[23:16]` (byte 2) |
| `WSTRB[3]` | `WDATA[31:24]` (byte 3) |

| WSTRB | Meaning |
| --- | --- |
| `4'b1111` | Full 32-bit word write |
| `4'b0011` | Half-word write (lower 16 bits) |
| `4'b0001` | Single-byte write (upper 24 bits unchanged) |
| `4'b1010` | Sparse strobe |
| `4'b0000` | Null write: no data written |

A slave that ignores WSTRB and writes all 32 bits is a critical protocol violation. RTL uses a per-byte enable, e.g. `if (WSTRB[0]) reg_data[7:0] <= WDATA[7:0];`.

### 3.5 Addressing and Data Rules

- Single transfers only (burst length = 1).
- Data bus is 32-bit or 64-bit.
- All accesses must be aligned to the data bus width.

### 3.6 Responses

| Code | Name | Meaning in this project |
| --- | --- | --- |
| `2'b00` | OKAY | Normal success |
| `2'b01` | EXOKAY | Not supported in AXI4-Lite (falls back to OKAY) |
| `2'b10` | SLVERR | Invalid/unmapped address, or write to read-only register |
| `2'b11` | DECERR | Normally generated by interconnect when no slave exists |

### 3.7 Reset Behavior

- Active-low synchronous reset `ARESETn`.
- All `VALID` signals must be driven LOW during reset.
- `READY` signals may take any value; slave READY is commonly HIGH during reset so the first post-reset cycle can accept a transaction.

---

## 4. DUT Specification

### 4.1 Configuration

| Parameter | Value |
| --- | --- |
| Data width | 32 bits |
| Address width | 32 bits |
| Register count | 8 |
| Outstanding transactions | 1 write, 1 read |
| Reset | Active-low synchronous (`ARESETn`) |

### 4.2 Register Map

> **Note:** Only `DATA_IN @ 0x08 (RW)` is stated explicitly in the source notes. Other offsets and access types below are proposed placeholders. **Update them to match your RTL.**

| Offset | Register | Access | Reset Value | Description |
| --- | --- | --- | --- | --- |
| `0x00` | CONTROL | RW `[TBD]` | `0x0` | Control bits |
| `0x04` | STATUS | RO `[TBD]` | `0x1` | Status bits |
| `0x08` | DATA_IN | RW | `0x0` | Input data register |
| `0x0C` | DATA_OUT | `[TBD]` | `0x0` | Output data register |
| `0x10` | CONFIG | RW `[TBD]` | `0x0` | Configuration |
| `0x14` | COUNT | `[TBD]` | `0x0` | Counter |
| `0x18` | VERSION | RO `[TBD]` | `0x00010000` | Version ID |
| `0x1C` | SCRATCH | RW `[TBD]` | `0x0` | Scratch register |

### 4.3 Access Behavior

| Access | Result |
| --- | --- |
| Read/write to a valid RW register | `OKAY` |
| Read to a valid RO register | `OKAY` |
| Write to RO register | `SLVERR`, register unchanged |
| Read/write to unmapped address | `SLVERR` |
| Write with `WSTRB=0000` | No register change `[confirm your response code]` |

### 4.4 Reset Behavior

On reset: CONTROL = 0, STATUS = 1, DATA_IN = 0, DATA_OUT = 0, CONFIG = 0, COUNT = 0, VERSION = `0x00010000`, SCRATCH = 0, and all AXI control state returns to idle.

Reset is tested: (1) before any transaction, (2) between transactions, (3) during a pending read, (4) during a pending write.

---

## 5. RTL Design and Architecture

### 5.1 Top-Level Block Diagram

```
                        AXI4-LITE SLAVE
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
      WRITE CONTROL                        READ CONTROL
            │                                   │
       AW capture                          AR capture
       W capture                                │
            │                                   ▼
            ▼                             Address decode
      AW/W tracking                             │
            │                                   ▼
            ▼                             Read data mux
       Write decode                             │
            │                                   ▼
            ▼                             RDATA / RRESP
      Register bank                             │
            │                                   ▼
            ▼                                 RVALID
      BRESP / BVALID                            │
            │                                   ▼
            ▼                                 RREADY
         BREADY
                              │
                      REGISTER BANK
     ┌──────────┬──────────┬──────────┬──────────┐
  CONTROL     STATUS    DATA_IN   DATA_OUT   CONFIG ... COUNT / VERSION / SCRATCH
```

### 5.2 Architecture Decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Read/write control | Separate read and write controllers | Simpler than one large FSM; channels are independent |
| Write tracking | Flag-based (`aw_received`, `w_received`) with a small FSM | Cleaner than `WAIT_AW`/`WAIT_W` state explosion; channels can arrive in either order |
| Outstanding transactions | One write, one read | Keeps RTL manageable; sufficient for CSR access |
| READY policy | Deassert after capture until transaction completes | Only one holding slot per channel |

> AXI4-Lite does not prescribe an FSM. The FSMs here are this project's own internal design.

### 5.3 Write Path

**Holding registers:** `awaddr_reg`, `wdata_reg`, `wstrb_reg` **Flags:** `aw_received`, `w_received`

```
 AW channel ─►┌──────────────────┐
              │ Address holding  │───┐
              │ register         │   │
              └──────────────────┘   ▼
                                 ┌──────────┐
                                 │  Write   │──► Register bank
                                 │Controller│──► BRESP / BVALID
                                 └──────────┘
              ┌──────────────────┐   ▲
 W channel ──►│ Data/Strobe      │───┘
              │ holding regs     │
              └──────────────────┘
```

**Write state encoding (conceptual):**

| `aw_received` | `w_received` | Meaning | AWREADY | WREADY | Action |
| --- | --- | --- | --- | --- | --- |
| 0 | 0 | Nothing received | 1 | 1 | Wait for either |
| 1 | 0 | Address only | 0 | 1 | Wait for W |
| 0 | 1 | Data only | 1 | 0 | Wait for AW |
| 1 | 1 | Both received | 0 | 0 | Execute write, issue B |

**Write FSM:**

```
WRITE_IDLE ──(aw_received && w_received)──► WRITE_EXEC ──► B_RESPONSE
     ▲                                                          │
     └─────────────── BVALID && BREADY ◄────────────────────────┘
                      (clear flags)
```

Key flag logic:

```systemverilog
if (AWVALID && AWREADY) aw_received <= 1;
if (WVALID  && WREADY ) w_received  <= 1;
if (aw_received && w_received) execute_write();
```

Byte-lane write:

```systemverilog
if (wstrb_reg[0]) reg_data[7:0]   <= wdata_reg[7:0];
if (wstrb_reg[1]) reg_data[15:8]  <= wdata_reg[15:8];
if (wstrb_reg[2]) reg_data[23:16] <= wdata_reg[23:16];
if (wstrb_reg[3]) reg_data[31:24] <= wdata_reg[31:24];
```

### 5.4 Worked Example: W Arrives Before AW

Transaction: `WRITE 0x08 = 0xDEADBEEF`, `WSTRB = 4'b1111`, W before AW, master stalls `BREADY`.

| Cycle | Event | aw_received | w_received | State |
| --- | --- | --- | --- | --- |
| 0 | Idle | 0 | 0 | WRITE_IDLE |
| 1 | W handshake (`wdata_reg=DEADBEEF`, WREADY→0) | 0 | 1 | WAIT_AW |
| 2 | AW handshake (`awaddr_reg=0x08`, AWREADY→0) | 1 | 1 | WRITE_EXEC |
| 3 | Decode `0x08 → DATA_IN`, write, `BVALID=1`, `BRESP=OKAY` | 1 | 1 | B_RESPONSE |
| 4 | B stalled (`BREADY=0`) | 1 | 1 | B_RESPONSE |
| 5 | B stalled | 1 | 1 | B_RESPONSE |
| 6 | B handshake (`BREADY=1`) | 1 | 1 | B_RESPONSE |
| 7 | Cleanup, flags cleared | 0 | 0 | WRITE_IDLE |

```
          C0  C1  C2  C3  C4  C5  C6  C7
WVALID        ███
WREADY        ███
WDATA         DEADBEEF
AWVALID           ███
AWREADY           ███
AWADDR            0x08
BVALID                ███████████████
BREADY                ────────────███
BRESP                 OKAY
DATA_IN               ─► DEADBEEF
```

> Insert your simulator waveform screenshot of this scenario in Section 12.

**Edge cases handled:**

- *W never arrives after AW:* `AWREADY=0`, `WREADY=1`, `BVALID=0`; must not write, respond, lose the address, or accept another AW.
- *AW never arrives after W:* `AWREADY=1`, `WREADY=0`, `BVALID=0`.

### 5.5 Read Path

```
READ_IDLE ──(ARVALID && ARREADY)──► READ_RESP ──(RVALID && RREADY)──► READ_IDLE
```

- `ARREADY=1` when the read path is idle.
- AR captured into a holding register, then decoded.
- `RDATA` and `RRESP` generated from the register mux (`SLVERR` if unmapped).
- `RVALID` held until `RREADY`.

### 5.6 Three Distinct Concepts

| Concept | Definition |
| --- | --- |
| **Channel handshake** | `VALID && READY` on a single channel |
| **Transaction completion** | Write: AW + W + B accepted. Read: AR + R accepted |
| **Register operation** | Write: occurs when AW and W are both received |

These are separate events and are verified separately.

---

## 6. Verification Plan and Strategy

### 6.1 Verification Goal

> Functional correctness + protocol correctness + meaningful coverage + no unexplained coverage gaps.

### 6.2 Verification Flow

```
Basic SV testbench (DUT sanity)
        ↓
UVM environment
        ↓
Constrained-random tests + assertions
        ↓
Functional + code coverage
        ↓
Regression (multiple seeds)
        ↓
Coverage gap analysis → new constraints/tests → regression
```

### 6.3 Feature-to-Test Plan

| ID | Feature | Test / Method | Checker |
| --- | --- | --- | --- |
| F1 | Reset values | Reset before/between/during transactions | Scoreboard, SVA |
| F2 | Register read | Random reads of all registers | Scoreboard |
| F3 | Register write | Random writes of RW registers | Scoreboard |
| F4 | WSTRB partial writes | Randomized strobes (full, half, byte, sparse, `0000`) | Scoreboard mask model |
| F5 | AW then W | Delays of 0, 1, 5 cycles | Scoreboard, SVA |
| F6 | W then AW | Delays of 0, 1, 5 cycles | Scoreboard, SVA |
| F7 | Same-cycle AW + W | Concurrent drive | Scoreboard |
| F8 | B backpressure | `BREADY` delay 0, 1, 5 cycles | SVA (BVALID stable) |
| F9 | R backpressure | `RREADY` delay | SVA (RVALID stable) |
| F10 | Invalid address | Unmapped read/write | Scoreboard (SLVERR) |
| F11 | Write to RO register | Write RO offsets | Scoreboard (SLVERR, no change) |
| F12 | Boundary addresses | First/last register, just beyond map | Scoreboard |
| F13 | Reset during transaction | Reset during pending read/write | SVA, scoreboard |
| F14 | Handshake rules | All channels | SVA |

---

## 7. UVM Testbench Architecture

### 7.1 Block Diagram

```
                 ┌───────────────┐
                 │   UVM Test    │
                 └───────┬───────┘
                         ▼
                 ┌───────────────┐
                 │   Sequences   │
                 └───────┬───────┘
                         ▼
                 ┌───────────────┐
                 │   Sequencer   │
                 └───────┬───────┘
                         ▼
                 ┌───────────────┐
                 │    Driver     │
                 └───────┬───────┘
                         │ AXI4-Lite
                         ▼
              ┌────────────────────────┐
              │          DUT           │
              │   AXI4-Lite Slave      │
              │          │             │
              │          ▼             │
              │    Register Bank       │
              └───────────┬────────────┘
                          ▼
                 ┌───────────────┐
                 │    Monitor    │
                 └───────┬───────┘
              ┌──────────┴──────────┐
              ▼                     ▼
       ┌─────────────┐       ┌─────────────┐
       │ Scoreboard  │       │  Coverage   │
       └─────────────┘       └─────────────┘

   + SystemVerilog Assertions (bound to interface/DUT)
```

### 7.2 Components

| Component | Role |
| --- | --- |
| **Interface** | Bundles AXI4-Lite signals, clocking blocks, modports; hosts assertions |
| **Transaction** (`axi_transaction`) | Randomizable item: operation (READ/WRITE), address, data, WSTRB, and delay knobs |
| **Sequences** | Generate transaction streams (directed and constrained-random) |
| **Sequencer** | Delivers transactions to the driver |
| **Driver** | Converts transaction into AXI signals on AW/W/AR channels; drives `BREADY`/`RREADY` with configurable stalls |
| **Monitor** | Passively observes all five channels; reconstructs completed transactions |
| **Agent** | Groups sequencer, driver, monitor (active/passive) |
| **Scoreboard** | Compares expected (reference model) vs. observed behavior |
| **Coverage collector** | Samples functional coverage from monitored transactions |
| **Environment** | Instantiates agent, scoreboard, coverage |
| **Test** | Selects sequences and configuration |

### 7.3 Transaction Example

```systemverilog
class axi_transaction extends uvm_sequence_item;
  rand bit        is_write;     // WRITE / READ
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0]  wstrb;
  rand int        aw_w_delay;   // negative = W first, positive = AW first
  rand int        bready_delay;
  rand int        rready_delay;
  bit      [1:0]  resp;         // observed response
  // constraints in Section 8
endclass
```

Driver mapping example:

```
axi_transaction {WRITE, addr=0x08, data=0x12345678}
        ▼
     Driver
        ▼
AWADDR=0x08, WDATA=0x12345678, AWVALID=1, WVALID=1
```

### 7.4 Scoreboard and Reference Model

The scoreboard maintains a model of the register bank:

- **On write:** applies WSTRB masking to combine old value and new data:

  ```systemverilog
  new_val = (old_val & ~mask) | (wdata & mask);   // mask built from wstrb bytes
  ```

  Only if the register is RW and mapped; otherwise expects `SLVERR` and no state change.
- **On read:** compares `RDATA` with model, and `RRESP` with expected.
- **On every write:** checks `BRESP`.
- **On reset:** reloads reset values.

---

## 8. Constrained-Random Stimulus and Test Scenarios

### 8.1 Address Distribution

| Category | Weight |
| --- | --- |
| Valid addresses | 70% |
| Invalid addresses | 20% |
| Boundary addresses | 10% |

*(Distribution can be tuned based on coverage gaps.)*

```systemverilog
constraint addr_dist_c {
  addr_kind dist { VALID := 70, INVALID := 20, BOUNDARY := 10 };
  // addr aligned to 4 bytes (aligned accesses only)
}
```

### 8.2 Randomized Fields

Addresses, read/write operation, data, WSTRB, stall cycles, and transaction ordering.

### 8.3 Write-Channel Ordering Scenarios

| # | Scenario |
| --- | --- |
| 1 | AW + W in the same cycle |
| 2 | AW → wait 1 cycle → W |
| 3 | AW → wait 5 cycles → W |
| 4 | W → wait 1 cycle → AW |
| 5 | W → wait 5 cycles → AW |

Crossed with BREADY delay of 0, 1, 5 cycles, exercising every path in the write control logic.

### 8.4 Test List

| Test | Description |
| --- | --- |
| `smoke_test` | Basic reset, write, read-back |
| `reg_rw_test` | Random reads/writes to all valid registers |
| `wstrb_test` | Random WSTRB: full, partial, sparse, `0000` |
| `aw_first_test` / `w_first_test` | Channel ordering with variable delays |
| `backpressure_test` | Random `BREADY`/`RREADY`/`AWREADY` stalls |
| `invalid_addr_test` | Unmapped addresses for read and write |
| `ro_write_test` | Write to read-only registers → SLVERR |
| `reset_test` | Reset before, between, and during transactions |
| `random_regression_test` | Mixed constrained-random across all knobs |

---

## 9. SystemVerilog Assertions

Assertions are placed in the interface (or a bound module) and checked on every simulation.

### 9.1 Assertion Catalog

| ID | Property | Description |
| --- | --- | --- |
| A1 | `AWVALID` stable | Once `AWVALID` is high, it stays high until `AWREADY` |
| A2 | AW payload stable | `AWADDR` unchanged while `AWVALID && !AWREADY` |
| A3 | `WVALID` stable | Holds until `WREADY` |
| A4 | W payload stable | `WDATA`, `WSTRB` stable while pending |
| A5 | `ARVALID` / `ARADDR` stable | Same rule on AR |
| A6 | `BVALID` stable | Slave cannot withdraw B response when `BREADY` is low |
| A7 | `BRESP` stable | While `BVALID && !BREADY` |
| A8 | `RVALID` / `RDATA` / `RRESP` stable | Slave cannot withdraw R response when `RREADY` is low |
| A9 | Valid response codes | `BRESP`/`RRESP` ∈ {OKAY, SLVERR} (never EXOKAY) |
| A10 | No early B | `BVALID` not asserted before both AW and W received |
| A11 | No early R | `RVALID` not asserted before AR received |
| A12 | Reset VALIDs low | All VALID signals LOW during reset |
| A13 | No X on control signals | VALID/READY not X after reset |
| A14 | Single outstanding | No second AW/W accepted before B completes (design-specific) |

### 9.2 Example Assertions

```systemverilog
// A1: VALID must remain asserted until READY
property p_awvalid_stable;
  @(posedge ACLK) disable iff (!ARESETn)
    (AWVALID && !AWREADY) |=> AWVALID;
endproperty
a_awvalid_stable: assert property (p_awvalid_stable);

// A2: payload stable while waiting
property p_awaddr_stable;
  @(posedge ACLK) disable iff (!ARESETn)
    (AWVALID && !AWREADY) |=> $stable(AWADDR);
endproperty

// A6: slave cannot withdraw response
property p_bvalid_hold;
  @(posedge ACLK) disable iff (!ARESETn)
    (BVALID && !BREADY) |=> (BVALID && $stable(BRESP));
endproperty

// A8: read response hold
property p_rvalid_hold;
  @(posedge ACLK) disable iff (!ARESETn)
    (RVALID && !RREADY) |=> (RVALID && $stable(RDATA) && $stable(RRESP));
endproperty

// A12: VALIDs low in reset
a_reset_valids: assert property (@(posedge ACLK)
  !ARESETn |-> (!AWVALID && !WVALID && !ARVALID && !BVALID && !RVALID));
```

> The exact behavior for reset during an active transaction should be specified precisely before finalizing A12/reset-related assertions.

---

## 10. Functional and Code Coverage

### 10.1 Functional Coverage Model

| Covergroup | Coverpoints / Bins |
| --- | --- |
| **Operation** | read, write |
| **Address** | each register offset, invalid address, boundary address |
| **WSTRB** | `1111`, `0011`, `1100`, `0001`, `0010`, `0100`, `1000`, sparse (`1010`, `0101`), `0000` |
| **Response** | OKAY, SLVERR (for read and write) |
| **Write ordering** | AW-first, W-first, simultaneous |
| **AW/W gap** | 0, 1, 2–5, >5 cycles |
| **BREADY delay** | 0, 1, 2–5, >5 cycles |
| **RREADY delay** | 0, 1, 2–5, >5 cycles |
| **Reset scenario** | idle, between transactions, during read, during write |

### 10.2 Cross Coverage

| Cross | Purpose |
| --- | --- |
| Operation × Address | Every register read and written |
| Address × Response | OKAY vs. SLVERR per register (e.g., write to RO) |
| WSTRB × Address (RW regs) | Partial writes hit every RW register |
| Ordering × AW/W gap | Both orders with all delays |
| Ordering × BREADY delay | Backpressure under each ordering |
| Operation × Reset scenario | Reset during read vs. write |

### 10.3 Code Coverage

Collected: line, branch, condition, toggle, FSM (state and transition). Unreachable/waived items are documented with justification.

### 10.4 Assertion Coverage

Each SVA has a `cover property` to prove it was exercised (not passing vacuously).

---

## 11. Regression and Coverage Closure

### 11.1 Regression Flow

```
Tests → Pass/Fail → Coverage → Coverage gaps → New constraints/tests → Regression
```

### 11.2 Setup

| Item | Value |
| --- | --- |
| Seeds per test | `[TBD]` |
| Total runs | `[TBD]` |
| Simulator | `[TBD]` |
| Merge method | `[e.g., UCDB / VDB merge]` |

### 11.3 Gap Analysis Log (fill in from your runs)

| Iteration | Gap Found | Root Cause | Action Taken | Result |
| --- | --- | --- | --- | --- |
| 1 | *\[e.g., W-first with 5-cycle delay not hit\]* | *\[constraint too narrow\]* | *\[widened delay dist\]* | *\[closed\]* |
| 2 | *\[...\]* | *\[...\]* | *\[...\]* | *\[...\]* |

### 11.4 Closure Criteria

- All tests pass across all seeds with zero assertion failures.
- Functional coverage target met `[e.g., 100%]`.
- Code coverage target met `[e.g., >95%]`, remaining holes explained or waived.

---

## 12. Results

### 12.1 Regression Summary

| Metric | Result |
| --- | --- |
| Tests run | `[TBD]` |
| Pass / Fail | `[TBD]` |
| Assertion failures | `[TBD]` |

### 12.2 Coverage Summary

| Type | Initial | Final |
| --- | --- | --- |
| Functional coverage | `[TBD]%` | `[TBD]%` |
| Line coverage | `[TBD]%` | `[TBD]%` |
| Branch coverage | `[TBD]%` | `[TBD]%` |
| Toggle coverage | `[TBD]%` | `[TBD]%` |
| FSM coverage | `[TBD]%` | `[TBD]%` |

### 12.3 Waveforms

Include screenshots of:

1. W-before-AW write with BREADY stall (Section 5.4 scenario)
2. Read with RREADY backpressure
3. Invalid-address access returning SLVERR
4. Partial-WSTRB write
5. Reset during pending transaction

```
![W-first write](images/w_first_write.png)
```

### 12.4 Coverage Plots

*\[Insert coverage-over-regression graph/screenshots.\]*

---

## 13. Bugs Found and Lessons Learned

### 13.1 Bug Log

| # | Bug | Detected By | Fix |
| --- | --- | --- | --- |
| 1 | *\[e.g., RTL assumed AW arrives before W\]* | Constrained-random W-first test | Flag-based AW/W tracking |
| 2 | *\[e.g., WSTRB ignored on one byte lane\]* | Scoreboard mismatch | Per-byte enable |
| 3 | *\[e.g., BVALID dropped under backpressure\]* | SVA A6 | Hold BVALID until BREADY |

> Replace with the bugs you actually found. These examples reflect the failure classes this environment was designed to catch.

### 13.2 Lessons Learned

- Simple tests with `VALID=1, READY=1` miss most real protocol bugs; backpressure and ordering matter.
- Verifying the RTL with a basic testbench first separates DUT bugs from UVM bugs.
- Handshake, transaction completion and register update are three separate events.
- Coverage gaps point directly at missing constraints.
- Flag-based control is simpler than state-heavy FSMs for independent AXI channels.

---

## 14. Conclusion and Future Work

### 14.1 Conclusion

An AXI4-Lite slave with a register bank was designed and verified using a reusable UVM environment. Constrained-random sequences, a WSTRB-aware scoreboard, protocol assertions, and functional/code coverage verified handshaking, backpressure, channel ordering, partial writes, error responses and reset behavior. Coverage analysis across randomized regressions identified verification gaps, which were closed with targeted constraints and tests.

### 14.2 Future Work

- Support 64-bit data width and parameterized address map.
- Support multiple outstanding transactions.
- Add a UVM RAL (register abstraction layer) model.
- Add a master-side UVM agent with protocol checker for reuse.
- Formal verification of handshake properties.
- Add `AWPROT`/`ARPROT` and optional interconnect (DECERR) modeling.

---

## 15. Appendix

### A. File Structure

```
axi4lite_project/
├── rtl/
│   └── axi4lite_slave.sv
├── tb_basic/
│   └── tb_axi4lite_slave.sv
├── uvm/
│   ├── axi_if.sv
│   ├── axi_transaction.sv
│   ├── axi_sequences.sv
│   ├── axi_sequencer.sv
│   ├── axi_driver.sv
│   ├── axi_monitor.sv
│   ├── axi_agent.sv
│   ├── axi_scoreboard.sv
│   ├── axi_coverage.sv
│   ├── axi_env.sv
│   └── axi_tests.sv
├── assertions/
│   └── axi_assertions.sv
├── sim/
│   ├── Makefile
│   └── run_regression.sh
└── docs/
    └── report.md
```

### B. How to Run

```bash
# Example, replace with your commands
make compile
make run TEST=random_regression_test SEED=1
make regress
make cov_report
```

### C. Glossary

| Term | Meaning |
| --- | --- |
| AXI4-Lite | Simplified AMBA AXI subset for register access |
| Backpressure | Receiver deasserts READY to stall the sender |
| WSTRB | Write strobe, byte-enable mask for WDATA |
| SLVERR | Slave error response |
| SVA | SystemVerilog Assertions |
| UVM | Universal Verification Methodology |
| CSR | Control/Status Register |

### D. References

1. ARM, *AMBA AXI and ACE Protocol Specification*.
2. Accellera, *UVM 1.2 User Guide / Class Reference*.
3. IEEE 1800, *SystemVerilog Language Reference Manual*.
