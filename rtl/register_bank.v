`timescale 1ns / 1ps
// Register bank storage and decoding logic

module axi4lite_reg_bank #(
    parameter ADDR_WIDTH = 32,
    parameter [31:0] VERSION_VALUE = 32'h0001_0000
)(
    input  wire                   ACLK,
    input  wire                   ARESETn,

    // Write interface
    input  wire [ADDR_WIDTH-1:0]  awaddr_reg,
    input  wire [31:0]            wdata_reg,
    input  wire [3:0]             wstrb_reg,
    input  wire                   wr_en,
    output wire                   wr_reg_is_rw,

    // Read interface
    input  wire [ADDR_WIDTH-1:0]  araddr_reg,
    output wire                   rd_addr_valid,
    output wire [31:0]            rd_mux
);

    localparam [2:0] IDX_CONTROL = 3'd0;   // 0x00
    localparam [2:0] IDX_STATUS  = 3'd1;   // 0x04
    localparam [2:0] IDX_DATA_IN = 3'd2;   // 0x08
    localparam [2:0] IDX_DATA_OUT= 3'd3;   // 0x0C
    localparam [2:0] IDX_CONFIG  = 3'd4;   // 0x10
    localparam [2:0] IDX_COUNT   = 3'd5;   // 0x14
    localparam [2:0] IDX_VERSION = 3'd6;   // 0x18
    localparam [2:0] IDX_SCRATCH = 3'd7;   // 0x1C

    // RW registers: CONTROL, DATA_IN, DATA_OUT, CONFIG, SCRATCH. COUNT is RO (hardware-updated only).
    reg [31:0] control_reg;
    reg [31:0] data_in_reg;
    reg [31:0] data_out_reg;
    reg [31:0] config_reg;
    reg [31:0] count_reg;
    reg [31:0] scratch_reg;

    // STATUS and VERSION are constants (no storage). VERSION is set by the VERSION_VALUE parameter.
    wire [31:0] status_val  = 32'h0000_0001;
    wire [31:0] version_val = VERSION_VALUE;

    // Helpers
    // WSTRB: one bit per byte lane. A set bit takes the new byte, a clear bit keeps the old byte. WSTRB = 0000 leaves the register unchanged.
    function [31:0] apply_strb;
        input [31:0] old_v;
        input [31:0] new_v;
        input [3:0]  strb;
        begin
            apply_strb = { strb[3] ? new_v[31:24] : old_v[31:24],
                           strb[2] ? new_v[23:16] : old_v[23:16],
                           strb[1] ? new_v[15:8]  : old_v[15:8],
                           strb[0] ? new_v[7:0]   : old_v[7:0] };
        end
    endfunction

    // Address decode chain (used by both read and write paths):
    //   address -> in range? aligned?  -> address_valid
    //           -> register index      -> RW / RO
    //   !address_valid         => SLVERR
    //   address_valid && RO    => SLVERR on write, OKAY on read
    //   address_valid && RW    => OKAY

    // Decode step 1a: is the address inside the 32-byte (8 x 32-bit) register window?
    function addr_in_range;
        input [ADDR_WIDTH-1:0] a;
        begin
            addr_in_range = (a[ADDR_WIDTH-1:5] == {(ADDR_WIDTH-5){1'b0}});
        end
    endfunction

    // Decode step 1b: is the address word aligned? Misaligned accesses are treated as invalid.
    function addr_aligned;
        input [ADDR_WIDTH-1:0] a;
        begin
            addr_aligned = (a[1:0] == 2'b00);
        end
    endfunction

    // Decode step 2: RW registers = CONTROL, DATA_IN, DATA_OUT, CONFIG, SCRATCH
    function idx_is_rw;
        input [2:0] idx;
        begin
            idx_is_rw = (idx == IDX_CONTROL) || (idx == IDX_DATA_IN) ||
                        (idx == IDX_DATA_OUT) || (idx == IDX_CONFIG) || (idx == IDX_SCRATCH);
        end
    endfunction

    // Decode of the captured write address
    wire       wr_addr_valid = addr_in_range(awaddr_reg) && addr_aligned(awaddr_reg);
    wire [2:0] wr_idx        = awaddr_reg[4:2];
    assign     wr_reg_is_rw  = wr_addr_valid && idx_is_rw(wr_idx);

    // Decode of the captured read address
    assign     rd_addr_valid = addr_in_range(araddr_reg) && addr_aligned(araddr_reg);
    wire [2:0] rd_idx        = araddr_reg[4:2];

    // Read mux (combinational, sampled into RDATA/RRESP on AR handshake)
    // Pure combinational mux; the result is loaded into rdata_r in RD_DEC, so RDATA never follows later register changes.
    reg [31:0] rd_mux_reg;
    always @(*) begin
        case (rd_idx)
            IDX_CONTROL : rd_mux_reg = control_reg;
            IDX_STATUS  : rd_mux_reg = status_val;
            IDX_DATA_IN : rd_mux_reg = data_in_reg;
            IDX_DATA_OUT: rd_mux_reg = data_out_reg;
            IDX_CONFIG  : rd_mux_reg = config_reg;
            IDX_COUNT   : rd_mux_reg = count_reg;
            IDX_VERSION : rd_mux_reg = version_val;
            IDX_SCRATCH : rd_mux_reg = scratch_reg;
            default     : rd_mux_reg = 32'h0;
        endcase
    end
    assign rd_mux = rd_mux_reg;

    always @(posedge ACLK) begin
        if (!ARESETn) begin
            // Reset clears all RW registers and COUNT.
            control_reg  <= 32'h0;
            data_in_reg  <= 32'h0;
            data_out_reg <= 32'h0;
            config_reg   <= 32'h0;
            count_reg    <= 32'h0;
            scratch_reg  <= 32'h0;
        end else if (wr_en) begin
            // COUNT: +1 per OKAY write. Natural 32-bit wrap, no saturation.
            count_reg <= count_reg + 32'd1;
            case (wr_idx)
                IDX_CONTROL : control_reg  <= apply_strb(control_reg, wdata_reg, wstrb_reg);
                IDX_CONFIG  : config_reg   <= apply_strb(config_reg,  wdata_reg, wstrb_reg);
                IDX_SCRATCH : scratch_reg  <= apply_strb(scratch_reg, wdata_reg, wstrb_reg);
                IDX_DATA_IN : data_in_reg  <= apply_strb(data_in_reg, wdata_reg, wstrb_reg);
                IDX_DATA_OUT: data_out_reg <= apply_strb(data_out_reg, wdata_reg, wstrb_reg);
                default: ;
            endcase
        end
    end

endmodule