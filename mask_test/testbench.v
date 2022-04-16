`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/04/07 17:01:50
// Design Name: 
// Module Name: testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module testbench();


reg clk;
reg rst;
reg [7:0] m_axi_wstrb;
reg [7:0] input_array [3:0];
wire [7:0] pmesh_mask;
wire o_ready;
reg [1:0] counter;
reg valid;
wire o_valid;
reg [7:0] data_fetch; 
reg ready;
integer i;

localparam BASE_1B = 8'b1000_0000;
localparam BASE_2B = 8'b1100_0000;
localparam BASE_4B = 8'b1111_0000;
localparam BASE_8B = 8'b1111_1111;


strb2mask ins1
(
    .rst (rst),
    .clk (clk),
    .m_axi_wstrb (m_axi_wstrb),
    .pmesh_mask (pmesh_mask),
    .o_ready (o_ready),
    .i_valid (valid),
    .o_valid (o_valid),
    .i_ready (ready)
);

initial begin
    clk = 0;
    forever begin
       #5 clk = ~clk;
    end
end 

initial begin
    $display("dump start");
    $dumpfile("test.vcd");
    $dumpvars;
    #300 $finish;
    $display("dump finish");
end


always@ (posedge clk) begin
    if (rst) begin 
        m_axi_wstrb <= BASE_8B;
        counter <= 0;
        valid <= 1;
    end
    else if (o_ready & valid) begin
        valid <= valid;
        m_axi_wstrb <= input_array[counter];
        counter <= counter + 1;
    end
    else begin
        counter <= counter;
        m_axi_wstrb <= m_axi_wstrb;
        valid <= valid;
    end
end

always@ (posedge clk) begin
    if (rst) ready <= 1;
    else ready <= ~ready;
    
end

always@(posedge clk) begin
    if (rst) begin
        data_fetch<= 8'b0;
    end
    else if (o_valid) begin
        data_fetch <= pmesh_mask;
    end
end


initial begin
$display("simulation start");
input_array[0] <= BASE_4B;
input_array[1] <= 8'b0111_1110;
input_array[2] <= 8'b0110_0000;
input_array[3] <= BASE_8B;
$display("input array initialize complete");
rst <= 0;
@(negedge clk) rst <= 1;
@(negedge clk) rst <= 1;
@(negedge clk) rst <= 0;
end


endmodule
