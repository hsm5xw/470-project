`timescale 1ns/100ps

extern void print_header(string str);
extern void print_cycles();
extern void print_stage(string div, int inst, int npc, int valid_inst);
extern void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                      int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
extern void print_membus(int proc2mem_command, int mem2proc_response,
                         int proc2mem_addr_hi, int proc2mem_addr_lo,
                         int proc2mem_data_hi, int proc2mem_data_lo);
extern void print_close();

extern void print_start_cycle();
extern void print_end_cycle();
extern void increment_cycle();

extern void print_rs_header();

extern void print_rob0_entry(int i, int pc, int executed, int instr_type, int prn_dest);
extern void print_rob1_entry(int i, int pc, int executed, int instr_type, int prn_dest);
extern void print_prf_entry(int i, int value, int thread, int valid, int free_entry);
extern void print_rat_enty(int i, int rat0, int rrat0, int rat1, int rrat1);
extern void print_rs_entry(int i, int busy, int rob, int prn_dest, int opa_ready, int opa_value, int opa_prn, 
                    int opb_ready, int opb_value, int opb_prn, int thread);
extern void print_icache_entry(int i, int valid, int tag, int data1, int data0);
extern void print_ex_entry(int valid, int instr_type, int op1, int op2, int rob);
extern void print_rat_prf_entry(int i, int n0, int n1, int n2, int n3);
extern void print_inst_entry(string str, int valid, int pc, int thread_id);
extern void print_prefetch_entry(int i, int tag, int addr);

extern void print_cdb(int FU_result, int prn, int rob, int valid, int mispredict, int branch_taken, int thread_id);
extern void print_cache_line(string s, int n);
extern void print_rs_line(string s, int n);
extern void print_lb0_line(string s, int n);
extern void print_sq0_line(string s, int n);
extern void print_rs_empty_line();
extern void print_rob_line(string s, int n0, int n1);
extern void print_inst_line(string s, int n);
extern void print_inst_empty_line();

extern void print_lb0_status_entry(int i, int n0, int n1, int n2, int n3, int n4, int n5, int n6, int n7);
extern void print_lb0_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN, int address, int base_addr);
extern void print_sq0_entry(int i, int valid, int ready, int value, int base_addr_PRN, int address);
extern void print_lb1_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN, int address, int base_addr);
extern void print_sq1_entry(int i, int valid, int ready, int value, int base_addr_PRN, int address);
extern void print_dcache_entry(int i, int valid, int tag, int data1, int data0);
extern void print_buffer_request_entry(int i, int addr, int response);
extern void print_dcache_line(string s, int n);
extern void print_dcache_empty_line();
extern void print_wb0(int commit, int valid, int pc, int arn, int val1, int val0, int cycle);
extern void print_wb1(int commit, int valid, int pc, int arn, int val1, int val0, int cycle);


module testbench;
  // variables used in the testbench
  int          wb_fileno;
  int          wb_fileno1;
  int          fl_fileno;
  logic        clock;
  logic        reset;

  ERROR_CODE   pipeline_status;
  logic  [1:0] proc2mem_command;
  logic [63:0] proc2mem_addr;
  logic [63:0] proc2mem_data;
  logic  [3:0] mem2proc_response;
  logic [63:0] mem2proc_data;
  logic  [3:0] mem2proc_tag;

  // Memory interface/arbiter wires
  logic [63:0] proc2Imem_addr;
  logic  [1:0] proc2Imem_command;
  logic  [3:0] Imem2proc_response;

  logic [63:0] proc2Dmem_addr;
  logic  [1:0] proc2Dmem_command;
  logic  [3:0] Dmem2proc_response;

  // icache wires
  logic [1:0] [63:0] icachemem_data_out;
  logic        [1:0] icachemem_valid_out;
  logic  [1:0] [4:0] icache_rd_idx;
  logic  [1:0] [7:0] icache_rd_tag;
  logic        [4:0] icache_wr_idx;
  logic        [7:0] icache_wr_tag;
  logic              icache_wr_en;
  logic [1:0] [63:0] icache0_data;
  logic [1:0] [63:0] proc2Icache0_addr;
  logic        [1:0] icache0_valid;

  // debugging prefetch
  logic [1:0] [`NUM_PREFETCH-1:0] [`MEM_TAG_BITS-1:0] icache_tag_arr;
  logic [1:0] [`NUM_PREFETCH-1:0]    [`ADDR_BITS-1:0] icache_addr_arr;
  logic [1:0] [`PREFETCH_BITS:0] icache_head_index;
  logic [1:0] [`PREFETCH_BITS:0] icache_tail_index;
  logic [1:0] [63:0] icache_prefetch_pc;
  logic              icache_prefetch_thread;

  // debugging IF
  logic if_smt_mode;
  logic if_active_thread;

  // debugging icache 
  logic [31:0]        icachemem_valids;
  logic [31:0] [63:0] icachemem_data;
  logic [31:0]  [8:0] icachemem_tags;

  // debugging rat
  RAT_ARR [1:0] rat_arr;
  RAT_ARR [1:0] rrat_arr;
  logic   [1:0] [`PR_SIZE-1:0] rrat_free_list;
  logic   [3:0] [`PR_BITS-1:0] rrat_committed_prn;

  // debugging prf
  PRF_DATA    [`PR_SIZE-1:0] prf_arr;
  logic       [`PR_SIZE-1:0] prf_free_list; 
  logic [1:0] [`PR_BITS-1:0] prf_free_prn;

  // debugging rob
  ROB_RRAT           [1:0] rob0_rrat_inst;
  ROB_DATA [`ROB_SIZE-1:0] rob0_arr;
  ROB_IF             [1:0] rob0_if_inst; 
  logic                    rob0_halt;
  logic                    rob0_nuke;

  logic    [`ROB_BITS-1:0] rob0_head_index; 
  logic    [`ROB_BITS-1:0] rob0_n_head_index; 
  logic    [`ROB_BITS-1:0] rob0_tail_index; 
  logic    [`ROB_BITS-1:0] rob0_n_tail_index; 
  logic      [`ROB_BITS:0] rob0_count;
  logic                    rob0_fork_committed;

  ROB_RRAT           [1:0] rob1_rrat_inst;
  ROB_DATA [`ROB_SIZE-1:0] rob1_arr;
  ROB_IF             [1:0] rob1_if_inst; 
  logic                    rob1_halt;
  logic                    rob1_nuke;

  logic    [`ROB_BITS-1:0] rob1_head_index; 
  logic    [`ROB_BITS-1:0] rob1_n_head_index; 
  logic    [`ROB_BITS-1:0] rob1_tail_index; 
  logic    [`ROB_BITS-1:0] rob1_n_tail_index; 
  logic      [`ROB_BITS:0] rob1_count;

  // debugging RS
  logic   [`RS_SIZE-1:0] rs_dispatch_free_list;
  logic   [`RS_SIZE-1:0] rs_awaken_alu_list;
  logic   [`RS_SIZE-1:0] rs_awaken_mult_list;
  logic   [`RS_SIZE-1:0] rs_awaken_branch_list;
  logic     [`RS_BITS:0] rs_count;
  RS_DATA [`RS_SIZE-1:0] rs_array; 

  // debugging cdb
  CDB cdb_0;
  CDB cdb_1;
  logic [1:0] dispatch_stall;

  // debugging instruction struct
  IF_ID        [1:0] if_id_inst;
  ID_DISPATCH  [1:0] id_dispatch_inst; 
  PRF_DISPATCH [1:0] prf_dispatch_inst;
  DISPATCH_ROB [1:0] dispatch_rob_inst;
  DISPATCH_RS  [1:0] dispatch_rs_inst;
  ISSUE_RS     [3:0] rs_ex_inst, n_rs_ex_inst;
  DISPATCH_LSQ [1:0] dispatch_lsq_inst;
  RAT_PRF      [1:0] rat_prf_inst;

  // debugging dcache
  DCACHE_LSQ   dcache_current_response;
  DCACHE_LSQ   dcache_resolved_load;
  logic        dcache_request_failed;
  logic [`INDEX_BITS-1:0]  dcache_wr_req_idx;                  
  logic [`TAG_BITS-1:0]  dcache_wr_req_tag; 
  logic [63:0] dcache_wr_req_data;
  logic [`INDEX_BITS-1:0]  dcache_wr_missed_load_idx;                  
  logic [`TAG_BITS-1:0]  dcache_wr_missed_load_tag; 
  logic        dcache_wr_req_en; 
  logic        dcache_wr_missed_load_en; 
  logic [`INDEX_BITS-1:0]  dcache_rd_idx;                  
  logic [`TAG_BITS-1:0]  dcache_rd_tag; 

  REQ_BUFF [1:0] [`REQ_BUFF_SIZE-1:0] dcache_request_buff; 
  logic [1:0] [`REQ_BUFF_BITS-1:0]    dcache_head_index;  
  logic [1:0] [`REQ_BUFF_BITS-1:0]    dcache_tail_index;  
  logic [1:0] [`REQ_BUFF_BITS:0]      dcache_count;

  // debugging dcachemem
  logic [31:0] [63:0] dcachemem_data;
  logic [31:0]  [7:0] dcachemem_tags; // lazy fix ********** !!!!! leave it just for now. 
  logic [31:0]        dcachemem_valids;
  logic [63:0]        dcachemem_data_out;               
  logic               dcachemem_valid_out; 

  // debugging lsq
  LSQ_DCACHE      lsq_request;
  FU_RESULT [1:0] lsq_ex_inst;
  logic           lsq_full;
  logic           lsq_almost_full;

  // debugging sq 
  SQ_DATA [1:0] [`SQ_SIZE-1:0] sq_entries; 
  logic   [1:0] [`SQ_SIZE-1:0] sq_eff_add_ready_list; 
  logic   [1:0] [`SQ_BITS-1:0] sq_eff_add_ready_index;
  logic   [1:0] [`SQ_BITS:0]   sq_count;
  logic   [1:0] [`SQ_BITS-1:0] sq_head_index;
  logic   [1:0] [`SQ_BITS-1:0] sq_tail_index;

  // debugging lb 
  LB_DATA [1:0] [`LB_SIZE-1:0] lb_entries; 
  logic   [1:0] [`LB_SIZE-1:0] lb_free_list; 
  logic   [1:0] [`LB_SIZE-1:0] lb_base_addr_ready_list;
  logic   [1:0] [`LB_SIZE-1:0] lb_ready_to_go_list; 
  logic   [1:0] [`LB_SIZE-1:0] lb_ready_cdb_list; 
  logic   [1:0] [`LB_BITS-1:0] lb_base_addr_ready_index; 
  logic   [1:0] [`LB_BITS-1:0] lb_ready_to_go_index; 
  logic   [1:0] [`LB_BITS-1:0] lb_ready_cdb_index;
  logic   [1:0]   [`LB_BITS:0] lb_count;
  logic                  [1:0] lb_request_success;

  // FU stuff
  logic ALU_0_sent;
  logic ALU_1_sent;
  logic Mult_sent;
  logic Branch_sent;

  logic [31:0] clock_count;
  logic [31:0] instr_count, n_instr_count;

  logic [31:0] branch_count;
  logic [31:0] correct_branch_count;


  // Instantiate the Pipeline
  pipeline pipeline_0 (
    // Inputs
    .clock             (clock),
    .reset             (reset),
    .mem2proc_response (mem2proc_response),
    .mem2proc_data     (mem2proc_data),
    .mem2proc_tag      (mem2proc_tag),

    // Outputs
    .pipeline_status   (pipeline_status),
    .proc2mem_command  (proc2mem_command),
    .proc2mem_addr     (proc2mem_addr),
    .proc2mem_data     (proc2mem_data),

    .proc2Imem_addr    (proc2Imem_addr),
    .proc2Imem_command (proc2Imem_command),
    .Imem2proc_response(Imem2proc_response),

    .proc2Dmem_addr(proc2Dmem_addr),
    .proc2Dmem_command(proc2Dmem_command),
    .Dmem2proc_response(Dmem2proc_response),

    .icachemem_data_out     (icachemem_data_out),
    .icachemem_valid_out    (icachemem_valid_out),
    .icache_rd_idx     (icache_rd_idx),
    .icache_rd_tag     (icache_rd_tag),
    .icache_wr_idx     (icache_wr_idx),
    .icache_wr_tag     (icache_wr_tag),
    .icache_wr_en      (icache_wr_en),
    .icache0_data      (icache0_data),
    .proc2Icache0_addr (proc2Icache0_addr),
    .icache0_valid     (icache0_valid),

    // debugging prefetch
    .icache_tag_arr(icache_tag_arr), 
    .icache_addr_arr(icache_addr_arr), 
    .icache_prefetch_pc(icache_prefetch_pc), 
    .icache_prefetch_thread(icache_prefetch_thread), 
    .icache_head_index(icache_head_index), 
    .icache_tail_index(icache_tail_index), 

    // debugging IF
    .if_smt_mode       (if_smt_mode),
    .if_active_thread  (if_active_thread),

    // debugging icache
    .icachemem_valids  (icachemem_valids), 
    .icachemem_data    (icachemem_data), 
    .icachemem_tags    (icachemem_tags),

    // debugging rrat
    .rat_arr           (rat_arr),
    .rrat_arr          (rrat_arr),
    .rrat_free_list    (rrat_free_list), 
    .rrat_committed_prn(rrat_committed_prn), 

    // debugging prf
    .prf_arr           (prf_arr),
    .prf_free_list     (prf_free_list),
    .prf_free_prn      (prf_free_prn), 

    // debugging rob
    .rob0_rrat_inst(rob0_rrat_inst), 
    .rob0_halt(rob0_halt), 
    .rob0_nuke(rob0_nuke), 
    .rob0_if_inst(rob0_if_inst), 
    .rob0_arr(rob0_arr), 

    .rob0_count(rob0_count), 
    .rob0_head_index(rob0_head_index), 
    .rob0_n_head_index(rob0_n_head_index), 
    .rob0_tail_index(rob0_tail_index), 
    .rob0_n_tail_index(rob0_n_tail_index), 
    .rob0_fork_committed(rob0_fork_committed), 

    .rob1_rrat_inst(rob1_rrat_inst), 
    .rob1_halt(rob1_halt), 
    .rob1_nuke(rob1_nuke), 
    .rob1_if_inst(rob1_if_inst), 
    .rob1_arr(rob1_arr), 

    .rob1_count(rob1_count), 
    .rob1_head_index(rob1_head_index), 
    .rob1_n_head_index(rob1_n_head_index), 
    .rob1_tail_index(rob1_tail_index), 
    .rob1_n_tail_index(rob1_n_tail_index), 

    // debugging RS
    .rs_dispatch_free_list(rs_dispatch_free_list), 
    .rs_awaken_alu_list   (rs_awaken_alu_list), 
    .rs_awaken_mult_list  (rs_awaken_mult_list), 
    .rs_awaken_branch_list(rs_awaken_branch_list), 
    .rs_array             (rs_array), 
    .rs_count             (rs_count), 

    // instruction struct
    .if_id_inst        (if_id_inst), 
    .id_dispatch_inst  (id_dispatch_inst), 
    .prf_dispatch_inst (prf_dispatch_inst),
    .dispatch_rob_inst (dispatch_rob_inst), 
    .dispatch_rs_inst  (dispatch_rs_inst),
    .rs_ex_inst        (rs_ex_inst),
    .n_rs_ex_inst      (n_rs_ex_inst),
    .dispatch_lsq_inst (dispatch_lsq_inst),
    .rat_prf_inst      (rat_prf_inst),

    // debugging cdb
    .cdb_0(cdb_0),
    .cdb_1(cdb_1), 
    .dispatch_stall(dispatch_stall), 

    // debugging dcache
    .dcache_current_response(dcache_current_response),
    .dcache_resolved_load(dcache_resolved_load),
    .dcache_request_failed(dcache_request_failed),
    .dcache_wr_req_idx(dcache_wr_req_idx),                  
    .dcache_wr_req_tag(dcache_wr_req_tag), 
    .dcache_wr_req_data(dcache_wr_req_data),
    .dcache_wr_missed_load_idx(dcache_wr_missed_load_idx),                  
    .dcache_wr_missed_load_tag(dcache_wr_missed_load_tag), 
    .dcache_wr_req_en(dcache_wr_req_en), 
    .dcache_wr_missed_load_en(dcache_wr_missed_load_en), 
    .dcache_rd_idx(dcache_rd_idx),
    .dcache_rd_tag(dcache_rd_tag), 

    .dcache_request_buff(dcache_request_buff), 
    .dcache_head_index(dcache_head_index),  
    .dcache_tail_index(dcache_tail_index),  
    .dcache_count(dcache_count),              

    // debugging dcachemem
    .dcachemem_data(dcachemem_data),
    .dcachemem_tags(dcachemem_tags),
    .dcachemem_valids(dcachemem_valids),
    .dcachemem_data_out(dcachemem_data_out),
    .dcachemem_valid_out(dcachemem_valid_out), 

    // debugging lsq
    .lsq_request(lsq_request),
    .lsq_ex_inst(lsq_ex_inst),
    .lsq_full(lsq_full),
    .lsq_almost_full(lsq_almost_full),

    // debugging sq 
    .sq_entries(sq_entries), 
    .sq_eff_add_ready_list(sq_eff_add_ready_list), 
    .sq_eff_add_ready_index(sq_eff_add_ready_index),
    .sq_count(sq_count),
    .sq_head_index(sq_head_index), 
    .sq_tail_index(sq_tail_index), 

    // debugging lb 
    .lb_entries(lb_entries), 
    .lb_free_list(lb_free_list), 
    .lb_base_addr_ready_list(lb_base_addr_ready_list),
    .lb_count(lb_count), 
    .lb_ready_to_go_list(lb_ready_to_go_list), 
    .lb_ready_cdb_list(lb_ready_cdb_list), 
    .lb_base_addr_ready_index(lb_base_addr_ready_index), 
    .lb_ready_to_go_index(lb_ready_to_go_index), 
    .lb_ready_cdb_index(lb_ready_cdb_index),
    .lb_request_success(lb_request_success), 

    // debugging FU stuff
    .ALU_0_sent(ALU_0_sent), 
    .ALU_1_sent(ALU_1_sent), 
    .Mult_sent(Mult_sent),
    .Branch_sent(Branch_sent) 
  );


  // Instantiate the Data Memory
  mem memory (
    // Inputs
    .clk               (clock),
    .proc2mem_command  (proc2mem_command),
    .proc2mem_addr     (proc2mem_addr),
    .proc2mem_data     (proc2mem_data),

    // Outputs
    .mem2proc_response (mem2proc_response),
    .mem2proc_data     (mem2proc_data),
    .mem2proc_tag      (mem2proc_tag)
  );

  // Generate System Clock
  always begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  task print_lb_status_arr;
    input [10:0] n;
    begin
      for(int i=0; i<n; i++)
        print_lb0_status_entry(i, lb_entries[0][i].sq_status[0], lb_entries[0][i].sq_status[1], lb_entries[0][i].sq_status[2], 
                                  lb_entries[0][i].sq_status[3], lb_entries[0][i].sq_status[4], lb_entries[0][i].sq_status[5],
                                  lb_entries[0][i].sq_status[6], lb_entries[0][i].sq_status[7]);
    end
  endtask

  task print_lb_arr;
    input [10:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_lb0_entry(i, lb_free_list[0][i], lb_base_addr_ready_list[0][i], lb_ready_to_go_list[0][i], lb_ready_cdb_list[0][i], 
                        lb_entries[0][i].base_addr_PRN, lb_entries[0][i].effective_address, lb_entries[0][i].request_succeed);
        print_lb1_entry(i, lb_free_list[1][i], lb_base_addr_ready_list[1][i], lb_ready_to_go_list[1][i], lb_ready_cdb_list[1][i], 
                        lb_entries[1][i].base_addr_PRN, lb_entries[1][i].effective_address, lb_entries[1][i].request_succeed);
      end
      print_lb0_line("ready_to_go_index", lb_ready_to_go_index[0]);
      print_lb0_line("ready_cdb_index  ", lb_ready_cdb_index[0]);
      print_lb0_line("req_success      ", lb_request_success[0]);
      print_lb0_line("sq_head_index    ", sq_head_index[0]);
      print_lb0_line("sq_tail_index    ", sq_tail_index[0]);
    end
  endtask

  task print_sq_arr;
    input [10:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_sq0_entry(i, sq_entries[0][i].valid, sq_eff_add_ready_list[0][i], sq_entries[0][i].value_to_store, 
                        sq_entries[0][i].base_addr_PRN, sq_entries[0][i].effective_address);
        print_sq1_entry(i, sq_entries[1][i].valid, sq_eff_add_ready_list[1][i], sq_entries[1][i].value_to_store, 
                        sq_entries[1][i].base_addr_PRN, sq_entries[1][i].effective_address);
      end

      for(int i=0; i<n; i++) begin
        print_sq0_entry(i, sq_entries[0][i].ROB_index, sq_entries[0][i].value_to_store_PRN, sq_entries[0][i].value_to_store_ready, 
                        sq_entries[0][i].address_resolved, sq_entries[0][i].base_addr_ready);
      end
      print_sq0_line("rob0_head_index", rob0_head_index);
      print_sq0_line("count", sq_count[0]);
      print_sq0_line("tail", sq_tail_index[0]);
      print_sq0_line("head", sq_head_index[0]);
    end
  endtask
  
  task print_dcache_arr;
    input [10:0] n;
    begin
      print_dcache_empty_line();
      print_dcache_line("Dcache Mem", 0);
      for(int i=0; i<n; i++)
        print_dcache_entry(i, dcachemem_valids[i], dcachemem_tags[i], dcachemem_data[i][63:32], dcachemem_data[i][31:0]);

      print_dcache_empty_line();
      print_dcache_line("Buffer Request", 0);
      for(int i=0; i<16; i++)
        print_buffer_request_entry(i, dcache_request_buff[0][i].addr, dcache_request_buff[0][i].tag);     

      print_dcache_empty_line();
      print_dcache_line("count", dcache_count[0]);
      print_dcache_line("head", dcache_head_index[0]);
      print_dcache_line("tail", dcache_tail_index[0]);

      print_dcache_empty_line();
      print_dcache_line("lsq_command", lsq_request.command);
      print_dcache_line("lsq_addr", lsq_request.addr);
      print_dcache_line("lsq_index", lsq_request.index);
      
      print_dcache_empty_line();
      print_dcache_line("proc2Dmem_command", proc2Dmem_command);
      print_dcache_line("proc2Dmem_addr", proc2Dmem_addr);
      print_dcache_line("proc2mem_data", proc2mem_data);

      print_dcache_empty_line();
      print_dcache_line("Dmem2proc_response", Dmem2proc_response);
      print_dcache_line("mem2proc_data", mem2proc_data);
      print_dcache_line("mem2proc_tag", mem2proc_tag);

      print_dcache_empty_line();
      print_dcache_line("dcachemem_data_out", dcachemem_data_out);
      print_dcache_line("dcachemem_valid_out", dcachemem_valid_out);

      print_dcache_empty_line();
      print_dcache_line("rob0_nuke", rob0_nuke);
      print_dcache_line("rob1_nuke", rob1_nuke);
      print_dcache_line("response_data", dcache_current_response.data);
      print_dcache_line("response_valid", dcache_current_response.valid);
      print_dcache_line("response_index", dcache_current_response.index);
      print_dcache_line("request_failed", dcache_request_failed);

      print_dcache_empty_line();
      print_dcache_line("dcache_wr_missed_load_en", dcache_wr_missed_load_en);
      print_dcache_line("dcache_wr_req_en", dcache_wr_req_en);
    end
  endtask

  task print_rat_prf_arr;
    input [`AR_BITS:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_rat_prf_entry(i, prf_arr[rrat_arr[0][i]].value[63:32], prf_arr[rrat_arr[0][i]].value[31:0], 
                               prf_arr[rrat_arr[1][i]].value[63:32], prf_arr[rrat_arr[1][i]].value[31:0]);
      end
    end
  endtask

  task print_ex_arr;
    begin
      print_rs_empty_line();
      print_rs_line("mispredict", rob0_if_inst[0].mispredict);
      print_rs_line("mispredict", rob0_if_inst[1].mispredict);
      print_rs_line("mispredict", rob1_if_inst[0].mispredict);
      print_rs_line("mispredict", rob1_if_inst[1].mispredict);
      print_rs_empty_line();
      for(int i=0; i<4; i++)
        print_ex_entry(rs_ex_inst[i].valid, rs_ex_inst[i].instr_type, rs_ex_inst[i].op1_value, rs_ex_inst[i].op2_value, rs_ex_inst[i].ROB_index);
    end
  endtask

  task print_cache;
    begin
      for(int i=0; i<2; i++) begin
        print_cache_line("\nicachemem_data_out   ", icachemem_data_out[i]);
        print_cache_line("icachemem_valid_out  ", icachemem_valid_out[i]);
        print_cache_line("icache_rd_idx   ", icache_rd_idx[i]);
        print_cache_line("icache_rd_tag   ", icache_rd_tag[i]);
        print_cache_line("icache0_data", icache0_data[i]);
        print_cache_line("icache0_valid", icache0_valid[i]);
        print_cache_line("proc2Icache0_addr", proc2Icache0_addr[i]);
      end

      print_cache_line("\nproc2Imem_addr   ", proc2Imem_addr);
      print_cache_line("proc2Imem_index  ", proc2Imem_addr[7:3]);
      print_cache_line("proc2Imem_tag    ", proc2Imem_addr[15:8]);
      print_cache_line("proc2Imem_command", proc2Imem_command);
      print_cache_line("mem2proc_response", mem2proc_response);
      print_cache_line("mem2proc_data    ", mem2proc_data);
      print_cache_line("mem2proc_tag     ", mem2proc_tag);

      print_cache_line("\nprefetch_pc0      ", icache_prefetch_pc[0]);
      print_cache_line("head_index0       ", icache_head_index[0]);
      print_cache_line("tail_index0       ", icache_tail_index[0]);

      print_cache_line("\nprefetch_pc1      ", icache_prefetch_pc[1]);
      print_cache_line("head_index1       ", icache_head_index[1]);
      print_cache_line("tail_index1       ", icache_tail_index[1]);

      print_cache_line("\nprefetch_thread   ", icache_prefetch_thread);
      print_cache_line("smt_mode          ", if_smt_mode);
    end
  endtask

  task print_icache_arr;
    input [31:0] n;
    begin
      for(int i=0; i<n; i++)
        print_icache_entry(i, icachemem_valids[i], icachemem_tags[i], icachemem_data[i][63:32], icachemem_data[i][31:0]);

      for(int i=0; i<8; i++)
        print_prefetch_entry(i, icache_tag_arr[0][i], icache_addr_arr[0][i]);

      for(int i=0; i<8; i++)
        print_prefetch_entry(i, icache_tag_arr[1][i], icache_addr_arr[1][i]);
    end
  endtask

  task print_rob_arr;
    input [`ROB_BITS:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_rob0_entry(i, rob0_arr[i].pc, rob0_arr[i].executed, rob0_arr[i].instr_type, rob0_arr[i].PRN_dest);
        print_rob1_entry(i, rob1_arr[i].pc, rob1_arr[i].executed, rob1_arr[i].instr_type, rob1_arr[i].PRN_dest);
      end
    end
  endtask

  task print_prf_arr;
    input [`PR_BITS:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_prf_entry(i, prf_arr[i].value, prf_arr[i].thread_id, prf_arr[i].valid, prf_free_list[i]);
      end
    end
  endtask

  task print_rat_arr;
    input [`AR_BITS:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_rat_enty(i, rat_arr[0][i], rrat_arr[0][i], rat_arr[1][i], rrat_arr[1][i]);
      end
    end
  endtask

  task print_rs_arr;
    input [`RS_BITS:0] n;
    begin
      for(int i=0; i<n; i++) begin
        print_rs_entry(i, rs_array[i].busy, rs_array[i].ROB_index, rs_array[i].dest_PRF_index, 
                       rs_array[i].op1_ready, rs_array[i].op1_value, rs_array[i].op1_PRF_index, 
                       rs_array[i].op2_ready, rs_array[i].op2_value, rs_array[i].op2_PRF_index,
                       rs_array[i].thread_ID);
      end
    end
  endtask

  task print_inst_arr;
    begin
      print_inst_line("smt_mode ", if_smt_mode);
      print_inst_line("rob0_halt", rob0_halt);
      print_inst_line("rob1_halt", rob1_halt);
      print_inst_line("dispatch_stall0", dispatch_stall[0]);
      print_inst_line("dispatch_stall1", dispatch_stall[1]);
      print_inst_line("rs_count", rs_count);
      print_inst_line("lb0", lb_count[0]);
      print_inst_line("lb1", lb_count[1]);
      print_inst_line("sq0", sq_count[0]);
      print_inst_line("sq1", sq_count[1]);
      print_inst_line("rob0", rob0_count);
      print_inst_line("rob1", rob1_count);
      print_inst_empty_line();
      print_inst_entry("if_id_0", if_id_inst[0].valid_inst, if_id_inst[0].pc, if_id_inst[0].thread_id);
      print_inst_entry("if_id_1", if_id_inst[1].valid_inst, if_id_inst[1].pc, if_id_inst[1].thread_id);
      print_inst_empty_line();
      print_inst_entry("id_dispatch_0", id_dispatch_inst[0].valid, id_dispatch_inst[0].pc, id_dispatch_inst[0].thread_ID);
      print_inst_entry("id_dispatch_1", id_dispatch_inst[1].valid, id_dispatch_inst[1].pc, id_dispatch_inst[1].thread_ID);
      print_inst_empty_line();
      print_inst_entry("dispatch_rs_0", dispatch_rs_inst[0].dispatch, dispatch_rs_inst[0].next_pc-4, dispatch_rs_inst[0].thread_ID);
      print_inst_entry("dispatch_rs_1", dispatch_rs_inst[1].dispatch, dispatch_rs_inst[1].next_pc-4, dispatch_rs_inst[1].thread_ID);
      print_inst_empty_line();
      print_inst_entry("dispatch_rob_0", dispatch_rob_inst[0].dispatch, dispatch_rob_inst[0].dispatch_pc, dispatch_rob_inst[0].thread_ID);
      print_inst_entry("dispatch_rob_1", dispatch_rob_inst[1].dispatch, dispatch_rob_inst[1].dispatch_pc, dispatch_rob_inst[1].thread_ID);
      print_inst_empty_line();
      print_inst_entry("dispatch_lsq_0", dispatch_lsq_inst[0].dispatch, dispatch_rob_inst[0].dispatch_pc, dispatch_lsq_inst[0].base_addr_PRN);
      print_inst_entry("dispatch_lsq_1", dispatch_lsq_inst[1].dispatch, dispatch_rob_inst[1].dispatch_pc, dispatch_lsq_inst[1].base_addr_PRN);
      print_inst_empty_line();

      print_inst_empty_line();
    end
  endtask;

  task print_cdbs;
    begin
      print_rs_empty_line();
      print_cdb(cdb_0.FU_result, cdb_0.PRN, cdb_0.ROB_index, cdb_0.valid, cdb_0.mispredict, cdb_0.branch_actually_taken, cdb_0.thread_ID);
      print_cdb(cdb_1.FU_result, cdb_1.PRN, cdb_1.ROB_index, cdb_1.valid, cdb_1.mispredict, cdb_1.branch_actually_taken, cdb_1.thread_ID);
    end
  endtask

  task print_rob_stuff;
    begin
      print_rob_line("count       ", rob0_count, rob1_count);
      print_rob_line("head_index  ", rob0_head_index, rob1_head_index);
      print_rob_line("n_head_index", rob0_n_head_index, rob1_n_head_index);
      print_rob_line("tail_index  ", rob0_tail_index, rob1_tail_index);
      print_rob_line("n_tail_index", rob0_n_tail_index, rob1_n_tail_index);
    end
  endtask

  // Show contents of a range of Unified Memory, in both hex and decimal
  task show_mem_with_decimal;
    input [31:0] start_addr;
    input [31:0] end_addr;
    int showing_data;
    begin
      $display("@@@");
      showing_data=0;
      for(int k=start_addr;k<=end_addr; k=k+1)
        if (memory.unified_memory[k] != 0) begin
          $display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], memory.unified_memory[k]);
          showing_data=1;
        end else if(showing_data!=0) begin
          $display("@@@");
          showing_data=0;
        end
      $display("@@@");
    end
  endtask  // task show_mem_with_decimal

  // Task to display # of elapsed clock edges
  task show_clk_count;
    real cpi;
    begin
      cpi = (clock_count + 1.0) / instr_count;
      $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
      clock_count+1, instr_count, cpi);
      $display("@@  %4.2f ns total time to execute\n@@",
      clock_count*`VIRTUAL_CLOCK_PERIOD);
    end
  endtask  // task show_clk_count 

   task show_branch_stuff;
     real branch;

     begin
      branch = (correct_branch_count + 0.0) / branch_count;
      $display("@@ Prediction rate: correct: %f, total: %f, ratio: %f \n", correct_branch_count,branch_count,branch);
     end 
   endtask
    
  initial begin
    clock = 1'b0;
    reset = 1'b0;

    // Pulse the reset signal
    $display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
    reset = 1'b1;
    @(posedge clock);
    @(posedge clock);

    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
    @(posedge clock);
    `SD;
    // This reset is at an odd time to avoid the pos & neg clock edges

    reset = 1'b0;
    $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

    wb_fileno  = $fopen("writeback.out");
    wb_fileno1 = $fopen("writeback1.out");
    fl_fileno  = $fopen("freelist.out");

    print_header("@@@@@@@@@@@ LET THE FUN BEGIN @@@@@@@@@@@@@@\n");
        
    @(negedge clock);
    repeat(10000) @(negedge clock);
    $fclose(wb_fileno);
    $fclose(wb_fileno1);
    $fclose(fl_fileno);
    $finish;
  end 

  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock or posedge reset) begin
    if(reset) begin
      clock_count <= `SD 0;
      instr_count <= `SD 0;

    end else begin
      clock_count <= `SD (clock_count + 1);
      instr_count <= `SD n_instr_count;
    end
  end 

  always_comb begin
    n_instr_count = instr_count;
    n_instr_count = rob0_rrat_inst[0].committed ? n_instr_count + 1 : n_instr_count;
    n_instr_count = rob0_rrat_inst[1].committed ? n_instr_count + 1 : n_instr_count;
    n_instr_count = rob1_rrat_inst[0].committed ? n_instr_count + 1 : n_instr_count;
    n_instr_count = rob1_rrat_inst[1].committed ? n_instr_count + 1 : n_instr_count;
    n_instr_count = rob0_halt                   ? n_instr_count - 1 : n_instr_count;
    n_instr_count = rob1_halt                   ? n_instr_count - 1 : n_instr_count;
  end

  // branch prediction rate stuff
  always @(posedge clock or posedge reset) begin
    if(reset) begin
      branch_count <= `SD 0;
      correct_branch_count <= `SD 0;
    
    end else begin

      if(rob0_if_inst[0].is_branch & rob0_if_inst[1].is_branch) begin
        branch_count <= `SD (branch_count + 2);
      end else if(rob0_if_inst[0].is_branch ^ rob0_if_inst[1].is_branch) begin
        branch_count <= `SD (branch_count + 1);
      end else begin
        branch_count <= `SD branch_count;
      end

      if((rob0_if_inst[0].is_branch & !rob0_if_inst[0].mispredict) & (rob0_if_inst[1].is_branch & !rob0_if_inst[1].mispredict)) begin
        correct_branch_count <= `SD (correct_branch_count + 2);
      end else if((rob0_if_inst[0].is_branch & !rob0_if_inst[0].mispredict) ^ (rob0_if_inst[1].is_branch & !rob0_if_inst[1].mispredict)) begin
        correct_branch_count <= `SD (correct_branch_count + 1);
      end else begin
        correct_branch_count <= `SD correct_branch_count;
      end
    end
  end  

  always @(negedge clock) begin
    if(reset)
      $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
               $realtime);
    else begin
      `SD;
      `SD;
      
      print_start_cycle();
      print_cycles();

      print_rs_header();

      print_stage("if_id_0", if_id_inst[0].instr, if_id_inst[0].next_pc, {31'b0,if_id_inst[0].valid_inst});
      print_stage("if_id_1", if_id_inst[1].instr, if_id_inst[1].next_pc, {31'b0,if_id_inst[1].valid_inst});
      print_stage("id_dispatch_0", id_dispatch_inst[0].instr, id_dispatch_inst[0].next_pc, {31'b0,id_dispatch_inst[0].valid});
      print_stage("id_dispatch_1", id_dispatch_inst[1].instr, id_dispatch_inst[1].next_pc, {31'b0,id_dispatch_inst[1].valid});

      print_rob_arr(`ROB_SIZE);
      print_prf_arr(`PR_SIZE);
      print_rat_arr(`AR_SIZE);
      print_rs_arr(`RS_SIZE);
      print_icache_arr(32);
      print_rat_prf_arr(`AR_SIZE);
      print_inst_arr();
      print_ex_arr();
      print_dcache_arr(32);
      print_sq_arr(`SQ_SIZE);
      print_lb_arr(`LB_SIZE);
      print_lb_status_arr(8);

      print_cdbs();
      print_cache();
      print_rob_stuff();

      print_end_cycle();
      increment_cycle();

      // print the writeback information for thread 0 to writeback.out
      for(int i=0; i<2; i++) begin
        if(rob0_rrat_inst[i].committed && !rob0_fork_committed) begin
          if(rob0_rrat_inst[i].PRN_dest!=`PR_SIZE-1)
            $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x", rob0_rrat_inst[i].pc, rob0_rrat_inst[i].ARN_dest, prf_arr[rob0_rrat_inst[i].PRN_dest].value);
          else
            $fdisplay(wb_fileno, "PC=%x, ---", rob0_rrat_inst[i].pc);
        end
      end

      // print the writeback information for thread 0 to writeback.out
      for(int i=0; i<2; i++) begin
        if(rob1_rrat_inst[i].committed) begin
          if(rob1_rrat_inst[i].PRN_dest!=`PR_SIZE-1)
            $fdisplay(wb_fileno1, "PC=%x, REG[%d]=%x", rob1_rrat_inst[i].pc, rob1_rrat_inst[i].ARN_dest, prf_arr[rob1_rrat_inst[i].PRN_dest].value);
        else
          $fdisplay(wb_fileno1, "PC=%x, ---", rob1_rrat_inst[i].pc);
        end
      end

      // print free_list to fl_fileno
      $fdisplay(fl_fileno, "\ncycle: %4d\n", clock_count);

      $fdisplay(fl_fileno, "nuke0: %b",   rob0_nuke);     
      $fdisplay(fl_fileno, "nuke1: %b\n", rob1_nuke);

      $fdisplay(fl_fileno, "committed_prn: %d",   rrat_committed_prn[0]);
      $fdisplay(fl_fileno, "committed_prn: %d",   rrat_committed_prn[1]);
      $fdisplay(fl_fileno, "committed_prn: %d",   rrat_committed_prn[2]);
      $fdisplay(fl_fileno, "committed_prn: %d\n", rrat_committed_prn[3]);

      $fdisplay(fl_fileno, "free_prn: %d",   prf_free_prn[0]);
      $fdisplay(fl_fileno, "free_prn: %d\n",   prf_free_prn[1]);
      
      $fdisplay(fl_fileno, "rrat[4]  %b", rrat_free_list[0][127:96]);
      $fdisplay(fl_fileno, " prf[4]  %b\n",   prf_free_list[127:96]);

      $fdisplay(fl_fileno, "rrat[3]  %b", rrat_free_list[0][95:64]);
      $fdisplay(fl_fileno, " prf[3]  %b\n",   prf_free_list[95:64]);

      $fdisplay(fl_fileno, "rrat[2]  %b", rrat_free_list[0][63:32]);
      $fdisplay(fl_fileno, " prf[2]  %b\n",   prf_free_list[63:32]);

      $fdisplay(fl_fileno, "rrat[1]  %b",  rrat_free_list[0][31:0]);
      $fdisplay(fl_fileno, " prf[1]  %b\n",    prf_free_list[31:0]);
      
      // print the writeback information to writeback.out
      print_wb0(rob0_rrat_inst[0].committed, rob0_rrat_inst[0].PRN_dest!=`PR_SIZE-1, rob0_rrat_inst[0].pc, rob0_rrat_inst[0].ARN_dest, 
                prf_arr[rob0_rrat_inst[0].PRN_dest].value[63:32], prf_arr[rob0_rrat_inst[0].PRN_dest].value[31:0], clock_count);
      print_wb0(rob0_rrat_inst[1].committed, rob0_rrat_inst[1].PRN_dest!=`PR_SIZE-1, rob0_rrat_inst[1].pc, rob0_rrat_inst[1].ARN_dest, 
                prf_arr[rob0_rrat_inst[1].PRN_dest].value[63:32], prf_arr[rob0_rrat_inst[1].PRN_dest].value[31:0], clock_count);

      print_wb1(rob1_rrat_inst[0].committed, rob1_rrat_inst[0].PRN_dest!=`PR_SIZE-1, rob1_rrat_inst[0].pc, rob1_rrat_inst[0].ARN_dest, 
                prf_arr[rob1_rrat_inst[0].PRN_dest].value[63:32], prf_arr[rob1_rrat_inst[0].PRN_dest].value[31:0], clock_count);
      print_wb1(rob1_rrat_inst[1].committed, rob1_rrat_inst[1].PRN_dest!=`PR_SIZE-1, rob1_rrat_inst[1].pc, rob1_rrat_inst[1].ARN_dest, 
                prf_arr[rob1_rrat_inst[1].PRN_dest].value[63:32], prf_arr[rob1_rrat_inst[1].PRN_dest].value[31:0], clock_count);

      if(pipeline_status != NO_ERROR) begin
        $display("@@@ Unified Memory contents hex on left, decimal on right: ");
        show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
        // 8Bytes per line, 16kB total

        $display("@@  %t : System halted\n@@", $realtime);

        case(pipeline_status)
          HALTED_ON_MEMORY_ERROR:  
              $display("@@@ System halted on memory error");
          HALTED_ON_HALT:          
              $display("@@@ System halted on HALT instruction");
          HALTED_ON_ILLEGAL:
              $display("@@@ System halted on illegal instruction");
          default: 
              $display("@@@ System halted on unknown error code %x",
                       pipeline_status);
        endcase
        $display("@@@\n@@");
        show_clk_count();
        show_branch_stuff();
        print_close(); // close the pipe_print output file
        $fclose(wb_fileno);
        $fclose(wb_fileno1);
        $fclose(fl_fileno);
        #100 $finish;
      end

    end
  end 
endmodule
