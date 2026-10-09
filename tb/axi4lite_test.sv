`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class clean_report_server extends uvm_default_report_server;

    virtual function string compose_report_message(
        uvm_report_message report_message,
        string report_object_name = ""
    );
        if (report_message.get_id() == "CLEAN") begin
            return report_message.get_message();
        end else begin
            return super.compose_report_message(report_message, report_object_name);
        end
    endfunction

endclass

class axi4lite_test extends uvm_test;

    `uvm_component_utils(axi4lite_test)

    localparam int EXPECTED_TRANSACTIONS = 1000;

    axi4lite_env env;
    virtual axi4lite_if.master  vif_master;
    virtual axi4lite_if.monitor vif_monitor;

    function new(string name = "axi4lite_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        clean_report_server srv;
        super.build_phase(phase);

        srv = new();
        uvm_report_server::set_server(srv);

        env = axi4lite_env::type_id::create("env", this);

        if (!uvm_config_db#(virtual axi4lite_if.master)::get(this, "", "vif_master", vif_master))
            `uvm_fatal(get_type_name(), "Master virtual interface not found in config_db")
        uvm_config_db#(virtual axi4lite_if.master)::set(this, "env.agent.driver", "vif", vif_master);

        if (!uvm_config_db#(virtual axi4lite_if.monitor)::get(this, "", "vif_monitor", vif_monitor))
            `uvm_fatal(get_type_name(), "Monitor virtual interface not found in config_db")
        uvm_config_db#(virtual axi4lite_if.monitor)::set(this, "env.agent.monitor", "vif", vif_monitor);
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi4lite_rand_test_seq seq;

        phase.raise_objection(this);
        
        `uvm_info("CLEAN", $sformatf("============================================================\n              AXI4-LITE UVM VERIFICATION\n              PHASE 5 FUNCTIONAL COVERAGE\n============================================================\n\nTransactions : %0d\n\n------------------------------------------------------------\n                    REGRESSION RUNNING\n------------------------------------------------------------\n", EXPECTED_TRANSACTIONS), UVM_LOW)
        
        seq = axi4lite_rand_test_seq::type_id::create("seq");
        seq.num_transactions = EXPECTED_TRANSACTIONS;
        seq.start(env.agent.sequencer);
        
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server srv = uvm_report_server::get_server();
        int err_cnt   = srv.get_severity_count(UVM_ERROR);
        int fatal_cnt = srv.get_severity_count(UVM_FATAL);
        int warn_cnt  = srv.get_severity_count(UVM_WARNING);
        
        int total = env.scoreboard.total_transactions;
        int pass  = env.scoreboard.passed_transactions;
        int fail  = env.scoreboard.failed_transactions;
        
        // Retrieve Functional Coverage
        real coverage_pct = env.coverage.cg_axi4lite.get_coverage();

        bit test_passed = (total == EXPECTED_TRANSACTIONS) &&
                          (fail == 0) &&
                          (pass + fail == total) &&
                          (err_cnt == 0) &&
                          (fatal_cnt == 0);

        string res = test_passed ? "PASS" : "FAIL";

        `uvm_info("CLEAN", $sformatf("------------------------------------------------------------\n                  REGRESSION SUMMARY\n------------------------------------------------------------\n\nTotal Transactions : %0d\nPassed             : %0d\nFailed             : %0d\n\nUVM Errors         : %0d\nUVM Warnings       : %0d\nUVM Fatals         : %0d\n\nFunctional Coverage: %0.2f%%\n\n============================================================\nRESULT: %s\n============================================================\n", total, pass, fail, err_cnt, warn_cnt, fatal_cnt, coverage_pct, res), UVM_LOW)
    endfunction

endclass