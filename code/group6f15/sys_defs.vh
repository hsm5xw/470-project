/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////
//
// system parameters
//
//////////////////////////////////////////////

`define CLOCK_PERIOD 8

`define ROB_SIZE  32
`define ROB_BITS  5

`define RS_SIZE  16
`define RS_BITS  4

`define PR_SIZE   128
`define PR_BITS   7

`define AR_SIZE   32
`define AR_BITS   5

`define ADDR_BITS 64
`define REG_BITS 64
`define INSTR_BITS 32
`define NUM_BITS 4

`define BTB_SIZE 128  // Change the # of bits and size at the same time!
`define BTB_BITS 7

`define BRANCH_PC_BITS 5      // Change this and one below together
`define HISTORY_TABLE_SIZE 32
`define BRANCH_HISTORY_BITS 3 // Change this and one below together
`define PATTERN_TABLE_SIZE 8
`define PRED_BITS 2

//////////////////////////////////////////////
//
// data structure
//
//////////////////////////////////////////////

typedef struct packed {
  logic thread_id;
  logic valid_inst;
  logic branch_taken;
  logic [`INSTR_BITS-1:0] instr;
  logic [`ADDR_BITS-1:0] pc;
  logic [`ADDR_BITS-1:0] next_pc;
  logic [`ADDR_BITS-1:0] branch_target_addr;
} IF_ID;

typedef struct packed {

  logic [`AR_BITS-1:0] ARN_dest;             // from dispatch module: 0 is store, 1 is load **specifics of LSQ? other memory operations?
  logic [`PR_BITS-1:0] PRN_dest;
  logic [`PR_BITS-1:0] opa_PRN;
  logic [`PR_BITS-1:0] opb_PRN;

  logic [31:0] instr;                        // need the actual instruction for getting immediates
  logic [2:0] instr_type;
  logic [4:0] alu_func;

  logic [`ADDR_BITS-1:0] pc;                 // PC for branch predictor
  logic [`ADDR_BITS-1:0] next_pc;            // next_pc (for branch taken comparison)
  logic [`ADDR_BITS-1:0] branch_target_addr; // predicted branch target address

  logic [1:0] opa_select;                    // passed around RAT, from decode
  logic [1:0] opb_select;                    // also from decode

  logic thread_ID;                           // duh

  logic valid;                               // high if instr is valid

  logic rd_mem;                              // high if instr is a load
  logic wr_mem;                              // high if instr is a store
  logic ldl_mem;                             // high if instr is a load lock
  logic stc_mem;                             // high if instr is a store cond.
  logic branch_taken;

} ID_DISPATCH;

typedef struct packed {
  logic thread_id;
  logic valid;
  logic [`AR_BITS-1:0] ARN_opa;
  logic [`AR_BITS-1:0] ARN_opb;
  logic [`AR_BITS-1:0] ARN_dest;
  logic [`ADDR_BITS-1:0] next_pc; 
  logic uncond_branch;
} ID_RAT;

typedef struct packed {
  logic thread_id;
  logic [`PR_BITS-1:0] PRN_opa;
  logic [`PR_BITS-1:0] PRN_opb;
  logic write; // this inst sets the free bit of PRN_dest to 0 in the PRF module
  logic [`PR_BITS-1:0] PRN_dest;
  logic [`ADDR_BITS-1:0] next_pc; 
  logic uncond_branch;
} RAT_PRF;

typedef struct packed {
  logic ready_opa;
  logic [`REG_BITS-1:0] value_opa;
  logic ready_opb;
  logic [`REG_BITS-1:0] value_opb;
} PRF_DISPATCH;

typedef struct packed {
  logic [`REG_BITS-1:0] value;
  logic thread_id;
  logic valid;
} PRF_DATA;

typedef logic [`AR_SIZE-1:0] [`PR_BITS-1:0] RAT_ARR;

//////////////////////////////////////////////
//
// Dispatch module to RS, ROB and LSQ
//
//////////////////////////////////////////////

typedef struct packed {
    
  logic thread_ID;
  logic dispatch;
  logic [2:0] instr_type;

  logic [1:0] op_type;                                // from dispatch module (maybe from struct dispatch)
  logic [4:0] operation;                              // ALU_FUNC enum, needed for ALU
  logic [2:0] branch_cond_op;

  // *** operand 1 in the dispatched instruction
  logic op1_ready;                                    // from dispatch module (maybe from struct dispatch)
  logic [`REG_BITS-1:0] op1_value;                     // from dispatch module (maybe from struct dispatch)
  logic [`PR_BITS-1:0] op1_PRF_index;          // from dispatch module (maybe from struct dispatch)


  // *** operand 2 in the dispatched instruction
  logic op2_ready;                                    // from dispatch module (maybe from struct dispatch)
  logic [`REG_BITS-1:0] op2_value;                     // from dispatch module (maybe from struct dispatch)
  logic [`PR_BITS-1:0] op2_PRF_index;          // from dispatch module (maybe from struct dispatch)

  logic [`PR_BITS-1:0] dest_PRF_index;  

  logic [`ROB_BITS-1:0]   ROB_index;                    // from ROB 
  logic [`ADDR_BITS-1:0]  next_pc;                    // for branch prediction
  logic [`ADDR_BITS-1:0]  branch_target_addr;         // for branch prediction

  logic branch_predicted_taken;

  logic [20:0] branch_disp; 

} DISPATCH_RS;

typedef struct packed {

  logic thread_ID;
  logic [2:0] instr_type;                     // from dispatch module: 0 is halt, 1 is branch, 2 is fork

  // *** dispatch_0 data
  logic dispatch;                             // 2 DISPATCH_ROB struct outputs, this will be different
                                              //    for each ROB, take thread_id into account in dispatch
  logic [`AR_BITS-1:0 ] ARN_dest;             // from dispatch module (maybe from struct dispatch)
  logic [`PR_BITS-1:0 ] PRN_dest;             // from dispatch module (maybe from struct dispatch)
  logic [`ADDR_BITS-1:0] dispatch_pc;         // PC for branch predictor, can also use to hold pc for fork

} DISPATCH_ROB;

typedef struct packed {

  logic rd_mem;                               // instr reads from memory (is a load)
  logic wr_mem;                               // instr writes to memory (is a store)
  logic ldl_mem;                              // instr is a load lock instruction
  logic stc_mem;                              // instr is a store cond. instruction

  logic thread_ID;
    
  logic dispatch;                             // 2 DISPATCH_ROB struct outputs, this will be different
                                              //    for each ROB, take thread_id into account in dispatch
  logic [`REG_BITS-1:0]  value_to_store;        // The value to store into memory for a store operation
  logic                 value_to_store_ready;                 // base_addr is 
  logic [`PR_BITS-1:0]  value_to_store_PRN;

  logic                 base_addr_ready;          // Since base_addr is a register, might not be valid yet.
  logic [`REG_BITS-1:0]  base_addr;             // Operand 2, the base address to add operand 2 to.
  logic [`PR_BITS-1:0]  base_addr_PRN;       // if base_addr isn't ready, need to listen for PRN.
    
  logic [`REG_BITS-1:0]  offset;                // Operand 1, the signed(?) offset to add to the base
  logic [`PR_BITS-1:0]  PRN_dest;              // Destination physical register for a load

  logic [`ROB_BITS-1:0] ROB_index;

} DISPATCH_LSQ;

//////////////////////////////////////////////
//
// LSQ stuff
//
//////////////////////////////////////////////

`define SQ_SIZE   8
`define SQ_BITS   3
`define LB_SIZE   8
`define LB_BITS   3

typedef struct packed {
  logic                      ldl_mem;
  logic                      request_succeed;
  logic [`SQ_SIZE-1:0] [1:0] sq_status; // this will be updated with stuff between the head/tail pointer
                                        // of the sq
  logic                      thread_ID;

  logic                      address_resolved; // set high when the address has been computed
  
  logic               [63:0] effective_address; // = base_addr + offset

  logic               [63:0] base_addr; // OP2 of the load instruction
  logic                      base_addr_ready;
  logic       [`PR_BITS-1:0] base_addr_PRN;


  logic               [63:0] offset;
  logic               [63:0] data_from_cache;
  logic       [`PR_BITS-1:0] PRN_dest; // use this to send to the cdb

  logic      [`ROB_BITS-1:0] ROB_index;

} LB_DATA;

typedef enum logic [1:0] {
  UNKNOWN          = 2'b00,
  NOT_DEP_BY_ORDER = 2'b01,
  NOT_DEP_BY_ADDR  = 2'b10,
  DEPENDENT        = 2'b11
} load_R_store;

typedef struct packed {
  logic                valid; 
  logic         [63:0] value_to_store;
  logic                value_to_store_ready;
  logic [`PR_BITS-1:0] value_to_store_PRN;

  logic                 address_resolved;
  logic          [63:0] effective_address;

  logic          [63:0] base_addr;
  logic                 base_addr_ready;
  logic  [`PR_BITS-1:0] base_addr_PRN;

  logic          [63:0] offset;

  logic [`ROB_BITS-1:0] ROB_index;
  logic                 stc_mem;

  logic  [`PR_BITS-1:0] PRN_dest;
} SQ_DATA;

typedef struct packed {
  logic [`SQ_SIZE-1:0] valid;
  logic [`SQ_SIZE-1:0] stc_mem;
  logic [`SQ_SIZE-1:0] address_resolved;
  logic [`SQ_SIZE-1:0][63:0] address;
} SQ_ALL_DATA;

typedef struct packed {
  logic                valid;
  logic                stc_mem;
  logic [`SQ_BITS-1:0] sq_index;
  logic         [63:0] sq_address;
} SQ_ADDER_DATA;

// Tell the load buffer the store's address and value before leaving (need to tell
// dependent loads they are clear to go make a request to the D-cache)
// Need to send up to two since two stores can commit.
// Address and value are only used for store-to-load forwarding (not implemented)
typedef struct packed {
  logic [1:0]                 valid;
  logic [1:0][`SQ_BITS-1:0]   sq_index;
  logic [1:0][63:0]           sq_address;
  logic [1:0][63:0]           sq_value;
} SQ_RETIRED_DATA;

//////////////////////////////////////////////
//
// D_Cache system parameters
//
//////////////////////////////////////////////

typedef enum logic [1:0] {
  BUS_NONE     = 2'h0,
  BUS_LOAD     = 2'h1,
  BUS_STORE    = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
  COMMAND_NONE     = 2'h0,
  COMMAND_LOAD     = 2'h1,
  COMMAND_STORE    = 2'h2
} CACHE_COMMAND;

// Request Buffer
`define REQ_BUFF_SIZE    16
`define REQ_BUFF_BITS    4

typedef struct packed {
  logic [`LB_BITS-1:0] LB_index;
  logic         [63:0] addr;
  logic         [3: 0] tag;
} REQ_BUFF;

typedef struct packed {
  logic         [63:0] data;
  logic [`LB_BITS-1:0] index;
  logic                valid;
  logic                thread_ID;
} DCACHE_LSQ;

typedef struct packed {
  CACHE_COMMAND        command;
  logic [`LB_BITS-1:0] index;
  logic         [63:0] addr;
  logic         [63:0] data;
  logic                thread_ID;
} LSQ_DCACHE;


typedef struct packed {
  logic [63:0] addr;
  logic        loaded;
} LDL_STC_REG;


//////////////////////////////////////////////
//
// D_Cache: 4-way associative cache stuffs
//
//////////////////////////////////////////////

`define CACHE_ASSOC 4 // cache associativity
`define NUM_SETS  8 

`define CACHE_ASSOC_BITS  2

`define TAG_BITS  10
`define INDEX_BITS  3
`define OFFSET_BITS 3

//
// Cache Line
//
typedef struct packed {
  logic [63:0]    data;
  logic [`TAG_BITS-1:0]   tag;  // 10 bits for tag (because it's 4-way associative)
  logic           valid;
} CACHE_LINE;

//
// Cache Set
//
typedef struct packed {
    CACHE_LINE [`CACHE_ASSOC-1:0]   line;
  logic [`CACHE_ASSOC_BITS:0] pseudo_LRU_bits;  // bits to maintain for pseudo_LRU 

} CACHE_SET;

//////////////////////////////////////////////
//
// ROB data structure
//
//////////////////////////////////////////////

typedef struct packed{
  logic [63:0] FU_result;
  logic [`PR_BITS-1:0] PRN;
  logic [`ROB_BITS-1:0] ROB_index;
  logic mispredict;
  logic valid;
  logic thread_ID;  
  logic branch_actually_taken;
} CDB;

typedef struct packed {
  logic [`AR_BITS-1:0] ARN_dest;
  logic [`PR_BITS-1:0] PRN_dest;
  logic executed;
  logic mispredict;
  logic branch_actually_taken;
  logic [2:0] instr_type;
  logic [`ADDR_BITS-1:0] pc;
  logic [`ADDR_BITS-1:0] target_addr; // branch target address to the BTB
} ROB_DATA;

typedef struct packed {
  logic committed;
  logic [`ADDR_BITS-1:0] pc;
  logic [`AR_BITS-1:0]   ARN_dest;
  logic [`PR_BITS-1:0]   PRN_dest;
} ROB_RRAT;

typedef struct packed {
  logic is_branch;
  logic branch_actually_taken;
  logic mispredict;
  logic [`ADDR_BITS-1:0] pc;
  logic [`ADDR_BITS-1:0] target_addr;
} ROB_IF;

//////////////////////////////////////////////
//
// Branch Predictor
//
//////////////////////////////////////////////

typedef struct packed {
  logic committed_is_branch_0;
  logic committed_is_branch_1;
  logic branch_taken_0; // for predictor
  logic branch_taken_1; // for predictor
  logic [`ADDR_BITS-1:0] branch_pc_ROB_0; // for BTB/predictor
  logic [`ADDR_BITS-1:0] branch_pc_ROB_1; // for BTB/predictor
  logic [`ADDR_BITS-1:0] branch_target_0; // for BTB/predictor
  logic [`ADDR_BITS-1:0] branch_target_1; // for BTB/predictor
} ROB_PRED;

typedef struct packed {
  logic branch_pred_0;  // if branch is predicted NT, use npc
  logic branch_pred_1;
  logic branch_in_BTB_0; // if branch is predicted T and is in BTB, use address
  logic branch_in_BTB_1; // if branch is predicted T and is NOT in BTB, use npc
  logic [`ADDR_BITS-1:0] pred_target_add_0;
  logic [`ADDR_BITS-1:0] pred_target_add_1;
} PRED_IF;


typedef struct packed {
  logic branch_PC;
  logic branch_taken;
  logic next_pc;
} BRANCH_IF;

typedef struct packed{
    logic valid;
    logic [`ADDR_BITS-1:0] pc;
    logic [`ADDR_BITS-1:0] pred_target_add;
  } BTB_DATA;


//////////////////////////////////////////////
//
// RS data structure
//
//////////////////////////////////////////////

typedef struct packed {

  logic thread_ID;
  logic [1:0] op_type;
  logic [2:0] instr_type;
  logic [4:0] operation;                     // ALU_FUNC enum, needed for ALU
  
  logic busy;

  logic op1_ready;
  logic [`REG_BITS-1:0]        op1_value;     // 64-bit value (actual value of operand)
  logic [`PR_BITS-1:0] op1_PRF_index; // 6-bit value (PRN reg where the value will be)

  logic op2_ready;
  logic [`REG_BITS-1:0]        op2_value;
  logic [`PR_BITS-1:0] op2_PRF_index;

  logic [`PR_BITS-1:0] dest_PRF_index; // Destination PRF number

  logic [`ROB_BITS-1:0]       ROB_index;
  logic [`ADDR_BITS-1:0]      next_pc;
  logic [`ADDR_BITS-1:0]      branch_target_addr;

  logic        branch_predicted_taken;
  logic [2:0]  branch_cond_op;
  logic [20:0] branch_disp;

} RS_DATA;

//////////////////////////////////////////////
//
// Issue data structure to Functional Unit
//
//////////////////////////////////////////////

typedef struct packed{

  logic thread_ID;
  logic [2:0] instr_type;
  logic [4:0] operation;                       // ALU_FUNC enum, needed for ALU


  logic [`REG_BITS-1:0] op1_value;     // to EX
  logic [`REG_BITS-1:0] op2_value;     // to EX   
  logic [`PR_BITS-1:0] dest_PRF_index; // Destination PRF number

  logic [`ROB_BITS-1:0] ROB_index;
  logic [`ADDR_BITS-1:0] next_pc;
  logic [`ADDR_BITS-1:0] branch_target_addr;

  logic valid;

  logic branch_predicted_taken;
  logic [2:0]  branch_cond_op;
  logic [20:0] branch_disp;

} ISSUE_RS;

//////////////////////////////////////////////
//
// MULT to CDB data structure
//
//////////////////////////////////////////////

typedef struct packed{
  logic [63:0] result;
  logic [`PR_BITS-1:0] PRN_index;
  logic [`ROB_BITS-1:0] ROB_index;
  logic thread_ID;
  logic FU_done;
} FU_RESULT;


//////////////////////////////////////////////
//
// FU output to CDB
//
//////////////////////////////////////////////

typedef struct packed {
  logic thread_ID;
  logic mispredict;
  logic branch_actually_taken;
  logic [63:0] result;
  logic [`PR_BITS-1:0] PRN_index;
  logic [`ROB_BITS-1:0] ROB_index;
} BRANCH_RESULT;

//////////////////////////////////////////////
//
// Instruction Type
//
//////////////////////////////////////////////

typedef enum logic [2:0] {
  HALT                 = 3'h0,
  BRANCH               = 3'h1,
  FORK                 = 3'h2,
  OTHER                = 3'h3,
  UNCOND_BRANCH        = 3'h4,
  NOOP                 = 3'h5
} INSTR_TYPE;

//////////////////////////////////////////////
//
// Operation Type -- which functional unit
//
//////////////////////////////////////////////

typedef enum logic [1:0] {
  INVALID    = 2'h0,
  ALU        = 2'h1,
  MULT       = 2'h2,
  BRANCH_OP  = 2'h3
} OP_TYPE;

//////////////////////////////////////////////
//
// Mmeory/testbench attribute definitions
//
//////////////////////////////////////////////

`define PREFETCH_BITS          3
`define NUM_PREFETCH           7
`define SMT_PREFETCH_BITS      1
`define SMT_NUM_PREFETCH       2

`define MEM_TAG_BITS           4
`define NUM_MEM_TAGS           15
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
//`define MEM_LATENCY_IN_CYCLES  12

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

`define VIRTUAL_CLOCK_PERIOD   30.0
`define VERILOG_CLOCK_PERIOD   10.0
// probably not a good idea to change this second one

//////////////////////////////////////////////
//
// Error codes
//
//////////////////////////////////////////////

typedef enum logic [3:0] {
  NO_ERROR               = 4'h0,
  HALTED_ON_MEMORY_ERROR = 4'h1,
  HALTED_ON_HALT         = 4'h2,
  HALTED_ON_ILLEGAL      = 4'h3
} ERROR_CODE;


//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
  ALU_OPA_IS_REGA        = 2'h0,
  ALU_OPA_IS_MEM_DISP    = 2'h1,
  ALU_OPA_IS_NPC         = 2'h2,
  ALU_OPA_IS_NOT3        = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [1:0] {
  ALU_OPB_IS_REGB       = 2'h0,
  ALU_OPB_IS_ALU_IMM    = 2'h1,
  ALU_OPB_IS_BR_DISP    = 2'h2
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
  DEST_IS_REGC  = 2'h0,
  DEST_IS_REGA  = 2'h1,
  DEST_NONE     = 2'h2
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [4:0] {
  ALU_ADDQ      = 5'h00,
  ALU_SUBQ      = 5'h01,
  ALU_AND       = 5'h02,
  ALU_BIC       = 5'h03,
  ALU_BIS       = 5'h04,
  ALU_ORNOT     = 5'h05,
  ALU_XOR       = 5'h06,
  ALU_EQV       = 5'h07,
  ALU_SRL       = 5'h08,
  ALU_SLL       = 5'h09,
  ALU_SRA       = 5'h0a,
  ALU_MULQ      = 5'h0b,
  ALU_CMPEQ     = 5'h0c,
  ALU_CMPLT     = 5'h0d,
  ALU_CMPLE     = 5'h0e,
  ALU_CMPULT    = 5'h0f,
  ALU_CMPULE    = 5'h10
} ALU_FUNC;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
//
`define SD #1


// the Alpha register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 31

`define ZERO_REG_PRN `PR_SIZE-1

//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// PALcode opcodes
`define PAL_HALT  26'h555
`define PAL_WHAMI 26'h3c


//
// Basic NOOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really a PAL_INST
//
`define NOOP_INST 32'h47ff041f

//
// top level opcodes, used by the IF stage to decode Alpha instructions
//
`define PAL_INST  6'h00
`define LDA_INST  6'h08
`define LDAH_INST  6'h09
`define LDBU_INST  6'h0a
`define LDQ_U_INST  6'h0b
`define LDWU_INST  6'h0c
`define STW_INST  6'h0d
`define STB_INST  6'h0e
`define STQ_U_INST  6'h0f
`define INTA_GRP  6'h10
`define INTL_GRP  6'h11
`define INTS_GRP  6'h12
`define INTM_GRP  6'h13
`define ITFP_GRP  6'h14  // unimplemented
`define FLTV_GRP  6'h15  // unimplemented
`define FLTI_GRP  6'h16  // unimplemented
`define FLTL_GRP  6'h17  // unimplemented
`define MISC_GRP  6'h18
`define JSR_GRP    6'h1a
`define FTPI_GRP  6'h1c
`define LDF_INST  6'h20
`define LDG_INST  6'h21
`define LDS_INST  6'h22
`define LDT_INST  6'h23
`define STF_INST  6'h24
`define STG_INST  6'h25
`define STS_INST  6'h26
`define STT_INST  6'h27
`define LDL_INST  6'h28
`define LDQ_INST  6'h29
`define LDL_L_INST  6'h2a
`define LDQ_L_INST  6'h2b
`define STL_INST  6'h2c
`define STQ_INST  6'h2d
`define STL_C_INST  6'h2e
`define STQ_C_INST  6'h2f
`define BR_INST    6'h30
`define FBEQ_INST  6'h31
`define FBLT_INST  6'h32
`define FBLE_INST  6'h33
`define BSR_INST  6'h34
`define FBNE_INST  6'h35
`define FBGE_INST  6'h36
`define FBGT_INST  6'h37
`define BLBC_INST  6'h38
`define BEQ_INST  6'h39
`define BLT_INST  6'h3a
`define BLE_INST  6'h3b
`define BLBS_INST  6'h3c
`define BNE_INST  6'h3d
`define BGE_INST  6'h3e
`define BGT_INST  6'h3f

// INTA (10.xx) opcodes
`define ADDL_INST  7'h00
`define S4ADDL_INST  7'h02
`define SUBL_INST  7'h09
`define S4SUBL_INST  7'h0b
`define CMPBGE_INST  7'h0f
`define S8ADDL_INST  7'h12
`define S8SUBL_INST  7'h1b
`define CMPULT_INST  7'h1d
`define ADDQ_INST  7'h20
`define S4ADDQ_INST  7'h22
`define SUBQ_INST  7'h29
`define S4SUBQ_INST  7'h2b
`define CMPEQ_INST  7'h2d
`define S8ADDQ_INST  7'h32
`define S8SUBQ_INST  7'h3b
`define CMPULE_INST  7'h3d
`define ADDLV_INST  7'h40
`define SUBLV_INST  7'h49
`define CMPLT_INST  7'h4d
`define ADDQV_INST  7'h60
`define SUBQV_INST  7'h69
`define CMPLE_INST  7'h6d

// INTL (11.xx) opcodes
`define AND_INST  7'h00
`define BIC_INST  7'h08
`define CMOVLBS_INST  7'h14
`define CMOVLBC_INST  7'h16
`define BIS_INST  7'h20
`define CMOVEQ_INST  7'h24
`define CMOVNE_INST  7'h26
`define ORNOT_INST  7'h28
`define XOR_INST  7'h40
`define CMOVLT_INST  7'h44
`define CMOVGE_INST  7'h46
`define EQV_INST  7'h48
`define AMASK_INST  7'h61
`define CMOVLE_INST  7'h64
`define CMOVGT_INST  7'h66
`define IMPLVER_INST  7'h6c

// INTS (12.xx) opcodes
`define MSKBL_INST  7'h02
`define EXTBL_INST  7'h06
`define INSBL_INST  7'h0b
`define MSKWL_INST  7'h12
`define EXTWL_INST  7'h16
`define INSWL_INST  7'h1b
`define MSKLL_INST  7'h22
`define EXTLL_INST  7'h26
`define INSLL_INST  7'h2b
`define ZAP_INST  7'h30
`define ZAPNOT_INST  7'h31
`define MSKQL_INST  7'h32
`define SRL_INST  7'h34
`define EXTQL_INST  7'h36
`define SLL_INST  7'h39
`define INSQL_INST  7'h3b
`define SRA_INST  7'h3c
`define MSKWH_INST  7'h52
`define INSWH_INST  7'h57
`define EXTWH_INST  7'h5a
`define MSKLH_INST  7'h62
`define INSLH_INST  7'h67
`define EXTLH_INST  7'h6a
`define MSKQH_INST  7'h72
`define INSQH_INST  7'h77
`define EXTQH_INST  7'h7a

// INTM (13.xx) opcodes
`define MULL_INST  7'h00
`define MULQ_INST  7'h20
`define UMULH_INST  7'h30
`define MULLV_INST  7'h40
`define MULQV_INST  7'h60

// MISC (18.xx) opcodes
`define TRAPB_INST  16'h0000
`define EXCB_INST  16'h0400
`define MB_INST    16'h4000
`define WMB_INST  16'h4400
`define FETCH_INST  16'h8000
`define FETCH_M_INST  16'ha000
`define RPCC_INST  16'hc000
`define RC_INST    16'he000
`define ECB_INST  16'he800
`define RS_INST    16'hf000
`define WH64_INST  16'hf800

// JSR (1a.xx) opcodes
`define JMP_INST  2'h0
`define JSR_INST  2'h1
`define RET_INST  2'h2
`define JSR_CO_INST  2'h3