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
wire [7:0] data_size;
wire [2:0] addr;

reg [7:0] input_array [3:0];
reg [1:0] counter;


wire s_channel_valid;
wire s_channel_ready;
wire d_channel_ready;
wire d_channel_valid;

reg fifo_has_packet;

integer i;

localparam BASE_1B = 8'b1000_0000;
localparam BASE_2B = 8'b1100_0000;
localparam BASE_4B = 8'b1111_0000;
localparam BASE_8B = 8'b1111_1111;

localparam NOT_VALID = 0;
localparam VALID = 1;
reg state, next_state;

reg [1:0] fake_ready_state, fake_ready_next_state;

strb2mask ins1
(
    .rst (rst),
    .clk (clk),
    .m_axi_wstrb (m_axi_wstrb),
    //.pmesh_mask (pmesh_mask),
    .pmesh_data_size (data_size),
    .pmesh_addr (addr),
    .s_channel_ready (s_channel_ready),
    .s_channel_valid (s_channel_valid),
    .d_channel_valid (d_channel_valid),
    .d_channel_ready (d_channel_ready)
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
    #1000 $finish;
    $display("dump finish");
end



// input counter control
always@ (posedge clk) begin
    if (rst) counter <= 0;
    else if (s_channel_ready & s_channel_valid) counter <= counter + 1;
    else counter <= counter;
end

always@(*) begin
    m_axi_wstrb = input_array[counter];
end



// valid control state machine 

assign s_channel_valid = (state == VALID);
always@(posedge clk) begin
    if (rst) state <= NOT_VALID;
    else state <= next_state;
end

always@(*) begin
    if (fifo_has_packet) next_state <= VALID;
    else if (~fifo_has_packet) next_state <= NOT_VALID;
end


//ready control

always@ (posedge clk) begin
    if (rst) fake_ready_state <= 2'b00;
    else fake_ready_state <= fake_ready_next_state;
end

always@ (*) begin
    if (fake_ready_state == 2'b00)
        fake_ready_next_state = 2'b01;
    else if (fake_ready_state == 2'b01)
        fake_ready_next_state = 2'b10;
    else if (fake_ready_state == 2'b10) begin
        if (d_channel_ready & d_channel_valid) 
            fake_ready_next_state = 2'b11;
        else fake_ready_next_state = fake_ready_state;
    end
    else if (fake_ready_state == 2'b11) 
        fake_ready_next_state = 2'b00;
    else 
        fake_ready_next_state = fake_ready_state;
end

assign d_channel_ready = (fake_ready_state == 2'b10) ? 1'b1 : 1'b0;

//assign d_channel_ready = 1;



initial begin
$display("simulation start");
input_array[0] <= BASE_4B;
input_array[1] <= 8'b0111_1110;;
input_array[2] <= BASE_4B;
input_array[3] <= 8'b0111_1111;
$display("input array initialize complete");
rst <= 0;
@(negedge clk) rst <= 1;
fifo_has_packet <= 1;
@(negedge clk) rst <= 1;
@(negedge clk) rst <= 0;
/*
repeat(6) @(posedge clk);
@(posedge clk) fifo_has_packet <= 0;

repeat(5) @(posedge clk);
@(posedge clk)fifo_has_packet <= 1;

repeat(6) @(posedge clk);
@(posedge clk) fifo_has_packet <= 0;

repeat(5) @(posedge clk);
@(posedge clk)fifo_has_packet <= 1;

*/

end


endmodule
