`timescale 1ns / 1ps

interface axi4lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic aclk,
    input logic aresetn
);

    //=========================================================
    // Initialization to prevent time-0 X-state assertion failures
    //=========================================================
    initial begin
        awvalid = 1'b0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        arvalid = 1'b0;
        rready  = 1'b0;
    end

    //=========================================================
    // AXI4-Lite Write Address Channel
    //=========================================================
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;

    //=========================================================
    // AXI4-Lite Write Data Channel
    //=========================================================
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    //=========================================================
    // AXI4-Lite Write Response Channel
    //=========================================================
    logic [1:0] bresp;
    logic       bvalid;
    logic       bready;

    //=========================================================
    // AXI4-Lite Read Address Channel
    //=========================================================
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;

    //=========================================================
    // AXI4-Lite Read Data Channel
    //=========================================================
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;


    //=========================================================
    // DUT / Slave Modport
    //=========================================================
    modport slave (
        input  aclk,
        input  aresetn,

        input  awaddr,
        input  awvalid,
        output awready,

        input  wdata,
        input  wstrb,
        input  wvalid,
        output wready,

        output bresp,
        output bvalid,
        input  bready,

        input  araddr,
        input  arvalid,
        output arready,

        output rdata,
        output rresp,
        output rvalid,
        input  rready
    );


    //=========================================================
    // UVM Driver / Master Modport
    //=========================================================
    modport master (
        input  aclk,
        input  aresetn,

        output awaddr,
        output awvalid,
        input  awready,

        output wdata,
        output wstrb,
        output wvalid,
        input  wready,

        input  bresp,
        input  bvalid,
        output bready,

        output araddr,
        output arvalid,
        input  arready,

        input  rdata,
        input  rresp,
        input  rvalid,
        output rready
    );


    //=========================================================
    // UVM Monitor Modport
    //=========================================================
    modport monitor (
        input aclk,
        input aresetn,

        input awaddr,
        input awvalid,
        input awready,

        input wdata,
        input wstrb,
        input wvalid,
        input wready,

        input bresp,
        input bvalid,
        input bready,

        input araddr,
        input arvalid,
        input arready,

        input rdata,
        input rresp,
        input rvalid,
        input rready
    );

endinterface