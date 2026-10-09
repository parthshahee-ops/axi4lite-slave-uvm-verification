`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// PHASES 1-3: DETERMINISTIC REGISTER & PROTOCOL VERIFICATION

class axi4lite_reg_test_seq extends uvm_sequence #(axi4lite_seq_item);

    `uvm_object_utils(axi4lite_reg_test_seq)

    function new(string name = "axi4lite_reg_test_seq");
        super.new(name);
    endfunction

    virtual task do_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb = 4'hF, int d_aw = 0, int d_w = 0, int d_b = 0);
        axi4lite_seq_item req;
        req = axi4lite_seq_item::type_id::create("req_write");

        start_item(req);
        if (!req.randomize() with {
            operation    == axi4lite_seq_item::WRITE;
            addr         == local::addr;
            data         == local::data;
            strb         == local::strb;
            delay_aw     == local::d_aw;
            delay_w      == local::d_w;
            delay_bready == local::d_b;
        }) begin
            `uvm_fatal(get_type_name(), "do_write randomization failed")
        end
        finish_item(req);
    endtask

    virtual task do_read(bit [31:0] addr, int d_ar = 0, int d_r = 0);
        axi4lite_seq_item req;
        req = axi4lite_seq_item::type_id::create("req_read");

        start_item(req);
        if (!req.randomize() with {
            operation    == axi4lite_seq_item::READ;
            addr         == local::addr;
            delay_ar     == local::d_ar;
            delay_rready == local::d_r;
        }) begin
            `uvm_fatal(get_type_name(), "do_read randomization failed")
        end
        finish_item(req);
    endtask

    virtual task body();
        `uvm_info("CLEAN", "============================================================\n              AXI4-LITE REGISTER TEST (PHASE 1)\n============================================================\n", UVM_LOW)
        
        // [1] CONTROL RW
        `uvm_info("CLEAN", "------------------------------------------------------------\n[1] CONTROL\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0000, 32'h1234_5678, 4'hF); do_read(32'h0000_0000);
        // [2] DATA_IN RW
        `uvm_info("CLEAN", "------------------------------------------------------------\n[2] DATA_IN\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0008, 32'hDEAD_BEEF, 4'hF); do_read(32'h0000_0008);
        // [3] DATA_OUT RW
        `uvm_info("CLEAN", "------------------------------------------------------------\n[3] DATA_OUT\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_000C, 32'hCAFE_F00D, 4'hF); do_read(32'h0000_000C);
        // [4] CONFIG RW
        `uvm_info("CLEAN", "------------------------------------------------------------\n[4] CONFIG\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0010, 32'hA5A5_5A5A, 4'hF); do_read(32'h0000_0010);
        // [5] SCRATCH RW
        `uvm_info("CLEAN", "------------------------------------------------------------\n[5] SCRATCH\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'h55AA_AA55, 4'hF); do_read(32'h0000_001C);
        // [6] STATUS RO Read
        `uvm_info("CLEAN", "------------------------------------------------------------\n[6] STATUS - READ ONLY\n------------------------------------------------------------", UVM_LOW)
        do_read(32'h0000_0004);
        // [7] COUNT RO Read
        `uvm_info("CLEAN", "------------------------------------------------------------\n[7] COUNT - READ ONLY\n------------------------------------------------------------", UVM_LOW)
        do_read(32'h0000_0014);
        // [8] VERSION RO Read
        `uvm_info("CLEAN", "------------------------------------------------------------\n[8] VERSION - READ ONLY\n------------------------------------------------------------", UVM_LOW)
        do_read(32'h0000_0018);
        // [9] RO Write Protection
        `uvm_info("CLEAN", "------------------------------------------------------------\n[9] RO WRITE PROTECTION\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0004, 32'hFFFF_FFFF, 4'hF);
        do_write(32'h0000_0014, 32'hFFFF_FFFF, 4'hF);
        do_write(32'h0000_0018, 32'hFFFF_FFFF, 4'hF);
        // [10] Invalid Address
        `uvm_info("CLEAN", "------------------------------------------------------------\n[10] INVALID ADDRESS\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0020, 32'hBADC_0FFE, 4'hF); do_read(32'h0000_0020);
        // [11] Misaligned Address
        `uvm_info("CLEAN", "------------------------------------------------------------\n[11] MISALIGNED ADDRESS\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_0002, 32'hBADC_0FFE, 4'hF); do_read(32'h0000_0002);

        `uvm_info("CLEAN", "\n============================================================\n              AXI4-LITE WSTRB TEST (PHASE 2)\n============================================================\n", UVM_LOW)
        `uvm_info("CLEAN", "------------------------------------------------------------\n[12] WSTRB INIT (0x11223344)\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'h1122_3344, 4'b1111); do_read(32'h0000_001C);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[13] WSTRB = 4'b0001\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hFFFF_FFAA, 4'b0001); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[14] WSTRB = 4'b0010\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hFFFF_BBFF, 4'b0010); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[15] WSTRB = 4'b0100\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hFFCC_FFFF, 4'b0100); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[16] WSTRB = 4'b1000\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hDDFF_FFFF, 4'b1000); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[17] WSTRB = 4'b0011\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hFFFF_9988, 4'b0011); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[18] WSTRB = 4'b1100\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'h7766_FFFF, 4'b1100); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[19] WSTRB = 4'b1010\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hEEFF_CCFF, 4'b1010); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[20] WSTRB = 4'b0101\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hFF55_FF44, 4'b0101); do_read(32'h0000_001C); do_write(32'h0000_001C, 32'h1122_3344, 4'b1111);
        `uvm_info("CLEAN", "------------------------------------------------------------\n[21] WSTRB = 4'b0000 (ZERO WSTRB)\n------------------------------------------------------------", UVM_LOW)
        do_write(32'h0000_001C, 32'hDEAD_BEEF, 4'b0000); do_read(32'h0000_001C);

        `uvm_info("CLEAN", "\n============================================================\n              AXI4-LITE PROTOCOL TEST (PHASE 3)\n============================================================\n", UVM_LOW)
        `uvm_info("CLEAN", "------------------------------------------------------------\n[22] AW-FIRST ORDERING (addr=0, data=5)\n------------------------------------------------------------", UVM_LOW)
        do_write(.addr(32'h0000_0000), .data(32'hA1A1_A1A1), .strb(4'hF), .d_aw(0), .d_w(5), .d_b(0));
        `uvm_info("CLEAN", "------------------------------------------------------------\n[23] W-FIRST ORDERING (addr=5, data=0)\n------------------------------------------------------------", UVM_LOW)
        do_write(.addr(32'h0000_0000), .data(32'hB2B2_B2B2), .strb(4'hF), .d_aw(5), .d_w(0), .d_b(0));
        `uvm_info("CLEAN", "------------------------------------------------------------\n[24] SAME-CYCLE ORDERING (addr=0, data=0)\n------------------------------------------------------------", UVM_LOW)
        do_write(.addr(32'h0000_0000), .data(32'hC3C3_C3C3), .strb(4'hF), .d_aw(0), .d_w(0), .d_b(0));
        `uvm_info("CLEAN", "------------------------------------------------------------\n[25] WRITE RESPONSE BACKPRESSURE (d_bready=8)\n------------------------------------------------------------", UVM_LOW)
        do_write(.addr(32'h0000_0008), .data(32'hD4D4_D4D4), .strb(4'hF), .d_aw(0), .d_w(0), .d_b(8));
        `uvm_info("CLEAN", "------------------------------------------------------------\n[26] READ RESPONSE BACKPRESSURE (d_rready=8)\n------------------------------------------------------------", UVM_LOW)
        do_read(.addr(32'h0000_0008), .d_ar(0), .d_r(8));
        
        // Final COUNT Verification (5 initial + 18 Phase 2 + 4 Phase 3 = 27 -> 0x0000_001B)
        `uvm_info("CLEAN", "------------------------------------------------------------\n[27] FINAL COUNT VERIFICATION\n------------------------------------------------------------", UVM_LOW)
        do_read(32'h0000_0014); 
    endtask
endclass


// PHASE 4B: CONSTRAINED-RANDOM REGRESSION

class axi4lite_rand_test_seq extends uvm_sequence #(axi4lite_seq_item);

    `uvm_object_utils(axi4lite_rand_test_seq)

    int num_transactions = 1000;

    function new(string name = "axi4lite_rand_test_seq");
        super.new(name);
    endfunction

    virtual task body();

        axi4lite_seq_item req;

        for (int i = 0; i < num_transactions; i++) begin
            req = axi4lite_seq_item::type_id::create("req");
            start_item(req);
            
            if (!req.randomize() with {
                addr dist {
                    // VALID (80% of total) -> 8 * 80 = 640
                    32'h0000_0000 := 80, 
                    32'h0000_0004 := 80, 
                    32'h0000_0008 := 80, 
                    32'h0000_000C := 80, 
                    32'h0000_0010 := 80, 
                    32'h0000_0014 := 80, 
                    32'h0000_0018 := 80, 
                    32'h0000_001C := 80, 

                    // MISALIGNED (10% of total) -> 8 * 10 = 80
                    [32'h0000_0001:32'h0000_0003] :/ 10,
                    [32'h0000_0005:32'h0000_0007] :/ 10,
                    [32'h0000_0009:32'h0000_000B] :/ 10,
                    [32'h0000_000D:32'h0000_000F] :/ 10,
                    [32'h0000_0011:32'h0000_0013] :/ 10,
                    [32'h0000_0015:32'h0000_0017] :/ 10,
                    [32'h0000_0019:32'h0000_001B] :/ 10,
                    [32'h0000_001D:32'h0000_001F] :/ 10,

                    // INVALID (10% of total) -> 1 * 80 = 80
                    [32'h0000_0020:32'hFFFF_FFFF] :/ 80
                };
            }) begin
                `uvm_fatal(get_type_name(), "Random transaction generation failed")
            end
            
            finish_item(req);
        end

    endtask

endclass