//`define TEST
`define PITON
module piton(

);

`ifdef PITON
    $display ("piton");
`else 
    $display ("no piton");
`endif





endmodule