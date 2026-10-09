`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_agent extends uvm_agent;

    `uvm_component_utils(axi4lite_agent)

    // UVM agent components

    axi4lite_sequencer sequencer;
    axi4lite_driver    driver;
    axi4lite_monitor   monitor;

    function new(
        string name = "axi4lite_agent",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    // Build phase

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        monitor = axi4lite_monitor::type_id::create(
            "monitor",
            this
        );

        // Create active components only when agent is ACTIVE
        if (is_active == UVM_ACTIVE) begin

            sequencer = axi4lite_sequencer::type_id::create(
                "sequencer",
                this
            );

            driver = axi4lite_driver::type_id::create(
                "driver",
                this
            );

        end

    endfunction

    // Connect phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin

            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );

        end

    endfunction

endclass