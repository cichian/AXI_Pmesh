
module strb2mask (
    input wire clk,
    input wire rst,
    input wire [7:0] m_axi_wstrb,
    input wire i_valid,
    output reg [7:0] pmesh_mask, 
    output wire o_ready,
    input wire i_ready,
    output wire o_valid
);


localparam BASE_1B = 8'b1000_0000;
localparam BASE_2B = 8'b1100_0000;
localparam BASE_4B = 8'b1111_0000;
localparam BASE_8B = 8'b1111_1111;

localparam not_valid_state = 1'b0;
localparam valid_state = 1'b1;

reg [7:0] source_q;
reg [7:0] source_d;
reg [7:0] target [14:0];
reg [14:0] all_match; 
reg [14:0] part_match;
reg [7:0] output_mask;
reg [7:0] reverse_source;
reg [7:0] reverse_target [14:0];
reg valid_delay_stage1;
reg valid_delay_stage2;
integer i;
integer j, k;

// FSM for output valid control 
reg ovalid_state;
reg ovalid_state_next;


assign o_ready = (|all_match) & i_ready;

always@ (*) begin
    reverse_source[0] = source_q[7];
    reverse_source[1] = source_q[6];
    reverse_source[2] = source_q[5];
    reverse_source[3] = source_q[4];
    reverse_source[4] = source_q[3];
    reverse_source[5] = source_q[2];
    reverse_source[6] = source_q[1];
    reverse_source[7] = source_q[0];
    for (i = 0; i < 15; i = i + 1) begin
        reverse_target[i][0] = target[i][7];
        reverse_target[i][1] = target[i][6];
        reverse_target[i][2] = target[i][5];
        reverse_target[i][3] = target[i][4];
        reverse_target[i][4] = target[i][3];
        reverse_target[i][5] = target[i][2];
        reverse_target[i][6] = target[i][1];
        reverse_target[i][7] = target[i][0];
    end
end

always@ (*) begin  
     
    target[0] = BASE_8B >> 0; 
    target[1] = BASE_4B >> 4; 
    target[2] = BASE_2B >> 6; 
    target[3] = BASE_1B >> 7; 
    target[4] = BASE_1B >> 6;
    target[5] = BASE_2B >> 4;
    target[6] = BASE_1B >> 5;
    target[7] = BASE_1B >> 4;
    target[8] = BASE_4B >> 0;
    target[9] = BASE_2B >> 2;
    target[10] = BASE_1B >> 3;
    target[11] = BASE_1B >> 2;
    target[12] = BASE_2B >> 0;
    target[13] = BASE_1B >> 1;
    target[14] = BASE_1B >> 0;
    for (j = 0; j < 15; j = j + 1) begin
        all_match[j] = (source_q == target[j]);
    end
end

always@ (*) begin
    for (k = 0; k < 15; k = k + 1) begin
        part_match[k] = (source_q > target[k]) & (reverse_source > reverse_target[k]);
    end
end

always@ (*) begin
    source_d = BASE_8B;
    output_mask = BASE_8B;
    if (~i_ready) begin
        if (i_valid) begin
            source_d = source_q;
            output_mask = output_mask;
        end
        else begin
            source_d = BASE_8B;
            output_mask = output_mask;
        end
    end
    else if ((|all_match)) begin
        source_d = m_axi_wstrb;
        casex (all_match)
            15'b????_????_????_??1: output_mask = target[0];
            15'b????_????_????_?1?: output_mask = target[1];
            15'b????_????_????_1??: output_mask = target[2];
            15'b????_????_???1_???: output_mask = target[3];
            15'b????_????_??1?_???: output_mask = target[4];
            15'b????_????_?1??_???: output_mask = target[5];
            15'b????_????_1???_???: output_mask = target[6];
            15'b????_???1_????_???: output_mask = target[7];
            15'b????_??1?_????_???: output_mask = target[8];
            15'b????_?1??_????_???: output_mask = target[9];
            15'b????_1???_????_???: output_mask = target[10];
            15'b???1_????_????_???: output_mask = target[11];
            15'b??1?_????_????_???: output_mask = target[12];
            15'b?1??_????_????_???: output_mask = target[13];
            15'b1???_????_????_???: output_mask = target[14];
            default:  output_mask = BASE_8B;
        endcase
    end
    else begin
        casex (part_match)
            15'b????_????_????_??1: begin output_mask = target[0]; source_d = source_q - target[0]; end
            15'b????_????_????_?1?: begin output_mask = target[1]; source_d = source_q - target[1]; end
            15'b????_????_????_1??: begin output_mask = target[2]; source_d = source_q - target[2]; end
            15'b????_????_???1_???: begin output_mask = target[3]; source_d = source_q - target[3]; end
            15'b????_????_??1?_???: begin output_mask = target[4]; source_d = source_q - target[4]; end
            15'b????_????_?1??_???: begin output_mask = target[5]; source_d = source_q - target[5]; end
            15'b????_????_1???_???: begin output_mask = target[6]; source_d = source_q - target[6]; end
            15'b????_???1_????_???: begin output_mask = target[7]; source_d = source_q - target[7]; end
            15'b????_??1?_????_???: begin output_mask = target[8]; source_d = source_q - target[8]; end
            15'b????_?1??_????_???: begin output_mask = target[9]; source_d = source_q - target[9]; end
            15'b????_1???_????_???: begin output_mask = target[10]; source_d = source_q - target[10]; end
            15'b???1_????_????_???: begin output_mask = target[11]; source_d = source_q - target[11]; end
            15'b??1?_????_????_???: begin output_mask = target[12]; source_d = source_q - target[12]; end
            15'b?1??_????_????_???: begin output_mask = target[13]; source_d = source_q - target[13]; end
            15'b1???_????_????_???: begin output_mask = target[14]; source_d = source_q - target[14]; end
            default:  begin output_mask = BASE_8B; source_d = source_q; end
        endcase
    end
end

always@ (posedge clk) begin
   if (rst) begin
        valid_delay_stage1 <= 0;
   end
   else begin
        valid_delay_stage1 <= i_valid;
   end
end

// FSN for output valid
always@(posedge clk) begin
    if (rst) ovalid_state <= not_valid_state;
    else ovalid_state <= ovalid_state_next;
end

always@ (*) begin
  if (ovalid_state == not_valid_state) begin
      if (valid_delay_stage1) ovalid_state_next = valid_state;
      else ovalid_state_next = ovalid_state;
  end
  else if (ovalid_state == valid_state) begin
      if (i_ready) ovalid_state_next = not_valid_state;
      else ovalid_state_next = ovalid_state;
  end
end

assign o_valid = (ovalid_state == valid_state);

always@ (posedge clk) begin 
    if (rst) begin
        pmesh_mask <= BASE_8B;
    end
    else begin
        pmesh_mask <= output_mask;
    end 
end

always@ (posedge clk) begin
    if (rst) begin
        source_q <= m_axi_wstrb;
    end
    else begin
        source_q <= source_d;
    end
end

endmodule 

