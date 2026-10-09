`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_monitor extends uvm_monitor;

    `uvm_component_utils(axi4lite_monitor)

    virtual axi4lite_if.monitor vif;
    uvm_analysis_port #(axi4lite_seq_item) analysis_port;

    localparam int TIMEOUT_CYCLES = 1000;

    function new(string name = "axi4lite_monitor", uvm_component parent = null);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4lite_if.monitor)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            forever monitor_write();
            forever monitor_read();
        join
    endtask

    virtual task monitor_write();
        axi4lite_seq_item item;
        logic [31:0] captured_addr;
        logic [31:0] captured_data;
        logic [3:0]  captured_strb;
        logic [1:0]  captured_resp;
        bit aw_done, w_done;
        
        int active_timeout;
        int b_timeout;
        int cycle_count; // Track relative cycles
        int cycle_aw;    // Cycle AW completed
        int cycle_w;     // Cycle W completed

        aw_done        = 1'b0;
        w_done         = 1'b0;
        active_timeout = 0;
        b_timeout      = 0;
        cycle_count    = 0;

        do begin
            @(posedge vif.aclk);
            cycle_count++;

            if (vif.awvalid && vif.awready && !aw_done) begin
                captured_addr = vif.awaddr;
                cycle_aw      = cycle_count; // Record when AW finished
                aw_done       = 1'b1;
            end
            if (vif.wvalid && vif.wready && !w_done) begin
                captured_data = vif.wdata;
                captured_strb = vif.wstrb;
                cycle_w       = cycle_count; // Record when W finished
                w_done        = 1'b1;
            end

            if (aw_done ^ w_done) begin
                active_timeout++;
                if (active_timeout >= TIMEOUT_CYCLES) begin
                    `uvm_fatal("MON_TIMEOUT", $sformatf("Monitor timeout: WRITE split handshake stalled (AW_DONE=%0b, W_DONE=%0b)", aw_done, w_done))
                end
            end
        end while (!(aw_done && w_done));

        do begin
            @(posedge vif.aclk);
            // Track if BREADY was intentionally delayed while BVALID was asserted
            if (vif.bvalid && !vif.bready) b_timeout++; 
            
            active_timeout++;
            if (active_timeout >= TIMEOUT_CYCLES) begin
                `uvm_fatal("MON_TIMEOUT", $sformatf("Monitor timeout: BVALID stalled after write transfer (ADDR=0x%08h)", captured_addr))
            end
        end while (!(vif.bvalid && vif.bready));
        captured_resp = vif.bresp;

        item = axi4lite_seq_item::type_id::create("write_item");
        item.operation                  = axi4lite_seq_item::WRITE;
        item.addr                       = captured_addr;
        item.data                       = captured_data;
        item.strb                       = captured_strb;
        item.resp                       = captured_resp;
        item.aw_cycle                   = cycle_aw;  
        item.w_cycle                    = cycle_w;   
        item.bready_backpressure_cycles = b_timeout; 

        `uvm_info("MONITOR", $sformatf("Observed WRITE: ADDR=0x%08h DATA=0x%08h", item.addr, item.data), UVM_HIGH)
        analysis_port.write(item);
    endtask

    virtual task monitor_read();
        axi4lite_seq_item item;
        logic [31:0] captured_addr;
        logic [31:0] captured_data;
        logic [1:0]  captured_resp;
        int r_timeout;
        int rready_delay; // Track backpressure

        r_timeout    = 0;
        rready_delay = 0;

        do begin
            @(posedge vif.aclk);
        end while (!(vif.arvalid && vif.arready));
        captured_addr = vif.araddr;

        do begin
            @(posedge vif.aclk);
            // Track if RREADY was intentionally delayed while RVALID was asserted
            if (vif.rvalid && !vif.rready) rready_delay++;

            r_timeout++;
            if (r_timeout >= TIMEOUT_CYCLES) begin
                `uvm_fatal("MON_TIMEOUT", $sformatf("Monitor timeout: RVALID stalled after address handshake (ADDR=0x%08h)", captured_addr))
            end
        end while (!(vif.rvalid && vif.rready));

        captured_data = vif.rdata;
        captured_resp = vif.rresp;

        item = axi4lite_seq_item::type_id::create("read_item");
        item.operation                  = axi4lite_seq_item::READ;
        item.addr                       = captured_addr;
        item.read_data                  = captured_data;
        item.resp                       = captured_resp;
        item.rready_backpressure_cycles = rready_delay; 

        `uvm_info("MONITOR", $sformatf("Observed READ: ADDR=0x%08h", item.addr), UVM_HIGH)
        analysis_port.write(item);
    endtask

endclass