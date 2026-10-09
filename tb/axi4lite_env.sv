`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_env extends uvm_env;

    `uvm_component_utils(axi4lite_env)

    axi4lite_agent      agent;
    axi4lite_scoreboard scoreboard;
    axi4lite_coverage   coverage; // [NEW] Added coverage collector

    function new(string name = "axi4lite_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = axi4lite_agent::type_id::create("agent", this);
        scoreboard = axi4lite_scoreboard::type_id::create("scoreboard", this);
        coverage   = axi4lite_coverage::type_id::create("coverage", this); // [NEW] Build coverage
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Multicast monitor transactions to both the scoreboard and the coverage collector
        agent.monitor.analysis_port.connect(scoreboard.analysis_export);
        agent.monitor.analysis_port.connect(coverage.analysis_export); // [NEW] Connect coverage
    endfunction

endclass