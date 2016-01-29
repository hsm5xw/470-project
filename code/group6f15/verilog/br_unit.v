`timescale 1ns/100ps

module br_unit(// Inputs
              input reset,
              input clock,
              input ISSUE_RS br_in,
      
              output BRANCH_RESULT br_out
             );
  
  logic [63:0] calculated_target;
  logic calculated_taken, branch_targets_match;

  logic [63:0] br_disp;

  assign br_disp = { {41{br_in.branch_disp[20]}}, br_in.branch_disp[20:0], 2'b00};

  always_comb
  begin
    case (br_in.branch_cond_op[1:0]) // 'full-case'  All cases covered, no need for a default
      2'b00: calculated_taken = (br_in.op2_value[0] == 0);  // LBC: (lsb(opa) == 0) ?
      2'b01: calculated_taken = (br_in.op2_value == 0);     // EQ: (opa == 0) ?
      2'b10: calculated_taken = (br_in.op2_value[63] == 1); // LT: (signed(opa) < 0) : check sign bit
      2'b11: calculated_taken = (br_in.op2_value[63] == 1) || (br_in.op2_value == 0); // LE: (signed(opa) <= 0)
    endcase

     // negate cond if func[2] is set
    if (br_in.branch_cond_op[2])
      calculated_taken = ~calculated_taken;
  end

  always_comb begin
    br_out.branch_actually_taken = 0;
    br_out.result = 64'hCDED_BEEF_BAAD_BEEF;
    br_out.thread_ID = br_in.thread_ID;
    br_out.mispredict = 0;
    br_out.PRN_index = `PR_SIZE-1;           // 'Zero REG'
    br_out.ROB_index = br_in.ROB_index;

    calculated_target = br_disp + br_in.next_pc;
    if(br_in.instr_type == UNCOND_BRANCH && br_in.operation == ALU_AND)
      calculated_target = br_in.op1_value & br_in.op2_value;
    branch_targets_match = calculated_target == br_in.branch_target_addr;

    if(br_in.instr_type == UNCOND_BRANCH) begin
      br_out.branch_actually_taken = 1;

      if(br_in.operation == ALU_ADDQ) begin 
        br_out.result = calculated_target;
      end
      else if(br_in.operation == ALU_AND) begin
        br_out.result = br_in.op1_value & br_in.op2_value;
      end

      if(br_in.branch_predicted_taken && branch_targets_match) begin
        br_out.mispredict = 0;
      end // if not a mispredict
      else begin
        br_out.mispredict = 1;
      end // if a mispredict
      
    end // instr = UNCOND_BRANCH
    else if(br_in.instr_type == BRANCH) begin

      if(calculated_taken) begin
        br_out.result                = calculated_target;
        br_out.branch_actually_taken = 1;

        if(br_in.branch_predicted_taken && branch_targets_match) begin
          br_out.mispredict = 0;
        end // if(preidcted_taken)
        else begin
          br_out.mispredict = 1;
        end // else

      end // else instr == BRANCH
      else begin
        br_out.result = br_in.next_pc;
        if(br_in.branch_predicted_taken)
          br_out.mispredict = 1;
        else
          br_out.mispredict = 0;
      end 
      
    end // instr = BRANCH
  end
endmodule // brcond