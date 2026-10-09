`timescale 1ns / 1ps
// READ PATH
// Read flow: AR handshake -> capture ARADDR -> decode -> RDATA/RRESP -> RVALID. 
// One outstanding read: ARREADY is high only in RD_IDLE.
module axi4lite_read #(
    parameter ADDR_WIDTH = 32
)(
    input  wire                   ACLK,
    input  wire                   ARESETn,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]  ARADDR,
    input  wire                   ARVALID,
    output wire                   ARREADY,

    // Read data channel
    output wire [31:0]            RDATA,
    output wire [1:0]             RRESP,
    output wire                   RVALID,
    input  wire                   RREADY,

    // Reg Bank Interface
    output reg  [ADDR_WIDTH-1:0]  araddr_reg,
    input  wire                   rd_addr_valid,
    input  wire [31:0]            rd_mux
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    // Read FSM: IDLE waits for AR, DEC decodes the captured address, RESP holds R until RREADY
    localparam [1:0] RD_IDLE = 2'd0,
                     RD_DEC  = 2'd1,
                     RD_RESP = 2'd2;

    reg [1:0]   rd_state;
    reg         rvalid_r;
    reg [31:0]  rdata_r;
    reg [1:0]   rresp_r;

    assign ARREADY = (rd_state == RD_IDLE);
    assign RVALID  = rvalid_r;
    assign RDATA   = rdata_r;
    assign RRESP   = rresp_r;

    // AR handshake: VALID && READY on the current edge.
    wire ar_hs = ARVALID && ARREADY;

    always @(posedge ACLK) begin
        if (!ARESETn) begin
            rd_state   <= RD_IDLE;
            araddr_reg <= {ADDR_WIDTH{1'b0}};
            rvalid_r   <= 1'b0;
            rdata_r    <= 32'h0;
            rresp_r    <= RESP_OKAY;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    // Capture ARADDR on the AR handshake.
                    if (ar_hs) begin
                        araddr_reg <= ARADDR;
                        rd_state   <= RD_DEC;
                    end
                end

                RD_DEC: begin
                    // Decode the captured address. Valid register (RW or RO) -> OKAY with register data. Out of range or misaligned -> SLVERR with RDATA = 0. RVALID is raised here. This adds one cycle of read latency.
                    if (rd_addr_valid) begin
                        rdata_r <= rd_mux;
                        rresp_r <= RESP_OKAY;
                    end else begin
                        rdata_r <= 32'h0;
                        rresp_r <= RESP_SLVERR;
                    end
                    rvalid_r <= 1'b1;
                    rd_state <= RD_RESP;
                end

                RD_RESP: begin
                    // Hold RDATA/RRESP stable until RVALID && RREADY. rdata_r, rresp_r and rvalid_r are not modified in this state while RREADY is low.
                    if (RREADY) begin             // rvalid_r is 1 here
                        rvalid_r <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
                
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule