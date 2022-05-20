module fake_mem_ctrl
#(
    parameter [63:0] MEM_BASE   = 64'h0000000000000000,
    parameter [63:0] SIZE_BYTES = 64'h0000000000010000
)
(

    input wire clk,
    input wire rst_n,

    input wire noc_valid_in,
    input wire [64-1:0] noc_data_in,
    output reg noc_ready_in,


    output reg noc_valid_out,
    output reg [64-1:0] noc_data_out,
    input wire noc_ready_out

);

reg mem_valid_in;
reg [3*64-1:0] mem_header_in;
reg mem_ready_in;


//Input buffer

reg [64-1:0] buf_in_mem_f [10:0];
reg [64-1:0] buf_in_mem_next;
reg [8-1:0] buf_in_counter_f;
reg [8-1:0] buf_in_counter_next;
reg [3:0] buf_in_wr_ptr_f;
reg [3:0] buf_in_wr_ptr_next;


reg         sim_memory_write;
reg [511:0] sim_memory_wr_data;
reg [63:0]  sim_memory_wr_addr;
reg [63:0]  sim_memory_rd_addr;
reg [511:0] sim_memory [SIZE_BYTES/(64*8)-1:0];
// reg [SIZE_BYTES-1:0] sim_memory;


always @ *
begin
    noc_ready_in = (buf_in_counter_f == 0) || (buf_in_counter_f < (buf_in_mem_f[0][29:22]+1));
end

always @ *
begin
    if (noc_valid_in && noc_ready_in)
    begin
        buf_in_counter_next = buf_in_counter_f + 1;
    end
    else if (mem_valid_in && mem_ready_in)
    begin
        buf_in_counter_next = 0;
    end
    else
    begin
        buf_in_counter_next = buf_in_counter_f;
    end
end


always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_in_counter_f <= 0;
    end
    else
    begin
        buf_in_counter_f <= buf_in_counter_next;
    end
end

always @ *
begin
    if (mem_valid_in && mem_ready_in)
    begin
        buf_in_wr_ptr_next = 0;
    end
    else if (noc_valid_in && noc_ready_in)
    begin
        buf_in_wr_ptr_next = buf_in_wr_ptr_f + 1;
    end
    else
    begin
        buf_in_wr_ptr_next = buf_in_wr_ptr_f;
    end
end


always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_in_wr_ptr_f <= 0;
    end
    else
    begin
        buf_in_wr_ptr_f <= buf_in_wr_ptr_next;
    end
end


always @ *
begin
    if (noc_valid_in && noc_ready_in)
    begin
        buf_in_mem_next = noc_data_in;
    end
    else
    begin
        buf_in_mem_next = buf_in_mem_f[buf_in_wr_ptr_f];
    end
end

always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_in_mem_f[buf_in_wr_ptr_f] <= 0;
    end
    else
    begin
        buf_in_mem_f[buf_in_wr_ptr_f] <= buf_in_mem_next;
    end
end


always @ *
begin
    mem_valid_in = (buf_in_counter_f != 0) && (buf_in_counter_f == (buf_in_mem_f[0][29:22]+1));
end

always @ *
begin
    mem_header_in = {buf_in_mem_f[2], buf_in_mem_f[1], buf_in_mem_f[0]};
end

//Memory read/write

wire [8-1:0] msg_type;
wire [8-1:0] msg_mshrid;
wire [3-1:0] msg_data_size;
wire [40-1:0] msg_addr;
wire [14-1:0] msg_src_chipid;
wire [8-1:0] msg_src_x;
wire [8-1:0] msg_src_y;
wire [4-1:0] msg_src_fbits;

reg [8-1:0] msg_send_type;
reg [8-1:0] msg_send_length;
reg [64-1:0] msg_send_data [7:0];
reg [64-1:0] mem_temp;
wire [64*3-1:0] msg_send_header;

l2_decoder decoder(
    .msg_header         (mem_header_in),
    .msg_type           (msg_type),
    .msg_length         (),
    .msg_mshrid         (msg_mshrid),
    .msg_data_size      (msg_data_size),
    .msg_cache_type     (),
    .msg_subline_vector (),
    .msg_mesi           (),
    .msg_l2_miss        (),
    .msg_subline_id     (),
    .msg_last_subline   (),
    .msg_addr           (msg_addr),
    .msg_src_chipid     (msg_src_chipid),
    .msg_src_x          (msg_src_x),
    .msg_src_y          (msg_src_y),
    .msg_src_fbits      (msg_src_fbits),
    .msg_sdid           (),
    .msg_lsid           ()
);

reg [63:0] write_mask;

always @ *
begin
    if (msg_data_size == 3'b001)
    begin
        write_mask = 64'hff00000000000000;
        write_mask = write_mask >> (8*msg_addr[2:0]);
    end
    else if (msg_data_size == 3'b010)
    begin
        write_mask = 64'hffff000000000000;
        write_mask = write_mask >> (16*msg_addr[2:1]);
    end
    else if (msg_data_size == 3'b011)
    begin
        write_mask = 64'hffffffff00000000;
        write_mask = write_mask >> (32*msg_addr[2]);
    end
    else if (msg_data_size == 3'b100)
    begin
        write_mask = 64'hffffffffffffffff;
    end
    else
    begin
        write_mask = 64'h0000000000000000;
    end
end


always @ *
begin
    // initialize to get rid of msim warnings
    mem_temp = 64'h0;
    msg_send_length = 8'b0;
    sim_memory_rd_addr = MEM_BASE;
    sim_memory_write = 1'b0;
    sim_memory_wr_addr = MEM_BASE;
    sim_memory_wr_data = 512'b0;
    if (mem_valid_in)
    begin
        case (msg_type)
        8'd19:
        begin
 // ifdef PITON_DPI
 // ifndef PITON_SIM_MEMORY
            sim_memory_rd_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true read addr: %h", sim_memory_rd_addr);
            msg_send_data[0] = sim_memory[sim_memory_rd_addr[63:6]][9'b000000000+:64];
            msg_send_data[1] = sim_memory[sim_memory_rd_addr[63:6]][9'b001000000+:64];
            msg_send_data[2] = sim_memory[sim_memory_rd_addr[63:6]][9'b010000000+:64];
            msg_send_data[3] = sim_memory[sim_memory_rd_addr[63:6]][9'b011000000+:64];
            msg_send_data[4] = sim_memory[sim_memory_rd_addr[63:6]][9'b100000000+:64];
            msg_send_data[5] = sim_memory[sim_memory_rd_addr[63:6]][9'b101000000+:64];
            msg_send_data[6] = sim_memory[sim_memory_rd_addr[63:6]][9'b110000000+:64];
            msg_send_data[7] = sim_memory[sim_memory_rd_addr[63:6]][9'b111000000+:64];
 // ifndef PITON_SIM_MEMORY
 // ifdef PITON_DPI

            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000}, msg_send_data[0]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b001000}, msg_send_data[1]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b010000}, msg_send_data[2]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b011000}, msg_send_data[3]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b100000}, msg_send_data[4]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b101000}, msg_send_data[5]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b110000}, msg_send_data[6]);
            $display("MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b111000}, msg_send_data[7]);

            msg_send_type = 8'd24;
            msg_send_length = 8'd8;
        end
        8'd20:
        begin
 // ifdef PITON_DPI
 // ifndef PITON_SIM_MEMORY
            sim_memory_write = 1'b1;
            sim_memory_wr_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true write addr: %h", sim_memory_wr_addr);
            sim_memory_wr_data = {buf_in_mem_f[10], buf_in_mem_f[9], buf_in_mem_f[8], buf_in_mem_f[7], buf_in_mem_f[6], buf_in_mem_f[5], buf_in_mem_f[4], buf_in_mem_f[3]};
 // ifndef PITON_SIM_MEMORY
 // ifdef PITON_DPI
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000}, buf_in_mem_f[3]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b001000}, buf_in_mem_f[4]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b010000}, buf_in_mem_f[5]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b011000}, buf_in_mem_f[6]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b100000}, buf_in_mem_f[7]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b101000}, buf_in_mem_f[8]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b110000}, buf_in_mem_f[9]);
            $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b111000}, buf_in_mem_f[10]);

            msg_send_type = 8'd25;
            msg_send_length = 8'd0;
        end
        8'd14:
        begin
            $display("Non-cacheable load request, size: %h, address: %h", msg_data_size, msg_addr);
            msg_send_type = 8'd26;
            case(msg_data_size)
 // ifndef PITON_SIM_MEMORY
            3'b100: 
            begin
 // ifndef PITON_SIM_MEMORY
            sim_memory_rd_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true read addr: %h", sim_memory_rd_addr);
            msg_send_data[0] = sim_memory[sim_memory_rd_addr[63:6]][(msg_addr[5:0]*8)+:64];
 // ifndef PITON_SIM_MEMORY
                msg_send_length = 8'd1;
            end
 // ifndef PITON_SIM_MEMORY
            3'b111: 
            begin
 // ifndef PITON_SIM_MEMORY
            sim_memory_rd_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true read addr: %h", sim_memory_rd_addr);
            msg_send_data[0] = sim_memory[sim_memory_rd_addr[63:6]][9'b000000000+:64];
            msg_send_data[1] = sim_memory[sim_memory_rd_addr[63:6]][9'b001000000+:64];
            msg_send_data[2] = sim_memory[sim_memory_rd_addr[63:6]][9'b010000000+:64];
            msg_send_data[3] = sim_memory[sim_memory_rd_addr[63:6]][9'b011000000+:64];
            msg_send_data[4] = sim_memory[sim_memory_rd_addr[63:6]][9'b100000000+:64];
            msg_send_data[5] = sim_memory[sim_memory_rd_addr[63:6]][9'b101000000+:64];
            msg_send_data[6] = sim_memory[sim_memory_rd_addr[63:6]][9'b110000000+:64];
            msg_send_data[7] = sim_memory[sim_memory_rd_addr[63:6]][9'b111000000+:64];
 // ifndef PITON_SIM_MEMORY
 // ifndef PITON_DPI
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000}, msg_send_data[0]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b001000}, msg_send_data[1]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b010000}, msg_send_data[2]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b011000}, msg_send_data[3]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b100000}, msg_send_data[4]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b101000}, msg_send_data[5]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b110000}, msg_send_data[6]);
                $display("NC_MemRead: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b111000}, msg_send_data[7]);
                msg_send_length = 8'd8;
            end
            endcase
        end
        8'd15:
        begin
            $display("Non-cacheable store request, size: %h, address: %h", msg_data_size, msg_addr);
            msg_send_type = 8'd27;
            msg_send_length = 8'd0;
            case(msg_data_size)
            3'b111:
            begin
 // ifdef PITON_DPI
 // ifndef PITON_SIM_MEMORY
            sim_memory_write = 1'b1;
            sim_memory_wr_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true write addr: %h", sim_memory_wr_addr);
            sim_memory_wr_data = {buf_in_mem_f[10], buf_in_mem_f[9], buf_in_mem_f[8], buf_in_mem_f[7], buf_in_mem_f[6], buf_in_mem_f[5], buf_in_mem_f[4], buf_in_mem_f[3]};
 // ifndef PITON_SIM_MEMORY
 // ifdef PITON_DPI
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000}, buf_in_mem_f[3]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b001000}, buf_in_mem_f[4]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b010000}, buf_in_mem_f[5]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b011000}, buf_in_mem_f[6]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b100000}, buf_in_mem_f[7]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b101000}, buf_in_mem_f[8]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b110000}, buf_in_mem_f[9]);
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b111000}, buf_in_mem_f[10]);
            end
            3'b100:
            begin
 // ifdef PITON_DPI
 // ifndef PITON_SIM_MEMORY
            sim_memory_write = 1'b1;
            sim_memory_wr_addr = {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000} - MEM_BASE;
            $display("fake_mem_ctrl.v: true write addr: %h", sim_memory_wr_addr);
            sim_memory_wr_data = (sim_memory[{msg_addr[39:6+8],msg_addr[6+8-1:6]}] & (~(512'hffffffffffffffff << (msg_addr[5:0] * 8)))) | (buf_in_mem_f[3] << (msg_addr[5:0] * 8));
 // ifndef PITON_SIM_MEMORY
 // ifdef PITON_DPI
                $display("MemWrite: %h : %h", {{(64-40){1'b0}}, msg_addr[39:6+8],msg_addr[6+8-1:6],6'b000000}, buf_in_mem_f[3]);
            end
// ifndef PITON_SIM_MEMORY
            endcase
        end
        default:
        begin
            msg_send_type = 8'd30;
            msg_send_length = 8'd0;
        end
        endcase
    end
end
//generate for (int i = 0; i < (SIZE_BYTES/64; i = i + 1) begin : gen_sim_memory
//always @(posedge clk) begin
//    //if (~rst_n) begin
//    //    sim_memory[i] <= 512'b0;
//    //end else
//    if (sim_memory_write & (sim_memory_wr_addr[63:6] == i) begin
//        sim_memory[i] <= sim_memory_wr_data;
//    end
//end
//end

always @(posedge clk) begin
    if (sim_memory_write) begin
        sim_memory[sim_memory_wr_addr[63:6]] <= sim_memory_wr_data;
    end
end

integer i;
initial begin
    for (i = 0; i < SIZE_BYTES/(64*8); i = i + 1) begin
        sim_memory[i] = 512'b0;
    end
    $readmemh("sim_memory.memh", sim_memory);
end

 // ifdef PITON_SIM_MEMORY

l2_encoder encoder(
    .msg_dst_chipid             (msg_src_chipid),
    .msg_dst_x                  (msg_src_x),
    .msg_dst_y                  (msg_src_y),
    .msg_dst_fbits              (msg_src_fbits),
    .msg_length                 (msg_send_length),
    .msg_type                   (msg_send_type),
    .msg_mshrid                 (msg_mshrid),
    .msg_data_size              ({3{1'b0}}),
    .msg_cache_type             ({1{1'b0}}),
    .msg_subline_vector         ({4{1'b0}}),
    .msg_mesi                   ({2{1'b0}}),
    .msg_l2_miss                (msg_addr[40-1]),
    .msg_subline_id             ({2{1'b0}}),
    .msg_last_subline           ({1{1'b1}}),
    .msg_addr                   (msg_addr),
    .msg_src_chipid             ({14{1'b0}}),
    .msg_src_x                  ({8{1'b0}}),
    .msg_src_y                  ({8{1'b0}}),
    .msg_src_fbits              ({4{1'b0}}),
    .msg_sdid                   ({10{1'b0}}),
    .msg_lsid                   ({6{1'b0}}),
    .msg_header                 (msg_send_header)
);



//Output buffer

reg [64-1:0] buf_out_mem_f [8:0];
reg [64-1:0] buf_out_mem_next [8:0];
reg [8-1:0] buf_out_counter_f;
reg [8-1:0] buf_out_counter_next;
reg [3:0] buf_out_rd_ptr_f;
reg [3:0] buf_out_rd_ptr_next;

always @ *
begin
    noc_valid_out = (buf_out_counter_f != 0);
end

always @ *
begin
    mem_ready_in = (buf_out_counter_f == 0);
end


always @ *
begin
    if (noc_valid_out && noc_ready_out)
    begin
        buf_out_counter_next = buf_out_counter_f - 1;
    end
    else if (mem_valid_in && mem_ready_in)
    begin
        buf_out_counter_next = msg_send_length + 1;
    end
    else
    begin
        buf_out_counter_next = buf_out_counter_f;
    end
end

always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_out_counter_f <= 0;
    end
    else
    begin
        buf_out_counter_f <= buf_out_counter_next;
    end
end


always @ *
begin
    if (mem_valid_in && mem_ready_in)
    begin
        buf_out_rd_ptr_next = 0;
    end
    else if (noc_valid_out && noc_ready_out)
    begin
        buf_out_rd_ptr_next = buf_out_rd_ptr_f + 1;
    end
    else
    begin
        buf_out_rd_ptr_next = buf_out_rd_ptr_f;
    end
end

always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_out_rd_ptr_f <= 0;
    end
    else
    begin
        buf_out_rd_ptr_f <= buf_out_rd_ptr_next;
    end
end



always @ *
begin
    if (mem_valid_in && mem_ready_in)
    begin
        buf_out_mem_next[0] = msg_send_header[64-1:0];
        buf_out_mem_next[1] = msg_send_data[0];
        buf_out_mem_next[2] = msg_send_data[1];
        buf_out_mem_next[3] = msg_send_data[2];
        buf_out_mem_next[4] = msg_send_data[3];
        buf_out_mem_next[5] = msg_send_data[4];
        buf_out_mem_next[6] = msg_send_data[5];
        buf_out_mem_next[7] = msg_send_data[6];
        buf_out_mem_next[8] = msg_send_data[7];
    end
    else
    begin
        buf_out_mem_next[0] = buf_out_mem_f[0];
        buf_out_mem_next[1] = buf_out_mem_f[1];
        buf_out_mem_next[2] = buf_out_mem_f[2];
        buf_out_mem_next[3] = buf_out_mem_f[3];
        buf_out_mem_next[4] = buf_out_mem_f[4];
        buf_out_mem_next[5] = buf_out_mem_f[5];
        buf_out_mem_next[6] = buf_out_mem_f[6];
        buf_out_mem_next[7] = buf_out_mem_f[7];
        buf_out_mem_next[8] = buf_out_mem_f[8];
    end
end

always @ (posedge clk)
begin
    if (!rst_n)
    begin
        buf_out_mem_f[0] <= 0;
        buf_out_mem_f[1] <= 0;
        buf_out_mem_f[2] <= 0;
        buf_out_mem_f[3] <= 0;
        buf_out_mem_f[4] <= 0;
        buf_out_mem_f[5] <= 0;
        buf_out_mem_f[6] <= 0;
        buf_out_mem_f[7] <= 0;
        buf_out_mem_f[8] <= 0;
    end
    else
    begin
        buf_out_mem_f[0] <= buf_out_mem_next[0];
        buf_out_mem_f[1] <= buf_out_mem_next[1];
        buf_out_mem_f[2] <= buf_out_mem_next[2];
        buf_out_mem_f[3] <= buf_out_mem_next[3];
        buf_out_mem_f[4] <= buf_out_mem_next[4];
        buf_out_mem_f[5] <= buf_out_mem_next[5];
        buf_out_mem_f[6] <= buf_out_mem_next[6];
        buf_out_mem_f[7] <= buf_out_mem_next[7];
        buf_out_mem_f[8] <= buf_out_mem_next[8];
    end
end


always @ *
begin
    noc_valid_out = (buf_out_counter_f != 0);
end

always @ *
begin
    // Tri: another quick fix for x
    noc_data_out = 0;
    if (buf_out_rd_ptr_f < 9)
        noc_data_out = buf_out_mem_f[buf_out_rd_ptr_f];
end


always @(posedge clk) begin
    if (noc_valid_in & noc_ready_in) begin



        $display("FakeMem: input: %h", noc_data_in, $time);

    end
    if (noc_valid_out & noc_ready_out) begin



        $display("FakeMem: output %h", noc_data_out, $time);

    end
end
 // endif MINIMAL_MONITORING

endmodule