# AXI4-Lite Slave Verification --- Detailed Project Development Report

**Project:** AXI4-Lite Slave Verification \| SystemVerilog & UVM\
**Purpose:** Base document for the final project report\
**Development period:** 2026\
**Simulation environment:** Vivado / XSim\
**Primary focus:** RTL design, AXI4-Lite protocol behavior, UVM
verification, constrained-random testing, functional coverage, coverage
closure, and SVA

------------------------------------------------------------------------

## 1. Executive Summary

This project was developed as a focused RTL and verification project
around a **32-bit AXI4-Lite slave** with a memory-mapped register bank.

The project was deliberately developed in stages rather than writing a
large UVM environment immediately. The progression was:

``` text
AXI4-Lite protocol understanding
        ↓
Modular RTL implementation
        ↓
Directed smoke test
        ↓
Deterministic functional verification
        ↓
UVM infrastructure
        ↓
Reference-model scoreboard
        ↓
Constrained-random verification
        ↓
Functional coverage
        ↓
Coverage-gap analysis and closure
        ↓
SystemVerilog Assertions
        ↓
Regression and documentation
```

The final functional regression achieved:

``` text
Transactions       : 1000
Passed             : 1000
Failed             : 0
UVM Errors         : 0
UVM Warnings       : 0
UVM Fatals         : 0
Functional Coverage: 100.00%
```

The project also contains an SVA layer. However, the final recorded SVA
run produced a reset-time assertion message at approximately 5 ns:

``` text
[SVA-RST] Valids not deasserted during reset!
```

Because the DUT uses a **synchronous active-low reset**, this is likely
related to when the assertion evaluates relative to the first clock edge
that applies reset. Therefore the technically correct final status is:

-   Functional/UVM regression: **PASS**
-   Functional coverage: **100%**
-   SVA layer: **implemented**
-   Completely assertion-clean regression: **not yet claimed**

This distinction should be preserved in the final report.

------------------------------------------------------------------------

# 2. Project Motivation

The purpose of the project was to demonstrate more than basic RTL
coding.

The target skill set was:

``` text
RTL
+
AXI4-Lite
+
SystemVerilog
+
UVM
+
Constrained Random
+
Scoreboard / Reference Model
+
Functional Coverage
+
Coverage Closure
+
SVA
```

The project was intended to strengthen an RTL/VLSI-oriented profile by
demonstrating the complete verification flow for a standard SoC
protocol.

The important distinction is:

> The project demonstrates the ability to systematically verify RTL,
> rather than simply demonstrate that an RTL block can produce the
> expected output for a few directed tests.

------------------------------------------------------------------------

# 3. Original Proposal vs Final Implemented Scope

The original project proposal considered a broader architecture in which
an AXI4-Lite peripheral would integrate a FIFO backend.

The proposal described a concept similar to:

``` text
AXI4-Lite Master
       |
       v
AXI4-Lite Slave
       |
  +----+----+
  |         |
Register   FIFO
Bank      Backend
```

The proposal also listed FIFO boundary verification as a target.

During implementation, the scope was intentionally narrowed.

## Why?

The primary goal became **verification depth**, not RTL size.

A smaller register-mapped AXI4-Lite DUT allowed the project to spend
more effort on:

-   correct AW/W independence;
-   VALID/READY handshaking;
-   WSTRB semantics;
-   read-only protection;
-   invalid and misaligned accesses;
-   backpressure;
-   reference-model checking;
-   constrained-random stimulus;
-   functional coverage;
-   coverage closure;
-   assertions.

Therefore, the final implemented and verified DUT is a **register-mapped
AXI4-Lite slave**.

### Important reporting rule

Do **not** claim the FIFO-integrated architecture from the original
proposal as part of the final project unless it is subsequently
integrated into the actual DUT and verified.

This report intentionally separates the original proposal from the final
implementation.

------------------------------------------------------------------------

# 4. Final Project Scope

The final project contains:

### RTL

-   32-bit AXI4-Lite slave
-   independent AW and W channel handling
-   read path
-   write response path
-   read response path
-   register bank
-   address decoding
-   read-only protection
-   invalid-address detection
-   misaligned-address detection
-   WSTRB byte enables
-   COUNT tracking
-   reset handling
-   response/backpressure handling

### UVM

-   SystemVerilog interface
-   sequence item
-   sequence
-   sequencer
-   driver
-   monitor
-   agent
-   environment
-   scoreboard
-   coverage
-   test

### Verification

-   directed smoke test
-   deterministic register-map tests
-   WSTRB testing
-   AW-first testing
-   W-first testing
-   same-cycle AW/W testing
-   BREADY backpressure
-   RREADY backpressure
-   read-only write protection
-   invalid addresses
-   misaligned addresses
-   constrained-random regression
-   functional coverage
-   coverage closure
-   SVA protocol checking

------------------------------------------------------------------------

# 5. AXI4-Lite Protocol Understanding

AXI4-Lite has five independent channels.

## 5.1 Write Address Channel

``` text
AWADDR
AWVALID
AWREADY
```

A transfer occurs on a rising clock edge when:

``` text
AWVALID && AWREADY
```

The slave captures the address at that transfer.

## 5.2 Write Data Channel

``` text
WDATA
WSTRB
WVALID
WREADY
```

A transfer occurs when:

``` text
WVALID && WREADY
```

The slave captures data and byte enables.

## 5.3 Write Response Channel

``` text
BRESP
BVALID
BREADY
```

A response transfer occurs when:

``` text
BVALID && BREADY
```

The slave must hold the response until the master accepts it.

## 5.4 Read Address Channel

``` text
ARADDR
ARVALID
ARREADY
```

A read address transfer occurs when:

``` text
ARVALID && ARREADY
```

## 5.5 Read Data Channel

``` text
RDATA
RRESP
RVALID
RREADY
```

The response is accepted when:

``` text
RVALID && RREADY
```

The response information must remain stable while the slave is waiting
for `RREADY`.

------------------------------------------------------------------------

# 6. The Main Protocol Challenge: AW and W Are Independent

One of the most important implementation and verification decisions was
not assuming that the write address and write data arrive together.

AXI4-Lite permits:

### AW first

``` text
Cycle N:
    AWVALID && AWREADY

Cycle N+1:
    WVALID && WREADY
```

### W first

``` text
Cycle N:
    WVALID && WREADY

Cycle N+1:
    AWVALID && AWREADY
```

### Same cycle

``` text
Cycle N:
    AWVALID && AWREADY
    WVALID  && WREADY
```

The DUT therefore independently captures:

``` text
AW
W
```

and performs the write only after both have been accepted.

This became a central functional and coverage requirement.

------------------------------------------------------------------------

# 7. Final Register Map

The final register map is:

  Address   Register   Access   Reset
  --------- ---------- -------- --------------
  `0x00`    CONTROL    RW       `0x00000000`
  `0x04`    STATUS     RO       `0x00000001`
  `0x08`    DATA_IN    RW       `0x00000000`
  `0x0C`    DATA_OUT   RW       `0x00000000`
  `0x10`    CONFIG     RW       `0x00000000`
  `0x14`    COUNT      RO       `0x00000000`
  `0x18`    VERSION    RO       `0x00010000`
  `0x1C`    SCRATCH    RW       `0x00000000`

Valid aligned register addresses are:

``` text
0x00, 0x04, 0x08, 0x0C,
0x10, 0x14, 0x18, 0x1C
```

Addresses `0x20` and above are outside the implemented map.

------------------------------------------------------------------------

# 8. Register Access Semantics

## RW Registers

The RW registers are:

``` text
CONTROL
DATA_IN
DATA_OUT
CONFIG
SCRATCH
```

A valid write produces:

``` text
BRESP = OKAY
```

A valid read produces:

``` text
RRESP = OKAY
```

## RO Registers

The RO registers are:

``` text
STATUS
COUNT
VERSION
```

Reading them is valid.

Writing them produces:

``` text
BRESP = SLVERR
```

and must not modify their values.

## Invalid Access

For an invalid write:

``` text
register state unchanged
BRESP = SLVERR
```

For an invalid read:

``` text
RDATA = 0
RRESP = SLVERR
```

## Misaligned Access

Addresses not aligned to 4-byte boundaries are rejected.

For example:

``` text
0x01
0x02
0x03
0x05
...
```

are not treated as valid register accesses.

------------------------------------------------------------------------

# 9. WSTRB Implementation

For the 32-bit data bus:

``` text
WSTRB[0] -> bits [7:0]
WSTRB[1] -> bits [15:8]
WSTRB[2] -> bits [23:16]
WSTRB[3] -> bits [31:24]
```

The new register value is constructed byte by byte.

For example:

``` text
old  = 0x11223344
data = 0xAABBCCDD
WSTRB = 0011
```

Only bytes 0 and 1 change:

``` text
result = 0x1122CCDD
```

The project explicitly tested all 16 WSTRB patterns, including:

``` text
0000
0001
0010
0011
0100
0101
0110
0111
1000
1001
1010
1011
1100
1101
1110
1111
```

The `0000` case was intentionally verified as a valid write transaction
that leaves the register value unchanged.

------------------------------------------------------------------------

# 10. COUNT Behavior

COUNT is read-only to the AXI master.

It increments once for every successful RW write.

The important corner case is:

``` text
WSTRB = 0000
```

Even though no byte changes, the AXI write itself is valid, so the
transaction still increments COUNT.

The deterministic regression expected:

``` text
Final COUNT = 27 = 0x1B
```

This became a useful end-to-end consistency check.

------------------------------------------------------------------------

# 11. RTL Architecture

The RTL was intentionally decomposed into separate functional blocks.

``` text
                 AXI4-Lite
                    |
        +-----------+-----------+
        |                       |
        v                       v
   Write Path               Read Path
        |                       |
        +-----------+-----------+
                    |
                    v
              Register Bank
```

The main files were organized as:

``` text
rtl/
├── top_module.v
├── write_path.v
├── read_path.v
└── register_bank.v
```

The RTL itself is plain Verilog, while the testbench/UVM layer uses
SystemVerilog.

------------------------------------------------------------------------

# 12. Write Path Design

The write path independently captures:

``` text
AW
W
```

and waits until both are available.

The conceptual state flow is:

``` text
WR_IDLE
   |
   v
WR_EXEC
   |
   v
WR_RESP
   |
   +---- BREADY ----> WR_IDLE
```

The important behavior is:

``` text
AW may arrive first
W may arrive first
AW and W may arrive together
```

The response is generated only after the write information is complete.

`BVALID` remains asserted while `BREADY` is low.

------------------------------------------------------------------------

# 13. Read Path Design

The read path uses:

``` text
RD_IDLE
   |
   v
RD_DEC
   |
   v
RD_RESP
   |
   +---- RREADY ----> RD_IDLE
```

The read address is captured explicitly.

The register bank determines:

``` text
RDATA
RRESP
```

and the response is held until accepted.

This ensures that read backpressure does not cause response data to
disappear or change prematurely.

------------------------------------------------------------------------

# 14. Register Bank

The register bank handles:

-   address decoding;
-   register storage;
-   reset values;
-   read data selection;
-   read-only identification;
-   WSTRB updates;
-   invalid/misaligned detection;
-   response status;
-   COUNT tracking.

This modularization made the RTL easier to reason about and allowed
protocol handling to remain separate from register semantics.

------------------------------------------------------------------------

# 15. Initial Bring-Up: Directed Smoke Test

Before UVM was introduced, a simple directed testbench was used.

The test:

1.  reset the DUT;
2.  wrote `0xDEADBEEF` to `DATA_IN` at `0x08`;
3.  read it back;
4.  checked the response codes.

Observed result:

``` text
Reset complete: 35 ns
Write complete: 65 ns
BRESP: 0
Read complete: 115 ns
RDATA: DEADBEEF
RRESP: 0

SMOKE TEST PASSED
```

This established that the basic RTL transaction path was working.

------------------------------------------------------------------------

# 16. Why the Smoke Test Came First

Without a directed bring-up test, a later UVM failure could originate
from:

``` text
sequence
driver
interface
DUT
monitor
scoreboard
```

The smoke test reduced the debug search space.

The development principle was:

> First prove that the DUT works. Then prove that the verification
> environment works.

------------------------------------------------------------------------

# 17. UVM Architecture

The final UVM structure was:

``` text
                 TEST
                  |
                  v
               SEQUENCE
                  |
                  v
              SEQUENCER
                  |
                  v
                DRIVER
                  |
                  v
                 DUT
                  |
                  v
               MONITOR
                /    \
               /      \
              v        v
        SCOREBOARD   COVERAGE
```

The monitor is passive.

The driver is active.

The monitor's analysis port feeds both the scoreboard and coverage.

------------------------------------------------------------------------

# 18. Sequence Item

The transaction object contains:

### Stimulus

``` text
operation
addr
data
strb
```

### Response

``` text
read_data
resp
```

### Randomized timing controls

``` text
delay_aw
delay_w
delay_bready
delay_ar
delay_rready
```

### Monitor observations

``` text
aw_cycle
w_cycle
bready_backpressure_cycles
rready_backpressure_cycles
```

This design allowed the same transaction object to represent both
stimulus and observed verification information.

------------------------------------------------------------------------

# 19. Deterministic Verification Sequence

Before large randomized regression, a deterministic sequence was
created.

## Phase 1 --- Register Map

The sequence tested:

1.  CONTROL RW
2.  DATA_IN RW
3.  DATA_OUT RW
4.  CONFIG RW
5.  SCRATCH RW
6.  STATUS RO read
7.  COUNT RO read
8.  VERSION RO read
9.  RO write protection
10. invalid address
11. misaligned address

## Phase 2 --- WSTRB

It tested:

12. initial register value
13. `0001`
14. `0010`
15. `0100`
16. `1000`
17. `0011`
18. `1100`
19. `1010`
20. `0101`
21. `0000`

## Phase 3 --- Protocol Timing

It tested:

22. AW-first
23. W-first
24. same-cycle AW/W
25. BREADY backpressure
26. RREADY backpressure
27. final COUNT

The expected final COUNT was:

``` text
27 = 0x1B
```

------------------------------------------------------------------------

# 20. Driver

The driver converts transaction-level UVM requests into AXI signal
activity.

For a write it:

1.  drives the address channel;
2.  drives the data channel;
3.  waits for the independent handshakes;
4.  waits for BVALID/BREADY;
5.  captures BRESP.

For a read it:

1.  drives AR;
2.  waits for ARVALID/ARREADY;
3.  drives/controls RREADY;
4.  waits for RVALID/RREADY;
5.  captures RDATA/RRESP.

The driver therefore bridges:

``` text
UVM transaction
```

to:

``` text
AXI4-Lite pin-level protocol
```

------------------------------------------------------------------------

# 21. Monitor

The monitor observes actual DUT activity.

For writes it detects:

``` text
AWVALID && AWREADY
WVALID && WREADY
BVALID && BREADY
```

For reads it detects:

``` text
ARVALID && ARREADY
RVALID && RREADY
```

The write monitor independently records:

``` text
AW cycle
W cycle
```

so the transaction can be classified as:

``` text
AW_FIRST
W_FIRST
SAME_CYCLE
```

This was necessary because assuming a fixed AW/W ordering would have
made the monitor itself incorrect.

------------------------------------------------------------------------

# 22. Monitor Timeout Protection

A monitor that waits forever can make a verification environment hang.

A timeout mechanism was therefore added.

The monitor uses a finite limit of:

``` text
TIMEOUT_CYCLES = 1000
```

If an expected handshake does not occur within that limit, a fatal
diagnostic is generated.

This changes:

``` text
infinite simulation wait
```

into:

``` text
actionable verification failure
```

A remaining minor improvement is that the read monitor's AR handshake
wait could also be bounded explicitly in the same manner.

------------------------------------------------------------------------

# 23. Scoreboard

The scoreboard is an independent reference model.

It maintains expected state for:

``` text
CONTROL
DATA_IN
DATA_OUT
CONFIG
SCRATCH
COUNT
```

and models constant/read-only values for:

``` text
STATUS
VERSION
```

The scoreboard does not simply trust the DUT.

It calculates expected results independently and compares them with
monitor observations.

------------------------------------------------------------------------

# 24. Scoreboard Write Checking

For an RW register:

``` text
expected response = OKAY
```

The expected register value is updated using the WSTRB model.

For a RO register:

``` text
expected response = SLVERR
expected value = unchanged
```

For an invalid or misaligned address:

``` text
expected response = SLVERR
expected state = unchanged
```

COUNT is updated in the reference model for every successful RW write,
including the zero-WSTRB case.

------------------------------------------------------------------------

# 25. Scoreboard Read Checking

For valid addresses, expected data is derived from the modeled register
state.

Examples:

``` text
STATUS  -> 0x00000001
VERSION -> 0x00010000
COUNT   -> modeled count
```

For invalid reads:

``` text
expected RDATA = 0
expected RRESP = SLVERR
```

The invalid-read data check was explicitly strengthened so that the
scoreboard verifies both:

``` text
response code
```

and:

``` text
response data
```

------------------------------------------------------------------------

# 26. Agent and Environment

The agent contains:

``` text
sequencer
driver
monitor
```

The environment contains:

``` text
agent
scoreboard
coverage
```

The monitor is connected to both consumers:

``` text
monitor.analysis_port
        |
        +----> scoreboard.analysis_export
        |
        +----> coverage.analysis_export
```

This allows one observation stream to support independent verification
functions.

------------------------------------------------------------------------

# 27. Constrained-Random Testing

After deterministic testing, randomized traffic was introduced.

The randomized fields include:

``` text
operation
address
data
WSTRB
AW delay
W delay
BREADY delay
AR delay
RREADY delay
```

The goal was to produce combinations that would be tedious to enumerate
manually.

Randomization was particularly useful for:

-   protocol timing;
-   backpressure;
-   address selection;
-   WSTRB combinations;
-   read/write mixes.

------------------------------------------------------------------------

# 28. Phase 4B Regression

The completed randomized regression used:

``` text
1000 transactions
```

The final completed result was:

``` text
Total Transactions : 1000
Passed             : 1000
Failed             : 0
UVM Errors         : 0
UVM Warnings       : 0
UVM Fatals         : 0
```

The simulation finished normally at approximately:

``` text
131275 ns
```

------------------------------------------------------------------------

# 29. Runtime Issue During Random Regression

An earlier run was stopped because the simulation runtime was too short.

This initially could look like a test failure, but inspection showed
that the test had simply not been allowed enough simulation time to
finish all 1000 transactions.

After increasing the runtime, the complete regression finished normally.

The lesson was:

> A simulation that stops before the expected transaction count is
> reached is not automatically a DUT failure.

The debug process should distinguish:

``` text
functional failure
```

from:

``` text
testbench/runtime termination
```

------------------------------------------------------------------------

# 30. Functional Coverage Model

The coverage model tracks the actual verification goals.

Main coverpoints:

``` text
operation
address type
register type
WSTRB exact pattern
WSTRB category
AW/W ordering
BREADY backpressure
RREADY backpressure
response
```

Address classification:

``` text
VALID_ALIGNED
MISALIGNED
INVALID_ADDR
```

Register classification:

``` text
RW_REG
RO_REG
```

Write ordering:

``` text
AW_FIRST
W_FIRST
SAME_CYCLE
```

Response:

``` text
OKAY
SLVERR
```

------------------------------------------------------------------------

# 31. WSTRB Coverage

Exact coverage was collected for all 16 WSTRB values.

In addition, category coverage grouped the patterns into:

``` text
all_zeros
all_ones
single_byte
multi_byte
```

This provides both:

``` text
exhaustive exact-pattern coverage
```

and:

``` text
higher-level semantic coverage
```

------------------------------------------------------------------------

# 32. First Coverage Result: 88.89%

The first major coverage-closure run produced approximately:

``` text
88.89% functional coverage
```

This was not caused by a functional DUT failure.

The individual coverpoints had reached full coverage, but several
crosses were only partially covered.

The problematic cross scenarios were:

``` text
WRITE × RO register × response
WRITE × invalid address × response
READ × invalid address × response
```

------------------------------------------------------------------------

# 33. Coverage Cross Root Cause

The initial cross definitions represented broad Cartesian products.

For example:

``` text
operation × register_type × response
```

mathematically creates many combinations.

But the verification objective was not to cover every possible
mathematical combination.

The meaningful illegal-access scenario was:

``` text
WRITE
+
RO_REG
+
SLVERR
```

Likewise:

``` text
WRITE
+
INVALID_ADDR
+
SLVERR
```

and:

``` text
READ
+
INVALID_ADDR
+
SLVERR
```

The irrelevant combinations were therefore inflating the coverage
denominator.

------------------------------------------------------------------------

# 34. Coverage Cross Resolution

The cross bins were rewritten to explicitly target the meaningful
scenarios.

The final coverage model directly checked:

``` text
WRITE × RO_REG × SLVERR
```

``` text
WRITE × INVALID_ADDR × SLVERR
```

``` text
READ × INVALID_ADDR × SLVERR
```

This is a significant verification lesson:

> Coverage closure is not always achieved by adding more stimulus.
> Sometimes the coverage model itself must be corrected so that it
> measures the intended verification goal.

------------------------------------------------------------------------

# 35. Address Classification Issue

A second coverage-model problem was found in address classification.

Valid aligned addresses end at:

``` text
0x1C
```

The next aligned boundary is:

``` text
0x20
```

The initial classification effectively used:

``` text
address > 0x1C
```

as the invalid-address condition.

That caused addresses such as:

``` text
0x1D
0x1E
0x1F
```

to be classified as invalid rather than being treated as misaligned
addresses.

The logic was corrected to:

``` text
if address >= 0x20:
    INVALID_ADDR
else if address[1:0] != 2'b00:
    MISALIGNED
else:
    VALID_ALIGNED
```

This made the coverage model correctly distinguish:

``` text
valid aligned
misaligned
outside implemented address space
```

------------------------------------------------------------------------

# 36. Final Phase 5 Coverage Result

After correcting the cross bins and address classification:

``` text
cp_op               : 100.00%
cp_addr_type        : 100.00%
cp_reg_type         : 100.00%
cp_wstrb_exact      : 100.00%
cp_wstrb_categories : 100.00%
cp_write_order      : 100.00%
cp_bready_bp        : 100.00%
cp_rready_bp        : 100.00%
cp_resp             : 100.00%

cp_write_ro_err     : 100.00%
cp_write_inv_err    : 100.00%
cp_read_inv_err     : 100.00%

Functional Coverage : 100.00%
```

This was the final functional coverage result.

------------------------------------------------------------------------

# 37. Why 100% Coverage Is Meaningful Here

The 100% result is meaningful only within the defined coverage model.

It means the regression exercised every defined bin for:

-   operation;
-   address categories;
-   register categories;
-   all WSTRB patterns;
-   WSTRB categories;
-   AW/W ordering;
-   backpressure;
-   response type;
-   defined negative-access crosses.

It does **not** mean that every possible AXI behavior in existence has
been verified.

The report should therefore say:

> **100% functional coverage for the defined verification model**

rather than implying complete formal proof of all AXI behavior.

------------------------------------------------------------------------

# 38. SVA Layer

After functional verification and coverage closure, a SystemVerilog
Assertions layer was added.

The purpose of SVA was to check temporal/protocol properties that are
different from scoreboard checking.

The verification responsibilities can be separated as:

``` text
Scoreboard:
    Is the functional result correct?

Coverage:
    Did we exercise the planned scenarios?

SVA:
    Did the interface obey temporal/protocol rules?
```

This separation is a key part of the project's verification methodology.

------------------------------------------------------------------------

# 39. SVA Reset Assertion Issue

The final recorded SVA run produced:

``` text
Time: 5 ns
[SVA-RST] Valids not deasserted during reset!
```

The DUT uses:

``` text
synchronous active-low reset
```

With synchronous reset, asserting `ARESETn = 0` does not necessarily
change registered outputs immediately at an arbitrary simulation time.

The registered state is updated on the active clock edge.

Therefore, an assertion that checks:

``` text
if reset is low -> valid signals must already be low
```

at a time before the first reset clock edge can observe the old state.

This is consistent with a reset-timing mismatch in the assertion rather
than automatically proving a DUT bug.

------------------------------------------------------------------------

# 40. Why the SVA Message Must Not Be Hidden

The UVM test still reported:

``` text
RESULT: PASS
```

because the test's pass criteria were based on:

``` text
transaction count
scoreboard failures
UVM error count
UVM fatal count
```

The raw SVA `$error` was not included in that UVM error counter.

Therefore the technically accurate statement is:

``` text
UVM functional regression: PASS
Functional coverage: 100%
SVA layer: implemented
One reset-time SVA assertion: requires correction
```

The project should not be described as:

``` text
all assertions passed
```

until that issue is corrected and rerun.

------------------------------------------------------------------------

# 41. Correct SVA Resolution Direction

Because reset is synchronous, the reset assertion should be evaluated
with synchronous clock semantics.

The property should distinguish between:

``` text
reset signal asserted
```

and:

``` text
a clock edge has occurred while reset is asserted
```

After the clocked reset takes effect, the expected registered outputs
can be checked.

The exact fix should be made against the current
`axi4lite_assertions.sv` file, but the core principle is:

> Assertion timing must match the reset semantics of the DUT.

------------------------------------------------------------------------

# 42. Problems Encountered --- Complete Summary

  -----------------------------------------------------------------------
  Problem           Root Cause        Resolution        Outcome
  ----------------- ----------------- ----------------- -----------------
  Need to validate  Multiple possible Directed smoke    Basic path proven
  RTL before UVM    debug layers      test              

  AW/W ordering     AXI channels are  Separate AW/W     Three orderings
  complexity        independent       capture           supported

  Potential monitor No finite timeout Added timeout     Diagnostic
  hangs                               counters          failures instead
                                                        of hangs

  Random run ended  Insufficient      Increased runtime 1000 transactions
  early             simulation                          completed
                    runtime                             

  Initial coverage  Cross bins        Explicit          Cross coverage
  \~88.89%          included          meaningful cross  closed
                    irrelevant        bins              
                    combinations                        

  Wrong address     Invalid threshold `>= 0x20` then    Address coverage
  classification    checked too early alignment check   corrected

  Need independent  Driver cannot be  Reference-model   Independent
  checking          the oracle        scoreboard        functional
                                                        checking

  Need              Scoreboard does   Added SVA         Protocol layer
  protocol-level    not express all                     added
  checking          temporal behavior                   

  Reset SVA failure Synchronous reset Requires          Functional
                    checked before    clock-aligned     regression
                    clocked reset     assertion fix     unaffected
                    effect                              
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# 43. Verification Plan

The verification plan can be summarized as follows.

## Functional Tests

-   RW register read/write
-   RO register reads
-   RO write protection
-   invalid addresses
-   misaligned addresses
-   WSTRB behavior
-   COUNT behavior

## Protocol Tests

-   AW-first
-   W-first
-   same-cycle AW/W
-   BREADY backpressure
-   RREADY backpressure

## Randomized Tests

-   random operation
-   random address
-   random data
-   random WSTRB
-   randomized channel delays
-   randomized response backpressure

## Coverage

-   operation
-   address type
-   register type
-   WSTRB
-   ordering
-   backpressure
-   response
-   negative-access crosses

## Assertions

-   reset behavior
-   VALID/READY protocol behavior
-   response stability/protocol properties

------------------------------------------------------------------------

# 44. Final Project Architecture

``` text
                    +----------------------+
                    |      UVM TEST        |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |       SEQUENCE       |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |      SEQUENCER       |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |       DRIVER         |
                    +----------+-----------+
                               |
                               v
             +---------------------------------------+
             |             AXI4-LITE DUT             |
             |                                       |
             |   +-------------+  +-------------+   |
             |   | Write Path  |  | Read Path   |   |
             |   +------+------+  +------+------+
             |          |                |
             |          +-------+--------+
             |                  |
             |          +-------v-------+
             |          | Register Bank |
             |          +---------------+
             +------------------+--------------------+
                                |
                                v
                    +----------------------+
                    |       MONITOR        |
                    +----------+-----------+
                               |
                    +----------+----------+
                    |                     |
                    v                     v
              +-----------+         +-----------+
              | SCOREBOARD|         | COVERAGE  |
              +-----------+         +-----------+

                    +----------------------+
                    |         SVA          |
                    +----------------------+
```

------------------------------------------------------------------------

# 45. Development Methodology

The development process was intentionally incremental.

## Stage 1 --- Understand the protocol

Before writing the UVM environment, establish:

-   five AXI channels;
-   VALID/READY handshake;
-   AW/W independence;
-   response holding;
-   backpressure;
-   error responses.

## Stage 2 --- Build the smallest useful RTL

The DUT was kept compact.

The focus was on:

``` text
protocol correctness
+
register semantics
```

rather than unnecessary RTL complexity.

## Stage 3 --- Prove the DUT with a smoke test

A simple write/read transaction established the baseline.

## Stage 4 --- Build UVM

The UVM architecture was introduced only after basic DUT behavior was
known.

## Stage 5 --- Build an independent reference model

The scoreboard became the functional oracle.

## Stage 6 --- Add deterministic corner cases

This exposed:

-   WSTRB semantics;
-   AW/W ordering;
-   RO protection;
-   invalid accesses;
-   backpressure.

## Stage 7 --- Add constrained random

Random timing and transaction combinations were introduced.

## Stage 8 --- Add coverage

Coverage measured whether the verification plan was actually exercised.

## Stage 9 --- Close coverage

Coverage failures were analyzed rather than blindly increasing test
count.

## Stage 10 --- Add assertions

SVA added temporal/protocol checking.

------------------------------------------------------------------------

# 46. What This Project Demonstrates

The project demonstrates practical understanding of:

### RTL

-   modular RTL design;
-   state-machine based control;
-   memory-mapped registers;
-   handshake-driven interfaces;
-   byte-enable updates;
-   synchronous reset.

### AXI4-Lite

-   five-channel architecture;
-   VALID/READY;
-   independent AW/W;
-   response channels;
-   backpressure;
-   error responses.

### SystemVerilog

-   interfaces;
-   modports;
-   classes;
-   constrained randomization;
-   covergroups;
-   assertions.

### UVM

-   sequence;
-   sequencer;
-   driver;
-   monitor;
-   agent;
-   environment;
-   scoreboard;
-   subscriber/coverage.

### Verification

-   directed testing;
-   negative testing;
-   constrained-random testing;
-   reference modeling;
-   functional coverage;
-   coverage closure;
-   protocol assertions;
-   regression analysis.

------------------------------------------------------------------------

# 47. Important Lessons Learned

## 47.1 A Protocol Is More Than Its Signal List

Knowing that AXI has AW/W/B/AR/R is not enough.

The important behavior is the temporal relationship between:

``` text
VALID
READY
payload
```

and the fact that channels are independent.

## 47.2 Verification Infrastructure Can Have Bugs

A failing coverage result does not automatically mean the DUT is wrong.

The 88.89% result demonstrated that the coverage model itself needed
refinement.

## 47.3 Random Testing Is Most Useful After Directed Tests

Random testing is powerful, but it should not replace basic
deterministic tests.

The deterministic sequence established the expected behavior first.

## 47.4 A Monitor Should Observe the DUT

The monitor should capture actual handshakes rather than assuming that
the driver successfully performed the transaction.

## 47.5 A Scoreboard Should Be Independent

A good scoreboard is a reference model, not a mirror of the DUT
implementation.

## 47.6 Timeouts Make Verification More Robust

A deadlock should become a diagnostic error rather than an infinite
simulation.

## 47.7 Reset Semantics Matter in Assertions

An assertion must understand whether reset is:

``` text
asynchronous
```

or:

``` text
synchronous
```

The property must match the RTL.

------------------------------------------------------------------------

# 48. What Should Be Claimed in the Final Report

Safe and accurate claims include:

> Developed a 32-bit AXI4-Lite slave with memory-mapped register access.

> Implemented independent AXI AW and W channel handling.

> Implemented WSTRB-based byte-level register updates.

> Verified read-only protection, invalid addresses, misaligned accesses,
> and response backpressure.

> Built a reusable UVM environment with sequence, sequencer, driver,
> monitor, scoreboard, and functional coverage.

> Ran a 1000-transaction constrained-random regression with 1000/1000
> passing transactions.

> Achieved 100% functional coverage for the defined coverage model.

> Implemented SVA-based protocol checking.

Until the reset assertion is corrected, avoid:

> All SVA assertions passed.

or:

> Assertion-clean regression.

------------------------------------------------------------------------

# 49. What Should NOT Be Claimed

Do not claim:

-   FIFO integration in the final DUT;
-   AXI4 bursts;
-   multiple outstanding transactions;
-   AXI IDs;
-   multiple masters;
-   AXI interconnect;
-   DMA;
-   formal proof;
-   complete AXI protocol compliance;
-   assertion-clean signoff;

unless those features are actually implemented and verified.

The project is stronger when it is technically precise than when it is
artificially made to sound larger.

------------------------------------------------------------------------

# 50. Suggested Final Report Structure

The final academic/project report should be organized as:

``` text
1. Abstract

2. Introduction
   2.1 Motivation
   2.2 Problem Statement
   2.3 Objectives

3. AXI4-Lite Protocol
   3.1 Five Channels
   3.2 VALID/READY
   3.3 Write Transactions
   3.4 Read Transactions
   3.5 Backpressure
   3.6 Error Responses

4. System Architecture
   4.1 Top-Level Architecture
   4.2 Write Path
   4.3 Read Path
   4.4 Register Bank

5. RTL Implementation
   5.1 Register Map
   5.2 WSTRB
   5.3 Error Handling
   5.4 Reset
   5.5 Response Handling

6. UVM Verification Architecture
   6.1 Interface
   6.2 Sequence Item
   6.3 Sequence
   6.4 Sequencer
   6.5 Driver
   6.6 Monitor
   6.7 Scoreboard
   6.8 Coverage

7. Verification Plan
   7.1 Directed Tests
   7.2 Corner Cases
   7.3 Constrained Random
   7.4 Negative Testing

8. Coverage and Coverage Closure
   8.1 Coverage Model
   8.2 Initial Coverage Result
   8.3 Coverage Problems
   8.4 Coverage Fixes
   8.5 Final Coverage

9. SVA
   9.1 Assertion Strategy
   9.2 Reset Assertion Issue
   9.3 Resolution

10. Results
    10.1 Regression
    10.2 Scoreboard
    10.3 Coverage
    10.4 Assertions

11. Issues Encountered and Debugging

12. Limitations

13. Future Work

14. Conclusion
```

------------------------------------------------------------------------

# 51. Recommended Figures for the Report

The final report should include diagrams/screenshots for:

1.  **AXI4-Lite five-channel interface**
2.  **Top-level RTL architecture**
3.  **Write-path state machine**
4.  **Read-path state machine**
5.  **Register map**
6.  **WSTRB byte-lane example**
7.  **UVM component hierarchy**
8.  **Monitor-to-scoreboard/coverage data flow**
9.  **Functional coverage report**
10. **1000-transaction regression result**
11. **SVA assertion result after the reset issue is fixed**

A useful coverage-closure figure is:

``` text
Regression
    ↓
Coverage Report
    ↓
Coverage Gap
    ↓
Root-Cause Analysis
    ↓
Stimulus / Coverage-Model Update
    ↓
Regression
    ↓
100% Defined Functional Coverage
```

------------------------------------------------------------------------

# 52. Final Results Table

  Verification Area               Result
  ------------------------------- ----------------------------
  Basic RTL smoke test            PASS
  Register-map tests              PASS
  WSTRB tests                     PASS
  AW-first                        PASS
  W-first                         PASS
  Same-cycle AW/W                 PASS
  BREADY backpressure             PASS
  RREADY backpressure             PASS
  RO write protection             PASS
  Invalid address                 PASS
  Misaligned address              PASS
  Constrained-random regression   PASS
  Randomized transactions         1000
  Transactions passed             1000
  Transactions failed             0
  UVM errors                      0
  UVM warnings                    0
  UVM fatals                      0
  Functional coverage             100%
  SVA implementation              Complete
  SVA reset assertion             Issue observed
  Assertion-clean signoff         Pending reset-property fix

------------------------------------------------------------------------

# 53. Final Project Positioning

The project can be positioned as a **verification-focused RTL project**.

The core story is:

> I designed a compact 32-bit AXI4-Lite slave and then verified it
> systematically. I first proved the RTL with directed tests, built a
> reusable UVM environment, created an independent reference model,
> stressed AXI channel ordering and backpressure with constrained-random
> stimulus, measured functional coverage, analyzed coverage gaps, and
> closed the defined coverage model to 100%. I also added SVA protocol
> checks and identified a reset-timing issue in the assertion layer.

This is stronger than simply saying:

> "I made an AXI project."

------------------------------------------------------------------------

# 54. Resume-Level Description

## Detailed version

**AXI4-Lite Slave Verification \| SystemVerilog & UVM**

> Developed and verified a 32-bit AXI4-Lite slave with register-mapped
> access, independent AW/W channels, WSTRB byte enables, error
> responses, and backpressure handling. Built a reusable UVM environment
> with constrained-random sequences, driver, monitor, reference-model
> scoreboard, and functional coverage. Achieved 1000/1000 passing
> randomized transactions and 100% functional coverage across protocol
> and corner-case scenarios.

## Compact version

> Built and verified a 32-bit AXI4-Lite slave with independent AW/W
> handling, WSTRB support, error responses, and backpressure; developed
> a UVM environment with constrained-random stimulus, scoreboard
> checking, functional coverage, and protocol assertions, achieving
> 1000/1000 passing transactions and 100% functional coverage.

------------------------------------------------------------------------

# 55. Interview Questions This Project Should Prepare You For

## Why AXI4-Lite?

Because it is a standard memory-mapped SoC interface and exposes
meaningful verification challenges without the complexity of bursts and
IDs.

## Why are AW and W separate?

AXI separates write address and write data channels so they can be
transferred independently.

## What happens if W arrives before AW?

The slave stores the write data and waits for the address.

## What happens if BREADY stays low?

The slave keeps BVALID and the response information stable until the
master accepts the response.

## What is WSTRB?

It identifies which byte lanes of the write data are valid for updating
the register.

## Why use a scoreboard?

To independently predict expected DUT behavior and detect incorrect
register state or response behavior.

## Why use functional coverage?

To determine whether the planned verification scenarios were actually
exercised.

## Why did coverage initially stop at 88.89%?

Because some cross-coverage definitions included irrelevant
combinations, and the address classification initially treated some
misaligned addresses incorrectly.

## How did you reach 100%?

By analyzing the coverage model, correcting the address classification
and defining meaningful cross bins, then rerunning the regression.

## What was the final regression result?

1000/1000 passing transactions, zero UVM errors/warnings/fatals, and
100% functional coverage.

## Did all assertions pass?

Not in the final recorded run. The SVA layer produced a reset-time
assertion failure. The DUT uses synchronous reset, so the assertion
needs to be aligned with the clocked reset semantics before claiming
assertion-clean status.

------------------------------------------------------------------------

# 56. Limitations

The final implementation intentionally remains compact.

It does not implement:

-   AXI4 bursts;
-   AXI IDs;
-   multiple outstanding transactions;
-   multiple masters;
-   arbitration;
-   AXI interconnect;
-   DMA;
-   a complex accelerator;
-   FIFO backend integration from the original proposal.

The SVA reset assertion also requires correction before full
assertion-clean signoff.

These limitations are acceptable for a focused project because the goal
is verification quality and protocol understanding rather than maximum
RTL complexity.

------------------------------------------------------------------------

# 57. Future Work

Potential extensions are:

## 57.1 Fix and Expand SVA

Correct the reset property and add additional stability/protocol
properties.

## 57.2 Add Code Coverage

Complement functional coverage with statement, branch, condition, and
toggle coverage.

## 57.3 Add Mutation Testing

Intentionally introduce small RTL bugs such as:

-   ignoring WSTRB;
-   assuming AW/W same-cycle;
-   releasing BVALID too early;
-   returning OKAY for invalid addresses;

and demonstrate that the verification environment detects them.

## 57.4 Add UVM RAL

A small Register Abstraction Layer model could make register
verification more scalable.

## 57.5 Integrate a FIFO

If desired, the original FIFO-backed architecture can be revisited as a
separate project extension. It should only be added after the current
register-bank implementation remains stable and the new FIFO behavior is
fully verified.

------------------------------------------------------------------------

# 58. Final Engineering Takeaway

The strongest part of this project is not the number of RTL lines.

It is the workflow:

``` text
Protocol understanding
        ↓
Modular RTL
        ↓
Directed bring-up
        ↓
UVM infrastructure
        ↓
Independent reference model
        ↓
Corner-case testing
        ↓
Constrained random
        ↓
Functional coverage
        ↓
Coverage-gap analysis
        ↓
Coverage closure
        ↓
SVA
        ↓
Regression analysis
        ↓
Technical documentation
```

The project therefore demonstrates the mindset of an RTL verification
engineer:

> **Build the design, define what correctness means, create an
> independent way to check it, measure what has been exercised,
> investigate gaps, close the gaps, and document the remaining
> limitations honestly.**

------------------------------------------------------------------------

# 59. Final One-Paragraph Project Summary

The project implements a 32-bit AXI4-Lite register-mapped slave and
verifies it using a SystemVerilog/UVM environment. The RTL is divided
into write-path, read-path, and register-bank modules, with independent
AW/W handling, WSTRB byte enables, read-only protection,
invalid/misaligned address detection, response generation, and
backpressure handling. The verification environment contains a sequence
item, constrained-random sequences, sequencer, driver, monitor, agent,
scoreboard, and functional coverage model. Verification progressed from
a directed smoke test to deterministic register and protocol tests and
finally a 1000-transaction randomized regression. The regression
achieved 1000/1000 passing transactions, zero UVM
errors/warnings/fatals, and 100% functional coverage for the defined
model. Coverage closure required correcting cross-bin definitions and
address classification. An SVA layer was also implemented; the recorded
run exposed a reset-time assertion issue associated with the synchronous
reset semantics, so the project should not yet be described as
completely assertion-clean.

------------------------------------------------------------------------

# 60. Final Status

**PROJECT FUNCTIONAL STATUS: COMPLETE**

**UVM REGRESSION: PASS**

**1000/1000 TRANSACTIONS: PASS**

**FUNCTIONAL COVERAGE: 100%**

**SVA LAYER: IMPLEMENTED**

**SVA RESET ASSERTION: REQUIRES FINAL FIX**

**FINAL REPORT STATUS: READY TO DOCUMENT**
