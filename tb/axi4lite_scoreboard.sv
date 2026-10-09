`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi4lite_scoreboard)

    uvm_analysis_imp #(axi4lite_seq_item, axi4lite_scoreboard) analysis_export;

    // Regression Counters
    int total_transactions;
    int passed_transactions;
    int failed_transactions;

    logic [31:0] reg_control;
    logic [31:0] reg_data_in;
    logic [31:0] reg_data_out;
    logic [31:0] reg_config;
    logic [31:0] reg_scratch;
    logic [31:0] reg_count;

    function new(string name = "axi4lite_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        total_transactions  = 0;
        passed_transactions = 0;
        failed_transactions = 0;

        reg_control  = 32'h0000_0000;
        reg_data_in  = 32'h0000_0000;
        reg_data_out = 32'h0000_0000;
        reg_config   = 32'h0000_0000;
        reg_scratch  = 32'h0000_0000;
        reg_count    = 32'h0000_0000;
    endfunction

    virtual function void write(axi4lite_seq_item item);
        if (item.operation == axi4lite_seq_item::WRITE)
            check_write(item);
        else
            check_read(item);
    endfunction

    virtual function void check_write(axi4lite_seq_item item);
        bit error_flag = 0;
        logic [1:0] expected_resp;
        bit is_valid_write;
        total_transactions++;

        // Explicit unknown checks on input write transaction attributes
        if ($isunknown(item.addr)) begin
            error_flag = 1;
            `uvm_error("UNKNOWN_VAL", $sformatf("Transaction #%0d WRITE address contains X/Z: 0x%08h", total_transactions, item.addr))
        end
        if ($isunknown(item.data)) begin
            error_flag = 1;
            `uvm_error("UNKNOWN_VAL", $sformatf("Transaction #%0d WRITE data contains X/Z: 0x%08h", total_transactions, item.data))
        end
        if ($isunknown(item.strb)) begin
            error_flag = 1;
            `uvm_error("UNKNOWN_VAL", $sformatf("Transaction #%0d WRITE strobe contains X/Z: %04b", total_transactions, item.strb))
        end

        // Determine expected response and legality strictly from operation and address
        if ((item.addr == 32'h0000_0000) || (item.addr == 32'h0000_0008) || 
            (item.addr == 32'h0000_000C) || (item.addr == 32'h0000_0010) || 
            (item.addr == 32'h0000_001C)) begin
            expected_resp  = 2'b00; // OKAY
            is_valid_write = 1'b1;
        end else begin
            expected_resp  = 2'b10; // SLVERR
            is_valid_write = 1'b0;
        end

        // Update reference model and COUNT independent of DUT's observed response
        if (is_valid_write) begin
            if (item.addr == 32'h0000_0000) reg_control  = apply_wstrb(reg_control, item.data, item.strb);
            if (item.addr == 32'h0000_0008) reg_data_in  = apply_wstrb(reg_data_in, item.data, item.strb);
            if (item.addr == 32'h0000_000C) reg_data_out = apply_wstrb(reg_data_out, item.data, item.strb);
            if (item.addr == 32'h0000_0010) reg_config   = apply_wstrb(reg_config, item.data, item.strb);
            if (item.addr == 32'h0000_001C) reg_scratch  = apply_wstrb(reg_scratch, item.data, item.strb);
            reg_count++;
        end

        // Catch X/Z unknown values on response bits
        if (item.resp !== expected_resp) begin
            error_flag = 1;
            `uvm_error("MISMATCH", $sformatf("\n[ERROR] Transaction #%0d\n  Operation : WRITE\n  Address   : 0x%08h\n  Expected  : RESP=%02b (%s)\n  Actual    : RESP=%02b", 
                       total_transactions, item.addr, expected_resp, (expected_resp == 2'b00) ? "OKAY" : "SLVERR", item.resp))
        end

        if (error_flag) failed_transactions++;
        else            passed_transactions++;
    endfunction

    virtual function void check_read(axi4lite_seq_item item);
        bit error_flag = 0;
        logic [1:0]  expected_resp;
        logic [31:0] expected_data = 32'h0000_0000;

        total_transactions++;

        // Explicit unknown checks on read address
        if ($isunknown(item.addr)) begin
            error_flag = 1;
            `uvm_error("UNKNOWN_VAL", $sformatf("Transaction #%0d READ address contains X/Z: 0x%08h", total_transactions, item.addr))
        end

        // Determine expected response and expected read data
        if (item.addr <= 32'h0000_001C && item.addr[1:0] == 2'b00) begin
            expected_resp = 2'b00; // OKAY
            if      (item.addr == 32'h0000_0000) expected_data = reg_control;
            else if (item.addr == 32'h0000_0004) expected_data = 32'h0000_0001; // STATUS
            else if (item.addr == 32'h0000_0008) expected_data = reg_data_in;
            else if (item.addr == 32'h0000_000C) expected_data = reg_data_out;
            else if (item.addr == 32'h0000_0010) expected_data = reg_config;
            else if (item.addr == 32'h0000_0014) expected_data = reg_count;     // COUNT
            else if (item.addr == 32'h0000_0018) expected_data = 32'h0001_0000; // VERSION
            else if (item.addr == 32'h0000_001C) expected_data = reg_scratch;
        end else begin
            expected_resp = 2'b10; // SLVERR
            expected_data = 32'h0000_0000;
        end

        // Catch X/Z unknowns on response using !==
        if (item.resp !== expected_resp) begin
            error_flag = 1;
            `uvm_error("MISMATCH", $sformatf("\n[ERROR] Transaction #%0d\n  Operation : READ\n  Address   : 0x%08h\n  Expected  : RESP=%02b (%s)\n  Actual    : RESP=%02b", 
                       total_transactions, item.addr, expected_resp, (expected_resp == 2'b00) ? "OKAY" : "SLVERR", item.resp))
        end

        // Check read data on EVERY transaction (including SLVERR), detecting X/Z via !==
        if (item.read_data !== expected_data) begin
            error_flag = 1;
            `uvm_error("MISMATCH", $sformatf("\n[ERROR] Transaction #%0d\n  Operation : READ\n  Address   : 0x%08h\n  Expected  : DATA=0x%08h\n  Actual    : DATA=0x%08h", 
                       total_transactions, item.addr, expected_data, item.read_data))
        end

        if (error_flag) failed_transactions++;
        else            passed_transactions++;
    endfunction

    virtual function logic [31:0] apply_wstrb(logic [31:0] old_value, logic [31:0] new_value, logic [3:0] strb);
        logic [31:0] result = old_value;
        if (strb[0]) result[7:0]   = new_value[7:0];
        if (strb[1]) result[15:8]  = new_value[15:8];
        if (strb[2]) result[23:16] = new_value[23:16];
        if (strb[3]) result[31:24] = new_value[31:24];
        return result;
    endfunction

endclass