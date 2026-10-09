`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_sequencer extends uvm_sequencer #(axi4lite_seq_item);

    `uvm_component_utils(axi4lite_sequencer)

    function new(
        string name = "axi4lite_sequencer",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

endclass