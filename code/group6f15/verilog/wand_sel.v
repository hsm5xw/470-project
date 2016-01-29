/*
   wand_sel - Priority selector module.
   updated for SystemVerilog: 3/18/2015 by szekany
*/
`timescale 1ns/100ps

`default_nettype none
module wand_sel (req,gnt);
  // synopsys template
  parameter WIDTH=64;
  input logic  [WIDTH-1:0] req;
  output wand [WIDTH-1:0] gnt;

  logic  [WIDTH-1:0] req_r;
  wand  [WIDTH-1:0] gnt_r;

  //priority selector
  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1)
    begin : reverse
      assign req_r[WIDTH-1-i] = req[i];
      assign gnt[WIDTH-1-i]   = gnt_r[i];
    end

    for (i = 0; i < WIDTH-1 ; i = i + 1)
    begin : steve_is_verilog_genius
      assign gnt_r [WIDTH-1:i] = {{(WIDTH-1-i){~req_r[i]}},req_r[i]};
    end
  endgenerate
  assign gnt_r[WIDTH-1] = req_r[WIDTH-1];

endmodule
`default_nettype wire
