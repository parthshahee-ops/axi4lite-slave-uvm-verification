`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4lite_coverage extends uvm_subscriber #(axi4lite_seq_item);

    `uvm_component_utils(axi4lite_coverage)

    axi4lite_seq_item item;

    typedef enum {VALID_ALIGNED, MISALIGNED, INVALID_ADDR} addr_type_e;
    typedef enum {RW_REG, RO_REG, UNMAPPED} reg_type_e;
    typedef enum {AW_FIRST, W_FIRST, SAME_CYCLE, NOT_WRITE} write_order_e;

    addr_type_e   addr_type;
    reg_type_e    reg_type;
    write_order_e write_order;

    covergroup cg_axi4lite;
        option.per_instance = 1;
        option.name = "axi4lite_functional_coverage";

        // 1. Operation Type
        cp_op: coverpoint item.operation {
            bins read  = {axi4lite_seq_item::READ};
            bins write = {axi4lite_seq_item::WRITE};
        }

        // 2. Address Classification
        cp_addr_type: coverpoint addr_type {
            bins valid      = {VALID_ALIGNED};
            bins misaligned = {MISALIGNED};
            bins invalid    = {INVALID_ADDR};
        }

        // 3. Register Type
        cp_reg_type: coverpoint reg_type {
            bins rw_reg = {RW_REG};
            bins ro_reg = {RO_REG};
            ignore_bins unmapped = {UNMAPPED};
        }

        // 4. Write Strobes
        cp_wstrb_exact: coverpoint item.strb iff (item.operation == axi4lite_seq_item::WRITE) {
            bins all_patterns[] = {[0:15]};
        }
        
        cp_wstrb_categories: coverpoint item.strb iff (item.operation == axi4lite_seq_item::WRITE) {
            bins all_zeros   = {4'b0000};
            bins all_ones    = {4'b1111};
            bins single_byte = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins multi_byte  = {4'b0011, 4'b0110, 4'b1100, 4'b1001, 4'b1010, 4'b0101, 4'b0111, 4'b1011, 4'b1101, 4'b1110};
        }

        // 5. Channel Ordering
        cp_write_order: coverpoint write_order iff (item.operation == axi4lite_seq_item::WRITE) {
            bins aw_first   = {AW_FIRST};
            bins w_first    = {W_FIRST};
            bins same_cycle = {SAME_CYCLE};
        }

        // 6. Backpressure
        cp_bready_bp: coverpoint item.bready_backpressure_cycles iff (item.operation == axi4lite_seq_item::WRITE) {
            bins no_delay = {0};
            bins delayed  = {[1:1000]}; 
        }

        cp_rready_bp: coverpoint item.rready_backpressure_cycles iff (item.operation == axi4lite_seq_item::READ) {
            bins no_delay = {0};
            bins delayed  = {[1:1000]};
        }

        // 7. Protocol Response
        cp_resp: coverpoint item.resp {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        // 8. Targeted Error Condition Scenarios (Replaces Crosses)
        cp_write_ro_err: coverpoint (item.operation == axi4lite_seq_item::WRITE && reg_type == RO_REG && item.resp == 2'b10) {
            bins hit = {1};
            ignore_bins not_hit = {0};
        }

        cp_write_inv_err: coverpoint (item.operation == axi4lite_seq_item::WRITE && addr_type == INVALID_ADDR && item.resp == 2'b10) {
            bins hit = {1};
            ignore_bins not_hit = {0};
        }

        cp_read_inv_err: coverpoint (item.operation == axi4lite_seq_item::READ && addr_type == INVALID_ADDR && item.resp == 2'b10) {
            bins hit = {1};
            ignore_bins not_hit = {0};
        }

    endgroup

    function new(string name = "axi4lite_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_axi4lite = new();
    endfunction

    virtual function void write(axi4lite_seq_item t);
        item = t;

        if (item.addr >= 32'h0000_0020) begin
            addr_type = INVALID_ADDR;
        end else if (item.addr[1:0] != 2'b00) begin
            addr_type = MISALIGNED;
        end else begin
            addr_type = VALID_ALIGNED;
        end

        if (addr_type == VALID_ALIGNED) begin
            if (item.addr == 32'h0000_0004 || item.addr == 32'h0000_0014 || item.addr == 32'h0000_0018)
                reg_type = RO_REG;
            else
                reg_type = RW_REG;
        end else begin
            reg_type = UNMAPPED;
        end

        if (item.operation == axi4lite_seq_item::WRITE) begin
            if (item.aw_cycle < item.w_cycle)      write_order = AW_FIRST;
            else if (item.aw_cycle > item.w_cycle) write_order = W_FIRST;
            else                                   write_order = SAME_CYCLE;
        end else begin
            write_order = NOT_WRITE;
        end

        cg_axi4lite.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("CLEAN", $sformatf(
            "\n------------------------------------------------------------\n                  COVERAGE BREAKDOWN\n------------------------------------------------------------\n  cp_op               : %6.2f%%\n  cp_addr_type        : %6.2f%%\n  cp_reg_type         : %6.2f%%\n  cp_wstrb_exact      : %6.2f%%\n  cp_wstrb_categories : %6.2f%%\n  cp_write_order      : %6.2f%%\n  cp_bready_bp        : %6.2f%%\n  cp_rready_bp        : %6.2f%%\n  cp_resp             : %6.2f%%\n  cp_write_ro_err     : %6.2f%%\n  cp_write_inv_err    : %6.2f%%\n  cp_read_inv_err     : %6.2f%%\n------------------------------------------------------------",
            cg_axi4lite.cp_op.get_coverage(),
            cg_axi4lite.cp_addr_type.get_coverage(),
            cg_axi4lite.cp_reg_type.get_coverage(),
            cg_axi4lite.cp_wstrb_exact.get_coverage(),
            cg_axi4lite.cp_wstrb_categories.get_coverage(),
            cg_axi4lite.cp_write_order.get_coverage(),
            cg_axi4lite.cp_bready_bp.get_coverage(),
            cg_axi4lite.cp_rready_bp.get_coverage(),
            cg_axi4lite.cp_resp.get_coverage(),
            cg_axi4lite.cp_write_ro_err.get_coverage(),
            cg_axi4lite.cp_write_inv_err.get_coverage(),
            cg_axi4lite.cp_read_inv_err.get_coverage()
        ), UVM_LOW)
    endfunction

endclass