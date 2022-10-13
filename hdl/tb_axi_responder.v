`timescale 1ns/1ps


module tb_axi_responder #(
  parameter ADDR_WIDTH          = 64,
  parameter DATA_WIDTH          = 64,
  parameter STROBE_WIDTH        = (DATA_WIDTH / 8)
)(

input                               clk,
input                               rst,

//Write Address Channel
input                               AXIML_AWVALID,
input       [ADDR_WIDTH - 1: 0]     AXIML_AWADDR,
output                              AXIML_AWREADY,
input       [1:0]                   AXIML_AWBURST,
input       [7:0]                   AXIML_AWLEN,
input       [2:0]                   AXIML_AWSIZE,

//Write Data Channel
input                               AXIML_WVALID,
output                              AXIML_WREADY,
input       [STROBE_WIDTH - 1:0]    AXIML_WSTRB,
input       [DATA_WIDTH - 1: 0]     AXIML_WDATA,


//Write Response Channel
output                              AXIML_BVALID,
input                               AXIML_BREADY,
output      [1:0]                   AXIML_BRESP,

//Read Address Channel
input                               AXIML_ARVALID,
output                              AXIML_ARREADY,
input       [ADDR_WIDTH - 1: 0]     AXIML_ARADDR,
input       [1:0]                  AXIML_ARBURST,
input      [7:0]                   AXIML_ARLEN,
input       [2:0]                  AXIML_ARSIZE,

//Read Data Channel
output                              AXIML_RVALID,
input                               AXIML_RREADY,
output      [1:0]                   AXIML_RRESP,
output      [DATA_WIDTH - 1: 0]     AXIML_RDATA,
output                              AXIML_RLAST


);


//Local Parameters
//Registers

reg               r_rst;
reg [7:0] 	  test_id         = 0;

//Workaround for weird icarus simulator bug
always @ (*)      r_rst           = rst;

wire bridge_mem_val;
wire [63:0] bridge_mem_dat;
wire bridge_mem_rdy;

wire mem_bridge_val;
wire [63:0] mem_bridge_dat;
wire mem_bridge_rdy;

//submodules
axilite_noc_bridge #(
) dut (
  .clk          (clk            ),
  .rst          (r_rst          ),


  .m_axi_awvalid    (AXIML_AWVALID  ),
  .m_axi_awaddr     (AXIML_AWADDR   ),
  .m_axi_awready    (AXIML_AWREADY  ),


  .m_axi_wvalid     (AXIML_WVALID   ),
  .m_axi_wready     (AXIML_WREADY   ),
  .m_axi_wstrb      (AXIML_WSTRB    ),
  .m_axi_wdata      (AXIML_WDATA    ),


  .m_axi_bvalid     (AXIML_BVALID   ),
  .m_axi_bready     (AXIML_BREADY   ),
  .m_axi_bresp      (AXIML_BRESP    ),


  .m_axi_arvalid    (AXIML_ARVALID  ),
  .m_axi_arready    (AXIML_ARREADY  ),
  .m_axi_araddr     (AXIML_ARADDR   ),


  .m_axi_rvalid     (AXIML_RVALID   ),
  .m_axi_rready     (AXIML_RREADY   ),
  .m_axi_rresp      (AXIML_RRESP    ),
  .m_axi_rdata      (AXIML_RDATA    ),

  .src_chipid       (14'b0),
  .src_xpos         (8'b0),
  .src_ypos         (8'b0),
  .src_fbits        (4'b0),

  .dest_chipid      (14'b0),
  .dest_xpos        (8'b0),
  .dest_ypos        (8'b0),
  .dest_fbits       (4'b0),

  .noc2_valid_in    (1'b0),
  .noc2_data_in     (64'b0),
  .noc2_ready_out   (),

  .noc2_valid_out   (bridge_mem_val),
  .noc2_data_out    (bridge_mem_dat),
  .noc2_ready_in    (bridge_mem_rdy),

  .noc3_valid_in    (mem_bridge_val),
  .noc3_data_in     (mem_bridge_dat),
  .noc3_ready_out   (mem_bridge_rdy),

  .noc3_valid_out   (),
  .noc3_data_out    (),
  .noc3_ready_in    (1'b0)
);

fake_mem_ctrl fake_mem_ctrl (
  .clk              (clk),
  .rst_n            (~r_rst),

  .noc_valid_in     (bridge_mem_val),
  .noc_data_in      (bridge_mem_dat),
  .noc_ready_in     (bridge_mem_rdy),

  .noc_valid_out    (mem_bridge_val),
  .noc_data_out     (mem_bridge_dat),
  .noc_ready_out    (mem_bridge_rdy)
);
assign AXIML_RLAST = AXIML_RVALID & AXIML_RREADY;

//asynchronus logic
//synchronous logic

`ifndef VERILATOR // traced differently
  initial begin
    $dumpfile ("design.vcd");
    $dumpvars(0, tb_axi_responder);
  end
`endif

endmodule