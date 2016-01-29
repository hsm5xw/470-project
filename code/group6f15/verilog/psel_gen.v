/*
  Joshua Smith (smjoshua@umich.edu)

  psel_gen.v - Parametrizable priority selector module

  Module is parametrizable in the width of the request bus (WIDTH), and the
  number of simultaneous requests granted (REQS).

  updated for SystemVerilog: 3/18/2015 by szekany

 */
`timescale 1ns/100ps

`default_nettype none
module psel_gen ( // Inputs
                  req,
                 
                  // Outputs
                  gnt,
                  gnt_bus, 
                  empty
                );

  parameter REQS  = 2;
  parameter WIDTH = `PR_SIZE;

  // Inputs
  input logic  [WIDTH-1:0]       req;

  // Outputs
  output wor  [WIDTH-1:0]       gnt;
  output wand [WIDTH*REQS-1:0]  gnt_bus;
  output logic                  empty;

  // Internal stuff
  logic  [WIDTH*REQS-1:0]  tmp_reqs;
  logic  [WIDTH*REQS-1:0]  tmp_reqs_rev;
  logic  [WIDTH*REQS-1:0]  tmp_gnts;
  logic  [WIDTH*REQS-1:0]  tmp_gnts_rev;

  // Calculate trivial empty case
  assign empty = ~(|req);
  
  genvar j, k;
  generate
    for (j=0; j<REQS; j=j+1)
    begin:foo
      // Zero'th request/grant trivial, just normal priority selector
      if (j == 0) begin
        assign tmp_reqs[WIDTH-1:0]  = req[WIDTH-1:0];
        assign gnt_bus[WIDTH-1:0]   = tmp_gnts[WIDTH-1:0];

      // First request/grant, uses input request vector but reversed, mask out
      //  granted bit from first request.
      end else if (j == 1) begin
        for (k=0; k<WIDTH; k=k+1)
        begin:Jone
          assign tmp_reqs[2*WIDTH-1-k] = req[k];
        end

        assign gnt_bus[2*WIDTH-1 -: WIDTH] = tmp_gnts_rev[2*WIDTH-1 -: WIDTH] & ~tmp_gnts[WIDTH-1:0];

      // Request/grants 2-N.  Request vector for j'th request will be same as
      //  j-2 with grant from j-2 masked out.  Will alternate between normal and
      //  reversed priority order.  For the odd lines, need to use reversed grant
      //  output so that it's consistent with order of input.
      end else begin    // mask out gnt from req[j-2]
        assign tmp_reqs[(j+1)*WIDTH-1 -: WIDTH] = tmp_reqs[(j-1)*WIDTH-1 -: WIDTH] &
                                                  ~tmp_gnts[(j-1)*WIDTH-1 -: WIDTH];
        
        if (j%2==0)
          assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts[(j+1)*WIDTH-1 -: WIDTH];
        else
          assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts_rev[(j+1)*WIDTH-1 -: WIDTH];

      end

      // instantiate priority selectors
      wand_sel #(WIDTH) psel (.req(tmp_reqs[(j+1)*WIDTH-1 -: WIDTH]), .gnt(tmp_gnts[(j+1)*WIDTH-1 -: WIDTH]));

      // reverse gnts (really only for odd request lines)
      for (k=0; k<WIDTH; k=k+1)
      begin:rev
        assign tmp_gnts_rev[(j+1)*WIDTH-1-k] = tmp_gnts[(j)*WIDTH+k];
      end

      // Mask out earlier granted bits from later grant lines.
      // gnt[j] = tmp_gnt[j] & ~tmp_gnt[j-1] & ~tmp_gnt[j-3]...
      for (k=j+1; k<REQS; k=k+2)
      begin:gnt_mask
        assign gnt_bus[(k+1)*WIDTH-1 -: WIDTH] = ~gnt_bus[(j+1)*WIDTH-1 -: WIDTH];
      end
    end

    // assign final gnt outputs
    // gnt_bus is the full-width vector for each request line, so OR everything
    for(k=0; k<REQS; k=k+1)
    begin:final_gnt
      assign gnt = gnt_bus[(k+1)*WIDTH-1 -: WIDTH];
    end
  endgenerate

endmodule
`default_nettype wire
