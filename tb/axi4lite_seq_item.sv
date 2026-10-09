`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_seq_item extends uvm_sequence_item;

    typedef enum bit {READ, WRITE} op_t;

    // Stimulus Fields
    rand op_t         operation;
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand logic [3:0]  strb;
    
    // Response Fields
    logic [31:0]      read_data;
    logic [1:0]       resp;

    // Stimulus Delay Variables (For sequencer/driver)
    rand int delay_aw;
    rand int delay_w;
    rand int delay_bready;
    rand int delay_ar;
    rand int delay_rready;

    // Observation Variables (For monitor/coverage)
    int aw_cycle;
    int w_cycle;
    int bready_backpressure_cycles;
    int rready_backpressure_cycles;

    constraint delay_c {
        delay_aw     inside {[0:10]};
        delay_w      inside {[0:10]};
        delay_bready inside {[0:10]};
        delay_ar     inside {[0:10]};
        delay_rready inside {[0:10]};
    }

    `uvm_object_utils_begin(axi4lite_seq_item)
        `uvm_field_enum(op_t, operation, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(strb, UVM_ALL_ON)
        `uvm_field_int(read_data, UVM_ALL_ON)
        `uvm_field_int(resp, UVM_ALL_ON)
        `uvm_field_int(delay_aw, UVM_ALL_ON)
        `uvm_field_int(delay_w, UVM_ALL_ON)
        `uvm_field_int(delay_bready, UVM_ALL_ON)
        `uvm_field_int(delay_ar, UVM_ALL_ON)
        `uvm_field_int(delay_rready, UVM_ALL_ON)
        `uvm_field_int(aw_cycle, UVM_ALL_ON)
        `uvm_field_int(w_cycle, UVM_ALL_ON)
        `uvm_field_int(bready_backpressure_cycles, UVM_ALL_ON)
        `uvm_field_int(rready_backpressure_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi4lite_seq_item");
        super.new(name);
    endfunction

endclass