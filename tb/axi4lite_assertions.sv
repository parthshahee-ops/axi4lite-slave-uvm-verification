`timescale 1ns / 1ps

module axi4lite_assertions (
    input logic        aclk,
    input logic        aresetn,

    // Write Address Channel
    input logic [31:0] awaddr,
    input logic        awvalid,
    input logic        awready,

    // Write Data Channel
    input logic [31:0] wdata,
    input logic [3:0]  wstrb,
    input logic        wvalid,
    input logic        wready,

    // Write Response Channel
    input logic [1:0]  bresp,
    input logic        bvalid,
    input logic        bready,

    // Read Address Channel
    input logic [31:0] araddr,
    input logic        arvalid,
    input logic        arready,

    // Read Data Channel
    input logic [31:0] rdata,
    input logic [1:0]  rresp,
    input logic        rvalid,
    input logic        rready
);

    // =========================================================================
    // 1. RESET BEHAVIOR
    // =========================================================================
    // Check after time 0 that while reset is asserted, no valid signal is active
    property p_reset_val_low;
        @(posedge aclk)
        ($time > 0 && !aresetn) |-> (awvalid !== 1'b1 &&
                                     wvalid  !== 1'b1 &&
                                     arvalid !== 1'b1 &&
                                     bvalid  !== 1'b1 &&
                                     rvalid  !== 1'b1);
    endproperty
    a_reset_val_low: assert property (p_reset_val_low)
        else $error("[SVA-RST] Valids asserted high during reset!");

    // =========================================================================
    // 2. MASTER VALID & PAYLOAD PERSISTENCE (AW, W, AR)
    // =========================================================================
    property p_aw_stability;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> (awvalid && $stable(awaddr));
    endproperty
    a_aw_stability: assert property (p_aw_stability)
        else $error("[SVA-M-AW] AWVALID or AWADDR destabilized before AWREADY handshake!");

    property p_w_stability;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> (wvalid && $stable(wdata) && $stable(wstrb));
    endproperty
    a_w_stability: assert property (p_w_stability)
        else $error("[SVA-M-W] WVALID, WDATA, or WSTRB destabilized before WREADY handshake!");

    property p_ar_stability;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> (arvalid && $stable(araddr));
    endproperty
    a_ar_stability: assert property (p_ar_stability)
        else $error("[SVA-M-AR] ARVALID or ARADDR destabilized before ARREADY handshake!");

    // =========================================================================
    // 3. SLAVE RESPONSE STABILITY (B, R)
    // =========================================================================
    property p_b_stability;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> (bvalid && $stable(bresp));
    endproperty
    a_b_stability: assert property (p_b_stability)
        else $error("[SVA-S-B] BVALID or BRESP destabilized before BREADY handshake!");

    property p_r_stability;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> (rvalid && $stable(rdata) && $stable(rresp));
    endproperty
    a_r_stability: assert property (p_r_stability)
        else $error("[SVA-S-R] RVALID, RDATA, or RRESP destabilized before RREADY handshake!");

    // =========================================================================
    // 4. PROTOCOL SEQUENCING
    // =========================================================================
    property p_bvalid_handshake_drop;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && $fell(bvalid)) |-> $past(bvalid && bready);
    endproperty
    a_bvalid_handshake_drop: assert property (p_bvalid_handshake_drop)
        else $error("[SVA-SEQ-B] BVALID dropped without handshake!");

    property p_rvalid_handshake_drop;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && $fell(rvalid)) |-> $past(rvalid && rready);
    endproperty
    a_rvalid_handshake_drop: assert property (p_rvalid_handshake_drop)
        else $error("[SVA-SEQ-R] RVALID dropped without handshake!");

endmodule
