`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_driver extends uvm_driver #(axi4lite_seq_item);

    `uvm_component_utils(axi4lite_driver)

    virtual axi4lite_if.master vif;
    localparam int TIMEOUT_CYCLES = 1000;

    function new(string name = "axi4lite_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4lite_if.master)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi4lite_seq_item req;

        vif.awvalid <= 1'b0;
        vif.wvalid  <= 1'b0;
        vif.bready  <= 1'b0;
        vif.arvalid <= 1'b0;
        vif.rready  <= 1'b0;

        wait(vif.aresetn === 1'b1);
        @(posedge vif.aclk);

        forever begin
            seq_item_port.get_next_item(req);

            if (req.operation == axi4lite_seq_item::WRITE) begin
                `uvm_info("DRIVER", $sformatf("Driving WRITE: ADDR=0x%08h", req.addr), UVM_HIGH)
                drive_write(req);
            end else begin
                `uvm_info("DRIVER", $sformatf("Driving READ: ADDR=0x%08h", req.addr), UVM_HIGH)
                drive_read(req);
            end

            seq_item_port.item_done();
        end
    endtask

    virtual task drive_write(axi4lite_seq_item req);
        int timeout_b = 0;

        fork
            // AW Channel
            begin
                int timeout_aw = 0;
                repeat(req.delay_aw) @(posedge vif.aclk);
                vif.awaddr  <= req.addr;
                vif.awvalid <= 1'b1;
                do begin
                    @(posedge vif.aclk);
                    timeout_aw++;
                    if (timeout_aw >= TIMEOUT_CYCLES) begin
                        `uvm_fatal("TIMEOUT", $sformatf("Driver timeout waiting for AWREADY (ADDR=0x%08h)", req.addr))
                    end
                end while (!(vif.awvalid && vif.awready));
                vif.awvalid <= 1'b0;
            end

            // W Channel
            begin
                int timeout_w = 0;
                repeat(req.delay_w) @(posedge vif.aclk);
                vif.wdata   <= req.data;
                vif.wstrb   <= req.strb;
                vif.wvalid  <= 1'b1;
                do begin
                    @(posedge vif.aclk);
                    timeout_w++;
                    if (timeout_w >= TIMEOUT_CYCLES) begin
                        `uvm_fatal("TIMEOUT", $sformatf("Driver timeout waiting for WREADY (ADDR=0x%08h)", req.addr))
                    end
                end while (!(vif.wvalid && vif.wready));
                vif.wvalid <= 1'b0;
            end
        join

        // B Channel
        repeat(req.delay_bready) @(posedge vif.aclk);
        vif.bready <= 1'b1;
        do begin
            @(posedge vif.aclk);
            timeout_b++;
            if (timeout_b >= TIMEOUT_CYCLES) begin
                `uvm_fatal("TIMEOUT", $sformatf("Driver timeout waiting for BVALID (ADDR=0x%08h)", req.addr))
            end
        end while (!(vif.bvalid && vif.bready));

        req.resp   = vif.bresp;
        vif.bready <= 1'b0;
    endtask

    virtual task drive_read(axi4lite_seq_item req);
        int timeout_ar = 0;
        int timeout_r  = 0;

        // AR Channel
        repeat(req.delay_ar) @(posedge vif.aclk);
        vif.araddr  <= req.addr;
        vif.arvalid <= 1'b1;
        do begin
            @(posedge vif.aclk);
            timeout_ar++;
            if (timeout_ar >= TIMEOUT_CYCLES) begin
                `uvm_fatal("TIMEOUT", $sformatf("Driver timeout waiting for ARREADY (ADDR=0x%08h)", req.addr))
            end
        end while (!(vif.arvalid && vif.arready));
        vif.arvalid <= 1'b0;

        // R Channel
        repeat(req.delay_rready) @(posedge vif.aclk);
        vif.rready <= 1'b1;
        do begin
            @(posedge vif.aclk);
            timeout_r++;
            if (timeout_r >= TIMEOUT_CYCLES) begin
                `uvm_fatal("TIMEOUT", $sformatf("Driver timeout waiting for RVALID (ADDR=0x%08h)", req.addr))
            end
        end while (!(vif.rvalid && vif.rready));

        req.read_data = vif.rdata;
        req.resp      = vif.rresp;
        vif.rready    <= 1'b0;
    endtask

endclass