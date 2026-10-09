`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Include your UVM components here if not compiled via a package
`include "axi4lite_seq_item.sv"
`include "axi4lite_sequence.sv"
`include "axi4lite_sequencer.sv"
`include "axi4lite_driver.sv"
`include "axi4lite_monitor.sv"
`include "axi4lite_scoreboard.sv"
`include "axi4lite_agent.sv"
`include "axi4lite_coverage.sv"
`include "axi4lite_env.sv"
`include "axi4lite_test.sv"
`include "axi4lite_assertions.sv"

module tb_top;

    // Clock and Reset Signals
    logic clk;
    logic resetn;

    // 100 MHz Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset Generation
    initial begin
        resetn = 0;
        repeat (3) @(posedge clk);
        resetn = 1;
    end

    // Interface Instantiation
    axi4lite_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) vif (
        .aclk(clk),
        .aresetn(resetn)
    );

    // DUT Instantiation
    axi4lite_slave_top #(
        .ADDR_WIDTH(32),
        .VERSION_VALUE(32'h0001_0000)
    ) dut (
        .ACLK(vif.aclk),
        .ARESETn(vif.aresetn),
        
        // Write Address Channel
        .AWADDR(vif.awaddr),
        .AWVALID(vif.awvalid),
        .AWREADY(vif.awready),
        
        // Write Data Channel
        .WDATA(vif.wdata),
        .WSTRB(vif.wstrb),
        .WVALID(vif.wvalid),
        .WREADY(vif.wready),
        
        // Write Response Channel
        .BRESP(vif.bresp),
        .BVALID(vif.bvalid),
        .BREADY(vif.bready),
        
        // Read Address Channel
        .ARADDR(vif.araddr),
        .ARVALID(vif.arvalid),
        .ARREADY(vif.arready),
        
        // Read Data Channel
        .RDATA(vif.rdata),
        .RRESP(vif.rresp),
        .RVALID(vif.rvalid),
        .RREADY(vif.rready)
    );

    // UVM Start Setup
    initial begin
        // Pass the modports into the config_db so the test can retrieve them
        uvm_config_db#(virtual axi4lite_if.master)::set(null, "uvm_test_top", "vif_master", vif.master);
        uvm_config_db#(virtual axi4lite_if.monitor)::set(null, "uvm_test_top", "vif_monitor", vif.monitor);
        
        // Start the UVM test
        run_test("axi4lite_test");
    end

    // Optional: Waveform dumping
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

// Bind SVA directly to interface instance (vif)
    axi4lite_assertions u_axi4lite_assertions (
        .aclk       (vif.aclk),
        .aresetn    (vif.aresetn),
        .awaddr     (vif.awaddr),
        .awvalid    (vif.awvalid),
        .awready    (vif.awready),
        .wdata      (vif.wdata),
        .wstrb      (vif.wstrb),
        .wvalid     (vif.wvalid),
        .wready     (vif.wready),
        .bresp      (vif.bresp),
        .bvalid     (vif.bvalid),
        .bready     (vif.bready),
        .araddr     (vif.araddr),
        .arvalid    (vif.arvalid),
        .arready    (vif.arready),
        .rdata      (vif.rdata),
        .rresp      (vif.rresp),
        .rvalid     (vif.rvalid),
        .rready     (vif.rready)
    );

endmodule                                                                                                                                                 