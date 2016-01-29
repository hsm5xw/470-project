/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id.v                                                //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////
//`timescale 1ns/100ps

//Decoder from project 3. Need to add the logic to deal with SMT stuff 
//in it, otherwise it will stay the same. WE STILL NEED TO ADD FORK instruction

`timescale 1ns/100ps

module decoder (

  input [`INSTR_BITS-1:0] inst,
  input                   valid_inst_in, 
  // ignore inst when low, outputs will reflect noop (except valid_inst)

  output ALU_OPA_SELECT   opa_select,
  output ALU_OPB_SELECT   opb_select,
  output DEST_REG_SEL     dest_reg,
  output ALU_FUNC         alu_func,
  output logic [2:0]      instr_type,
  output logic            rd_mem, wr_mem, ldl_mem, stc_mem,
  output logic            valid_inst      
  // for counting valid instructions executed and for making the fetch stage die on halts or
  // keeping track of when to allow the next instruction out of fetch 0 for HALT and illegal 
  // instructions (die on halt)
);
  logic cond_branch, uncond_branch, halt, illegal;

  assign valid_inst = valid_inst_in & ~illegal;

  always_comb begin
    // default control values:
    // - valid instructions must override these defaults as necessary.
    //   opa_select, opb_select, and alu_func should be set explicitly.
    // - invalid instructions should clear valid_inst.
    // - These defaults are equivalent to a noop
    // * see sys_defs.vh for the constants used here
    opa_select = ALU_OPA_IS_REGA;
    opb_select = ALU_OPB_IS_REGB;
    alu_func = ALU_ADDQ;
    dest_reg = DEST_NONE;
    instr_type = OTHER;
    rd_mem = `FALSE;
    wr_mem = `FALSE;
    ldl_mem = `FALSE;
    stc_mem = `FALSE;
    cond_branch = `FALSE;
    uncond_branch = `FALSE;
    halt = `FALSE;
    illegal = `FALSE;

    if(inst == `NOOP_INST)
      instr_type = NOOP;

    if(valid_inst_in) begin
      case ({inst[31:29], 3'b0})
        6'h0:
        case (inst[31:26])
          `PAL_INST: begin
            if (inst[25:0] == `PAL_HALT) begin
              halt = `TRUE;
              instr_type = HALT;
            end 
            else if(inst[25:24] == 2'h3) begin
              instr_type = FORK;
            end
            else begin
              illegal = `TRUE;
            end
          end            
          default: illegal = `TRUE;
        endcase // case(inst[31:26])
       
        6'h10:
        begin
          opa_select = ALU_OPA_IS_REGA;
          opb_select = inst[12] ? ALU_OPB_IS_ALU_IMM : ALU_OPB_IS_REGB;
          dest_reg = DEST_IS_REGC;
          case (inst[31:26])
            `INTA_GRP:
            case (inst[11:5])
              `CMPULT_INST:  alu_func = ALU_CMPULT;
              `ADDQ_INST:    alu_func = ALU_ADDQ;
              `SUBQ_INST:    alu_func = ALU_SUBQ;
              `CMPEQ_INST:   alu_func = ALU_CMPEQ;
              `CMPULE_INST:  alu_func = ALU_CMPULE;
              `CMPLT_INST:   alu_func = ALU_CMPLT;
              `CMPLE_INST:   alu_func = ALU_CMPLE;
              default:       illegal  = `TRUE;
            endcase // case(inst[11:5])
            `INTL_GRP:
            case (inst[11:5])
              `AND_INST:    alu_func = ALU_AND;
              `BIC_INST:    alu_func = ALU_BIC;
              `BIS_INST:    alu_func = ALU_BIS;
              `ORNOT_INST:  alu_func = ALU_ORNOT;
              `XOR_INST:    alu_func = ALU_XOR;
              `EQV_INST:    alu_func = ALU_EQV;
              default:      illegal  = `TRUE;
            endcase // case(inst[11:5])
            `INTS_GRP:
            case (inst[11:5])
              `SRL_INST:  alu_func = ALU_SRL;
              `SLL_INST:  alu_func = ALU_SLL;
              `SRA_INST:  alu_func = ALU_SRA;
              default:    illegal  = `TRUE;
            endcase // case(inst[11:5])
            `INTM_GRP:
            case (inst[11:5])
              `MULQ_INST:       alu_func = ALU_MULQ;
              default:          illegal  = `TRUE;
            endcase // case(inst[11:5])
            `ITFP_GRP:       illegal = `TRUE;       // unimplemented
            `FLTV_GRP:       illegal = `TRUE;       // unimplemented
            `FLTI_GRP:       illegal = `TRUE;       // unimplemented
            `FLTL_GRP:       illegal = `TRUE;       // unimplemented
          endcase // case(inst[31:26])
        end
           
        6'h18:
        case (inst[31:26])
          `MISC_GRP:       illegal = `TRUE; // unimplemented
          `JSR_GRP:
          begin
            // JMP, JSR, RET, and JSR_CO have identical semantics
            instr_type = UNCOND_BRANCH;
            opa_select = ALU_OPA_IS_NOT3;
            opb_select = ALU_OPB_IS_REGB;
            alu_func = ALU_AND; // clear low 2 bits (word-align)
            dest_reg = DEST_IS_REGA;
            uncond_branch = `TRUE;
          end
          `FTPI_GRP:       illegal = `TRUE;       // unimplemented
        endcase // case(inst[31:26])
           
        6'h08, 6'h20, 6'h28:
        begin
          opa_select = ALU_OPA_IS_MEM_DISP;
          opb_select = ALU_OPB_IS_REGB;
          alu_func = ALU_ADDQ;
          dest_reg = DEST_IS_REGA;
          case (inst[31:26])
            `LDA_INST:  /* defaults are OK */;
            `LDQ_INST:
            begin
              rd_mem = `TRUE;
              dest_reg = DEST_IS_REGA;
            end // case: `LDQ_INST
            `LDQ_L_INST:
            begin
              rd_mem = `TRUE;
              ldl_mem = `TRUE;
              dest_reg = DEST_IS_REGA;
            end // case: `LDQ_L_INST
            `STQ_INST:
            begin
              wr_mem = `TRUE;
              dest_reg = DEST_NONE;
            end // case: `STQ_INST
            `STQ_C_INST:
            begin
              wr_mem = `TRUE;
              stc_mem = `TRUE;
              dest_reg = DEST_IS_REGA;
            end // case: `STQ_INST
            default:       illegal = `TRUE;
          endcase // case(inst[31:26])
        end
           
        6'h30, 6'h38:
        begin
          opa_select = ALU_OPA_IS_NPC;
          opb_select = ALU_OPB_IS_BR_DISP;
          alu_func = ALU_ADDQ;
          case (inst[31:26])
            `FBEQ_INST, `FBLT_INST, `FBLE_INST,
            `FBNE_INST, `FBGE_INST, `FBGT_INST:
            begin
              // FP conditionals not implemented
              illegal = `TRUE;
            end

            `BR_INST, `BSR_INST:
            begin
              instr_type = UNCOND_BRANCH;
              dest_reg = DEST_IS_REGA;
              uncond_branch = `TRUE;
            end

            default:
            begin
              instr_type = BRANCH;
              cond_branch = `TRUE; // all others are conditional
            end
          endcase // case(inst[31:26])
        end
      endcase // case(inst[31:29] << 3)
    end // if(~valid_inst_in)
  end // always
endmodule // decoder

module id_stage (
  input                      clock,               // system clock
  input                      reset,               // system reset
  input                      mispredict_thread_0, // high if a mispredicted branch from thread 0 is committed
  input                      mispredict_thread_1, // high if a mispredicted branch from thread 1 is committed
  input IF_ID [1:0]          inst_in,
  //THESE ARE USED BY THE RAT
  input [1:0] [`PR_BITS-1:0] free_PRN,            // PRN to rename inst, from the PRF module
  input RAT_ARR [1:0]        RRAT_arr,            // used to recover RAT in case of branch mispredict
  input                      stall_0,
  input                      stall_1,

  output RAT_ARR             [1:0] RAT_arr,
  output ID_DISPATCH [1:0]   inst_dispatch,       // goes to the dispatch module
  output RAT_PRF [1:0]       inst_PRF             // goes to the PRF module
);
  
  logic  [1:0] [4:0] ra_idx, rb_idx, rc_idx; 
  logic        [1:0] valid;
  DEST_REG_SEL [1:0] dest_reg_sel;
  ID_RAT       [1:0] inst_RAT;                     // goes to the RAT module

  generate
    genvar i;
    for(i=0; i<2; i++) begin
      decoder decoder_inst (
        .inst(inst_in[i].instr),
        .valid_inst_in(inst_in[i].valid_inst),

        .opa_select(inst_dispatch[i].opa_select),
        .opb_select(inst_dispatch[i].opb_select),
        .dest_reg(dest_reg_sel[i]),
        .alu_func(inst_dispatch[i].alu_func),
        .instr_type(inst_dispatch[i].instr_type),
        .rd_mem(inst_dispatch[i].rd_mem), 
        .wr_mem(inst_dispatch[i].wr_mem), 
        .ldl_mem(inst_dispatch[i].ldl_mem), 
        .stc_mem(inst_dispatch[i].stc_mem), 
        .valid_inst(valid[i])
      );
    end
  endgenerate

  rat rat_0 (
    //Inputs
    .clock(clock),
    .reset(reset),
    .mispredict_thread_0(mispredict_thread_0),
    .mispredict_thread_1(mispredict_thread_1),
    .free_PRN(free_PRN),
    .inst_in(inst_RAT),
    .RRAT_arr(RRAT_arr),
    .stall_0(stall_0),
    .stall_1(stall_1),

    //outputs
    .RAT_arr(RAT_arr),
    .inst_out(inst_PRF)
  );

  always_comb begin
    for(int i=0; i<2; i++) begin
      ra_idx[i] = inst_in[i].instr[25:21];    // inst operand A register index
      rb_idx[i] = inst_in[i].instr[20:16];    // inst operand B register index
      rc_idx[i] = inst_in[i].instr[4:0];      // inst operand C register index

      // need this to handle banches that writes the next pc to a dest reg
      inst_RAT[i].next_pc       = inst_in[i].next_pc;
      inst_RAT[i].uncond_branch = inst_dispatch[i].instr_type==UNCOND_BRANCH;

      inst_RAT[i].valid     = valid[i];
      inst_RAT[i].thread_id = inst_in[i].thread_id;
      inst_RAT[i].ARN_opa   = ra_idx[i];
      inst_RAT[i].ARN_opb   = rb_idx[i];

      case(dest_reg_sel[i])
        DEST_IS_REGC: inst_RAT[i].ARN_dest = rc_idx[i];
        DEST_IS_REGA: inst_RAT[i].ARN_dest = ra_idx[i];
        DEST_NONE:    inst_RAT[i].ARN_dest = `ZERO_REG;
        default:      inst_RAT[i].ARN_dest = `ZERO_REG;
      endcase

      inst_dispatch[i].ARN_dest = inst_RAT[i].ARN_dest;
      inst_dispatch[i].PRN_dest = inst_PRF[i].PRN_dest;
      inst_dispatch[i].opa_PRN  = inst_PRF[i].PRN_opa;
      inst_dispatch[i].opb_PRN  = inst_PRF[i].PRN_opb;

      inst_dispatch[i].thread_ID          = inst_in[i].thread_id;
      inst_dispatch[i].instr              = inst_in[i].instr;
      inst_dispatch[i].pc                 = inst_in[i].pc;
      inst_dispatch[i].next_pc            = inst_in[i].next_pc;
      inst_dispatch[i].branch_target_addr = inst_in[i].branch_target_addr;
      inst_dispatch[i].branch_taken       = inst_in[i].branch_taken;
      inst_dispatch[i].instr              = inst_in[i].instr;
      inst_dispatch[i].valid              = valid[i];

      if(mispredict_thread_0 && !inst_in[i].thread_id) begin
        inst_dispatch[i].valid = 0;
        inst_RAT[i].valid      = 0;
      end

      if(mispredict_thread_1 && inst_in[i].thread_id) begin
        inst_dispatch[i].valid = 0;
        inst_RAT[i].valid      = 0;
      end
    end
  end

endmodule