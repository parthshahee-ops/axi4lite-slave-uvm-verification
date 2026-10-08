`timescale 1ns / 1ps
//==============================================================================
// AXI4-Lite Slave with 8-register bank   (Phase 1 DUT) - TOP LEVEL
//------------------------------------------------------------------------------
//  - 32-bit data, ADDR_WIDTH-bit address, active-low synchronous reset
//  - One outstanding write + one outstanding read (independent channels)
//  - Write path : flag-based AW/W capture (AW-first, W-first, same-cycle),
//                 small FSM (IDLE -> EXEC -> RESP), per-byte WSTRB,
//                 RO protection, SLVERR on invalid/misaligned address
//                 AW and W are captured independently; the write executes only
//                 after both halves have been received.
//  - Read path  : FSM (IDLE -> RESP), RVALID/RDATA/RRESP held under backpressure
//
//  Register map                  Access   Reset
//    0x00 CONTROL                RW       0x0000_0000
//    0x04 STATUS                 RO       0x0000_0001
//    0x08 DATA_IN                RW       0x0000_0000
//    0x0C DATA_OUT               RW       0x0000_0000
//    0x10 CONFIG                 RW       0x0000_0000
//    0x14 COUNT                  RO       0x0000_0000  (+1 for every write that returns OKAY)
//    0x18 VERSION                RO       0x0001_0000
//    0x1C SCRATCH                RW       0x0000_0000
//
//  COUNT semantics:
//    COUNT increments once for every write transaction that returns OKAY
//    (including WSTRB = 0000 to a RW register). Writes that return SLVERR do not
//    increment it. It is a 32-bit unsigned counter and wraps FFFF_FFFF -> 0.
//
//  Reset: synchronous, active-low (ARESETn sampled on posedge ACLK). Clears the
//    write FSM, aw/w_received flags, AW/W holding regs, BVALID/BRESP, all RW
//    registers, COUNT, the read FSM, the AR holding reg and RVALID/RDATA/RRESP.
//
//  Responses: OKAY (2'b00) or SLVERR (2'b10)
//    - write to RO reg / unmapped / misaligned address -> SLVERR, nothing changes
//    - read  of unmapped / misaligned address          -> SLVERR, RDATA = 0
//    - write with WSTRB = 0000 to a RW reg             -> OKAY, no data change
//==============================================================================
module axi4lite_slave_top #(
    parameter ADDR_WIDTH = 32,
    parameter [31:0] VERSION_VALUE = 32'h0001_0000
)(
    input  wire                   ACLK,
    input  wire                   ARESETn,

    // Write address channel
    input  wire [ADDR_WIDTH-1:0]  AWADDR,
    input  wire                   AWVALID,
    output wire                   AWREADY,

    // Write data channel
    input  wire [31:0]            WDATA,
    input  wire [3:0]             WSTRB,
    input  wire                   WVALID,
    output wire                   WREADY,

    // Write response channel
    output wire [1:0]             BRESP,
    output wire                   BVALID,
    input  wire                   BREADY,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]  ARADDR,
    input  wire                   ARVALID,
    output wire                   ARREADY,

    // Read data channel
    output wire [31:0]            RDATA,
    output wire [1:0]             RRESP,
    output wire                   RVALID,
    input  wire                   RREADY
);

    // Internal routing wires between controllers and register bank
    wire [ADDR_WIDTH-1:0] awaddr_reg;
    wire [31:0]           wdata_reg;
    wire [3:0]            wstrb_reg;
    wire                  wr_reg_is_rw;
    wire                  wr_en;

    wire [ADDR_WIDTH-1:0] araddr_reg;
    wire                  rd_addr_valid;
    wire [31:0]           rd_mux;

    // Instantiate Write Controller
    axi4lite_write #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_write_ctrl (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY),
        .awaddr_reg(awaddr_reg),
        .wdata_reg(wdata_reg),
        .wstrb_reg(wstrb_reg),
        .wr_reg_is_rw(wr_reg_is_rw),
        .wr_en(wr_en)
    );

    // Instantiate Read Controller
    axi4lite_read #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_read_ctrl (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .ARADDR(ARADDR), .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY),
        .araddr_reg(araddr_reg),
        .rd_addr_valid(rd_addr_valid),
        .rd_mux(rd_mux)
    );

    // Instantiate Register Bank
    axi4lite_reg_bank #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .VERSION_VALUE(VERSION_VALUE)
    ) u_reg_bank (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .awaddr_reg(awaddr_reg),
        .wdata_reg(wdata_reg),
        .wstrb_reg(wstrb_reg),
        .wr_en(wr_en),
        .wr_reg_is_rw(wr_reg_is_rw),
        .araddr_reg(araddr_reg),
        .rd_addr_valid(rd_addr_valid),
        .rd_mux(rd_mux)
    );

endmodule