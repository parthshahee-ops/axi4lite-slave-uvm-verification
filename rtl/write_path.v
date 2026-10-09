`timescale 1ns / 1ps
// WRITE PATH
// AW and W are independent channels. Each is captured when its own VALID/READY 
// handshake occurs; the write is executed only after both halves are available. 
// This handles AW-first, W-first, and AW+W in the same cycle.

module axi4lite_write #(
    parameter ADDR_WIDTH = 32
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

    // Reg Bank Interface
    output reg  [ADDR_WIDTH-1:0]  awaddr_reg,
    output reg  [31:0]            wdata_reg,
    output reg  [3:0]             wstrb_reg,
    input  wire                   wr_reg_is_rw,
    output wire                   wr_en
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // Write FSM: IDLE collects AW/W, EXEC updates the register bank, RESP holds B until BREADY
    localparam [1:0] WR_IDLE = 2'd0,       
                     WR_EXEC = 2'd1,       
                     WR_RESP = 2'd2;       

    reg [1:0]            wr_state;
    reg                  aw_received;
    reg                  w_received;
    reg                  bvalid_r;
    reg [1:0]            bresp_r;

    // READY is high only in WR_IDLE and only for a channel not yet captured, so exactly one AW and one W are accepted per write.
    assign AWREADY = (wr_state == WR_IDLE) && !aw_received;
    assign WREADY  = (wr_state == WR_IDLE) && !w_received;
    assign BVALID  = bvalid_r;
    assign BRESP   = bresp_r;

    // Handshake = VALID && READY on the current clock edge.
    wire aw_hs = AWVALID && AWREADY;
    wire w_hs  = WVALID  && WREADY;

    // Trigger the write enable when executing a valid read/write operation
    assign wr_en = (wr_state == WR_EXEC) && wr_reg_is_rw;

    // Write path: synchronous active-low reset, then AW/W capture, then the write controller.
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            // Reset clears FSM state, capture flags, holding registers, BVALID/BRESP.
            wr_state     <= WR_IDLE;
            aw_received  <= 1'b0;
            w_received   <= 1'b0;
            awaddr_reg   <= {ADDR_WIDTH{1'b0}};
            wdata_reg    <= 32'h0;
            wstrb_reg    <= 4'h0;
            bvalid_r     <= 1'b0;
            bresp_r      <= RESP_OKAY;
        end else begin
            // ---- Channel capture (independent: any order or same cycle) ----
            // AW and W are captured independently. Either handshake sets its own flag, in any order or in the same cycle.
            if (aw_hs) begin
                awaddr_reg  <= AWADDR;
                aw_received <= 1'b1;
            end
            if (w_hs) begin
                wdata_reg   <= WDATA;
                wstrb_reg   <= WSTRB;
                w_received  <= 1'b1;
            end

            // ---- Write controller ----
            case (wr_state)
                WR_IDLE: begin
                    // Move on as soon as both halves are (or are being) captured
                    // "|| aw_hs / w_hs" accounts for a handshake happening on THIS edge. Do not simplify to (aw_received && w_received): the same-cycle AW+W case would take an extra cycle.
                    if ((aw_received || aw_hs) && (w_received || w_hs))
                        wr_state <= WR_EXEC;
                end

                WR_EXEC: begin
                    // One-cycle execute: decode the registered address, apply WSTRB-masked data to a RW register (OKAY, COUNT+1), or return SLVERR with no state change. Registered AW/W values are valid here because capture happened on an earlier edge.
                    bvalid_r <= 1'b1;
                    wr_state <= WR_RESP;
                    if (wr_reg_is_rw) begin
                        bresp_r <= RESP_OKAY;
                    end else begin
                        // SLVERR cases: write to RO register, out-of-range address, or misaligned address.
                        bresp_r <= RESP_SLVERR;
                    end
                end

                WR_RESP: begin
                    // Hold BVALID and BRESP stable until BVALID && BREADY. Nothing in this state changes bvalid_r or bresp_r while BREADY is low (no withdrawal under backpressure). Flags are cleared only on the B handshake, so AWREADY/WREADY stay low until then.
                    if (BREADY) begin             // bvalid_r is 1 here
                        bvalid_r    <= 1'b0;
                        aw_received <= 1'b0;
                        w_received  <= 1'b0;
                        wr_state    <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

endmodule