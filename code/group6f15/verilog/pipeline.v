`timescale 1ns/100ps

module pipeline (
    input         clock,                    // System clock
    input         reset,                    // System reset

    input [3:0]   mem2proc_response,        // Tag from memory about current request
    input [63:0]  mem2proc_data,            // Data coming back from memory
    input [3:0]   mem2proc_tag,              // Tag from memory about current reply

    // process to memory
    output ERROR_CODE   pipeline_status,
    output logic [1:0]  proc2mem_command,    // command sent to memory
    output logic [63:0] proc2mem_addr,      // Address sent to memory
    output logic [63:0] proc2mem_data,      // Data sent to memory

    output PRF_DATA    [`PR_SIZE-1:0] prf_arr,
    output ROB_RRAT           [1:0] rob0_rrat_inst,
    output ROB_RRAT           [1:0] rob1_rrat_inst,
    output logic                    rob0_halt,
    output logic                    rob1_halt
);
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

    // debugging if
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
    logic       [`PR_SIZE-1:0] prf_free_list; 
    logic [1:0] [`PR_BITS-1:0] prf_free_prn;

    // debugging rob
    ROB_DATA [`ROB_SIZE-1:0] rob0_arr;
    ROB_IF             [1:0] rob0_if_inst; 
    logic                    rob0_nuke;

    logic    [`ROB_BITS-1:0] rob0_head_index; 
    logic    [`ROB_BITS-1:0] rob0_n_head_index; 
    logic    [`ROB_BITS-1:0] rob0_tail_index; 
    logic    [`ROB_BITS-1:0] rob0_n_tail_index; 
    logic      [`ROB_BITS:0] rob0_count;
    logic                    rob0_fork_committed; 

    ROB_DATA [`ROB_SIZE-1:0] rob1_arr;
    ROB_IF             [1:0] rob1_if_inst; 
    logic                    rob1_nuke;

    logic    [`ROB_BITS-1:0] rob1_head_index; 
    logic    [`ROB_BITS-1:0] rob1_n_head_index; 
    logic    [`ROB_BITS-1:0] rob1_tail_index; 
    logic    [`ROB_BITS-1:0] rob1_n_tail_index; 
    logic      [`ROB_BITS:0] rob1_count;

    // debugging RS
    logic   [`RS_SIZE-1:0] rs_dispatch_free_list;
    logic     [`RS_BITS:0] rs_count;
    logic   [`RS_SIZE-1:0] rs_awaken_alu_list;
    logic   [`RS_SIZE-1:0] rs_awaken_mult_list;
    logic   [`RS_SIZE-1:0] rs_awaken_branch_list;
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
    logic   [1:0]   [`LB_BITS:0] lb_count;
    logic   [1:0] [`LB_SIZE-1:0] lb_base_addr_ready_list;
    logic   [1:0] [`LB_SIZE-1:0] lb_ready_to_go_list; 
    logic   [1:0] [`LB_SIZE-1:0] lb_ready_cdb_list; 
    logic   [1:0] [`LB_BITS-1:0] lb_base_addr_ready_index; 
    logic   [1:0] [`LB_BITS-1:0] lb_ready_to_go_index; 
    logic   [1:0] [`LB_BITS-1:0] lb_ready_cdb_index;
    logic                  [1:0] lb_request_success;

    logic ALU_0_sent;
    logic ALU_1_sent;
    logic Mult_sent;
    logic Branch_sent;

    
    DISPATCH_ROB [1:0] n_dispatch_rob_inst;
    DISPATCH_RS  [1:0] n_dispatch_rs_inst;
    DISPATCH_LSQ [1:0] n_dispatch_lsq_inst;

    // whatever
    CACHE_COMMAND    proc2Dcache_command_1;   // lazy fix


    // if
    IF_ID [1:0] if_inst;
    logic [1:0] if_predicted_taken;
    logic [1:0] icache_changed_addr;

    // id
    ID_DISPATCH [1:0] id_inst;
    RAT_PRF [1:0]     rat_inst;

    // rs
    logic              rs_full;
    logic              rs_almost_full;
    ISSUE_RS     [3:0] rs_issued_inst;

    // ex
    logic ex_alu0_ready;
    logic ex_alu1_ready;
    logic ex_mult_ready;
    logic ex_branch_ready;

    // dispatch
    DISPATCH_ROB [1:0] dispatch_all_inst;
    DISPATCH_RS  [1:0] dispatch_nonmem_inst;
    DISPATCH_LSQ [1:0] dispatch_mem_inst;
    
    // rob0
    logic [`ADDR_BITS-1:0] rob0_fork_addr;
    logic                  rob0_full;
    logic                  rob0_almost_full;

    // rob1
    logic [`ADDR_BITS-1:0] rob1_fork_addr;
    logic                  rob1_fork_committed;
    logic                  rob1_full;
    logic                  rob1_almost_full;

    // halting pipeline stuff
    logic multi_threaded;
    logic thread0_halted;
    logic thread1_halted;
    logic halt_pipeline;

    // Memory interface/arbiter wires
    

    // pipeline halting logic
    assign halt_pipeline   = multi_threaded ? thread0_halted && thread1_halted : thread0_halted;
    assign pipeline_status = halt_pipeline ? HALTED_ON_HALT : NO_ERROR;

    // memory interface logic
    assign proc2mem_command   = (proc2Dmem_command==BUS_NONE) ? proc2Imem_command : proc2Dmem_command;
    assign proc2mem_addr      = (proc2Dmem_command==BUS_NONE) ? proc2Imem_addr    : proc2Dmem_addr;
    assign Dmem2proc_response = (proc2Dmem_command==BUS_NONE) ? 0                 : mem2proc_response;
    assign Imem2proc_response = (proc2Dmem_command==BUS_NONE) ? mem2proc_response : 0;
    

    icachemem icachemem_0 (
        .clock(clock),
        .reset(reset),

        .changed_addr(icache_changed_addr), 

        .wr1_en(icache_wr_en),
        .wr1_idx(icache_wr_idx),
        .wr1_tag(icache_wr_tag),
        .wr1_data(mem2proc_data),

        .rd1_idx(icache_rd_idx),
        .rd1_tag(icache_rd_tag),

        // outputs
        .valids(icachemem_valids), 
        .data(icachemem_data), 
        .tags(icachemem_tags), 

        .rd1_data(icachemem_data_out),
        .rd1_valid(icachemem_valid_out)
    );

    icache icache_0 (
        .clock(clock),
        .reset(reset),

        .smt_mode(if_smt_mode), 
        .active_thread(if_active_thread), 
        .predicted_taken(if_predicted_taken), 

        .Imem2proc_response(Imem2proc_response),
        .Imem2proc_data(mem2proc_data),
        .Imem2proc_tag(mem2proc_tag),

        .proc2Icache_addr(proc2Icache0_addr),
        .cachemem_data(icachemem_data_out),
        .cachemem_valid(icachemem_valid_out),

        // outputs
        .changed_addr(icache_changed_addr), 

        .proc2Imem_command(proc2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),

        .tag_arr(icache_tag_arr), 
        .addr_arr(icache_addr_arr), 
        .request(icache_prefetch_pc), 
        .curr_thread(icache_prefetch_thread), 
        .head_index(icache_head_index), 
        .tail_index(icache_tail_index), 

        .Icache_data_out(icache0_data),
        .Icache_valid_out(icache0_valid),
        .rd_index(icache_rd_idx),
        .rd_tag(icache_rd_tag),
        .wr_index(icache_wr_idx),
        .wr_tag(icache_wr_tag),
        .wr_en(icache_wr_en)
    );

    if_stage if_stage_0 (
        .clock (clock),
        .reset (reset),
        .Icache0_valid(icache0_valid),
        .Icache0_data(icache0_data),
        .rob0_inst(rob0_if_inst),
        .rob1_inst(rob1_if_inst),
        .stall(dispatch_stall),
        .fork_committed(rob0_fork_committed),
        .fork_addr(rob0_fork_addr),
        .rob0_halt(rob0_halt),
        .rob1_halt(rob1_halt),
        //output
        .predicted_taken(if_predicted_taken), 
        .smt_mode(if_smt_mode),
        .active_thread(if_active_thread),
        .proc2Icache0_addr(proc2Icache0_addr),
        .inst_out(if_inst)
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            multi_threaded <= `SD 0;
            thread0_halted <= `SD 0;
            thread1_halted <= `SD 0;
        end else begin
            if(if_smt_mode)
                multi_threaded <= `SD 1;
            if(rob0_halt)
                thread0_halted <= `SD 1;
            if(rob1_halt)
                thread1_halted <= `SD 1;
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            if_id_inst <= `SD 0;
        end else begin
            if(!dispatch_stall[0])
                if_id_inst[0] <= `SD if_inst[0];
            if(!dispatch_stall[1])
                if_id_inst[1] <= `SD if_inst[1];
        end
    end

    id_stage id_stage_0 (
        .clock(clock),
        .reset(reset), 
        .mispredict_thread_0(rob0_nuke), // high if one of the mispreditc bits for ROB0 is high
        .mispredict_thread_1(rob1_nuke), // high if one of the mispreditc bits for ROB1 is high
        .inst_in(if_id_inst),            // instruction struct from IF stage
        .free_PRN(prf_free_prn),         // 2 free PRNs to rename the 2 instructions
        .RRAT_arr(rrat_arr),             // need this to update RAT in case of mispredict
        .stall_0(dispatch_stall[0]),
        .stall_1(dispatch_stall[1]),
        // outputs
        .RAT_arr(rat_arr), 
        .inst_dispatch(id_inst),         // instruction struct to send to the dispatch module
        .inst_PRF(rat_inst)              // instruction struct to send to the PRF module
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            id_dispatch_inst <= `SD 0;
            rat_prf_inst     <= `SD 0;
        end else begin
            if(!dispatch_stall[0]) begin
                id_dispatch_inst[0] <= `SD id_inst[0];
                rat_prf_inst[0]     <= `SD rat_inst[0];
            end
            if(!dispatch_stall[1]) begin
                id_dispatch_inst[1] <= `SD id_inst[1];
                rat_prf_inst[1]     <= `SD rat_inst[1];
            end 
        end
    end

    prf prf_0 (
        .clock(clock), 
        .reset(reset), 
        .mispredict_thread_0(rob0_nuke),  // high if one of the mispreditc bits for ROB0 is high
        .mispredict_thread_1(rob1_nuke),  // high if one of the mispreditc bits for ROB1 is high
        .free_PRN_in(rrat_committed_prn), // PRNs of instructions that are committed
        .RRAT_free_list(rrat_free_list),  // used to update the PRF's free list in case of mispredict
        .inst_in(rat_prf_inst),           // instruction struct from ID
        .CDB_0(cdb_0),
        .CDB_1(cdb_1), 
        .stall_0(dispatch_stall[0]),
        .stall_1(dispatch_stall[1]),

        // outputs
        .n_PRF_arr(prf_arr),
        .n_PRF_free_list(prf_free_list),
        .free_PRN_out(prf_free_prn),      // 2 free PRNs for the ID stage to rename incoming instructions
        .inst_out(prf_dispatch_inst)      // instruction struct to send to the dispatch module
    );

    dispatch dispatch_0 (
        .clock(clock), 
        .reset(reset),
        .id_disp_0(id_dispatch_inst[0]),
        .id_disp_1(id_dispatch_inst[1]), 
        .mispredict_ROB_0(rob0_nuke), 
        .mispredict_ROB_1(rob1_nuke), 
        .ROB_0_tail(rob0_n_tail_index),
        .ROB_1_tail(rob1_n_tail_index),
        .ROB_0_full(rob0_full),
        .ROB_0_almost_full(rob0_almost_full),
        .ROB_1_full(rob1_full),
        .ROB_1_almost_full(rob1_almost_full),
        .RS_full(rs_full),
        .RS_almost_full(rs_almost_full),
        .LSQ_full(lsq_full),
        .LSQ_almost_full(lsq_almost_full),
        .PRF_out_0(prf_dispatch_inst[0]), 
        .PRF_out_1(prf_dispatch_inst[1]), 

        // outputs
        .disp_ROB_0(dispatch_all_inst[0]), 
        .disp_ROB_1(dispatch_all_inst[1]), 
        .disp_RS_0(dispatch_nonmem_inst[0]), 
        .disp_RS_1(dispatch_nonmem_inst[1]), 
        .disp_LSQ_0(dispatch_mem_inst[0]), 
        .disp_LSQ_1(dispatch_mem_inst[1]),
        .stall_0(dispatch_stall[0]),
        .stall_1(dispatch_stall[1])
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            dispatch_rob_inst <= `SD 0;
            dispatch_rs_inst  <= `SD 0;
            dispatch_lsq_inst <= `SD 0;
        end
        else begin
            dispatch_rob_inst <= `SD dispatch_all_inst;
            dispatch_rs_inst  <= `SD dispatch_nonmem_inst;
            dispatch_lsq_inst <= `SD dispatch_mem_inst;
        end
    end

    rob #(.THREAD_ID(0)) rob_0 (
        .clock(clock), 
        .reset(reset), 
        .CDB_0(cdb_0),
        .CDB_1(cdb_1),
        .disp_ROB_0(dispatch_rob_inst[0]),
        .disp_ROB_1(dispatch_rob_inst[1]),

        // outputs
        .head_index(rob0_head_index), 
        .n_head_index(rob0_n_head_index), 
        .tail_index(rob0_tail_index),
        .n_tail_index(rob0_n_tail_index),
        .count(rob0_count),

        //.ROB_arr(rob0_arr),
        .head(rob0_rrat_inst[0]),
        .head_plus1(rob0_rrat_inst[1]),
        .head_branch(rob0_if_inst[0]),
        .head_plus1_branch(rob0_if_inst[1]),
        .full(rob0_full),
        .almost_full(rob0_almost_full),
        .halt(rob0_halt),
        .nuke(rob0_nuke),
        .fork_committed(rob0_fork_committed),
        .fork_addr(rob0_fork_addr)
    );

    rob #(.THREAD_ID(1)) rob_1 (
        .clock(clock), 
        .reset(reset), 
        .CDB_0(cdb_0),
        .CDB_1(cdb_1),
        .disp_ROB_0(dispatch_rob_inst[0]),
        .disp_ROB_1(dispatch_rob_inst[1]),

        // outputs
        .head_index(rob1_head_index), 
        .n_head_index(rob1_n_head_index), 
        .tail_index(rob1_tail_index),
        .n_tail_index(rob1_n_tail_index),
        .count(rob1_count),

        //.ROB_arr(rob1_arr),
        .head(rob1_rrat_inst[0]),
        .head_plus1(rob1_rrat_inst[1]),
        .head_branch(rob1_if_inst[0]),
        .head_plus1_branch(rob1_if_inst[1]),
        .full(rob1_full),
        .almost_full(rob1_almost_full),
        .halt(rob1_halt),
        .nuke(rob1_nuke),
        .fork_committed(rob1_fork_committed),
        .fork_addr(rob1_fork_addr)
    );

    rs rs_0 (
        .clock(clock), 
        .reset(reset), 
        
        .dispatch_inst0(dispatch_rs_inst[0]),
        .dispatch_inst1(dispatch_rs_inst[1]),
        
        .CDB_0(cdb_0),
        .CDB_1(cdb_1),
        
        .branch_mispredict_0(rob0_nuke),
        .branch_mispredict_1(rob1_nuke),
        
        .ALU0_ready(ex_alu0_ready),
        .ALU1_ready(ex_alu1_ready),
        .Mult_ready(ex_mult_ready),
        .Branch_ready(ex_branch_ready),

        // outputs
        .issue_inst0(rs_issued_inst[0]),
        .issue_inst1(rs_issued_inst[1]),
        .issue_inst2(rs_issued_inst[2]),
        .issue_inst3(rs_issued_inst[3]),

        .full(rs_full),
        .almost_full(rs_almost_full)
        // .count(rs_count),

        // .dispatch_free_list_debug(rs_dispatch_free_list),
        // .awaken_ALU_list_debug(rs_awaken_alu_list),
        // .awaken_Mult_list_debug(rs_awaken_mult_list),
        // .awaken_Branch_list_debug(rs_awaken_branch_list),
        // .RS_array_debug(rs_array)
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            rs_ex_inst <= `SD 0;
        end 
        else begin
            rs_ex_inst <= `SD n_rs_ex_inst;
        end
    end

    always_comb begin
        n_rs_ex_inst = rs_ex_inst;

        if(ex_alu0_ready)
            n_rs_ex_inst[0] = rs_issued_inst[0];
        if(ex_alu1_ready)
            n_rs_ex_inst[1] = rs_issued_inst[1];
        if(ex_branch_ready)
            n_rs_ex_inst[3] = rs_issued_inst[3];
        n_rs_ex_inst[2] = rs_issued_inst[2];

        if(rob0_nuke) begin
            if(!n_rs_ex_inst[0].thread_ID) begin
                n_rs_ex_inst[0] = 0;
            end
            if(!n_rs_ex_inst[1].thread_ID) begin
                n_rs_ex_inst[1] = 0;
            end
            if(!n_rs_ex_inst[2].thread_ID) begin
                n_rs_ex_inst[2] = 0;
            end
            if(!n_rs_ex_inst[3].thread_ID) begin
                n_rs_ex_inst[3] = 0;
            end
        end
        if(rob1_nuke) begin
            if(n_rs_ex_inst[0].thread_ID) begin
                n_rs_ex_inst[0] = 0;
            end
            if(n_rs_ex_inst[1].thread_ID) begin
                n_rs_ex_inst[1] = 0;
            end
            if(n_rs_ex_inst[2].thread_ID) begin
                n_rs_ex_inst[2] = 0;
            end
            if(n_rs_ex_inst[3].thread_ID) begin
                n_rs_ex_inst[3] = 0;
            end
        end
    end

    ex_stage ex_0 (
        .clock(clock),                // system clock
        .reset(reset),                // system reset

        .mispredict_0(rob0_nuke),
        .mispredict_1(rob1_nuke),

        .issue_ALU_0(rs_ex_inst[0]),   // issued instruction to ALU_0 
        .issue_ALU_1(rs_ex_inst[1]),   // issued instruction to ALU_1
        .issue_Mult(rs_ex_inst[2]),     // issued instruction to Mult
        .issue_Branch(rs_ex_inst[3]), // issued instruction to Branch_calc

        .LSQ_in_0(lsq_ex_inst[0]),
        .LSQ_in_1(lsq_ex_inst[1]),

        .ALU_0_sent(ALU_0_sent),
        .ALU_1_sent(ALU_1_sent),
        .Mult_sent(Mult_sent),
        .Branch_sent(Branch_sent),

        .ALU_0_ready(ex_alu0_ready),                // Determines whether a particular Functional Unit is ready or not
        .ALU_1_ready(ex_alu1_ready),
        .Mult_ready(ex_mult_ready),
        .Branch_ready(ex_branch_ready),

        .cdb_0(cdb_0),
        .cdb_1(cdb_1)
    );

    rrat rrat_0 (
        .clock(clock),
        .reset(reset),
        .inst_in({rob1_rrat_inst, rob0_rrat_inst}), // struct for committed instructions from the ROB

        // outputs
        .n_RRAT_arr(rrat_arr),                      // the rrat table (maps ARN to committed PRN)
        .free_PRN_out(rrat_committed_prn),          // PRNs that have been overwritten due to committed instructions
        .n_RRAT_free_list(rrat_free_list)           // a bit vector of PRNs (high if free, low otherwise)
    );

    lsq lsq_0 (
        .clock(clock), 
        .reset(reset), 

        .nuke_thread_0(rob0_nuke),
        .nuke_thread_1(rob1_nuke),

        .cdb_0(cdb_0),
        .cdb_1(cdb_1),

        .ROB_0_head_index(rob0_head_index),
        .ROB_1_head_index(rob1_head_index),

        .disp_LSQ(dispatch_lsq_inst),

        .cache_LSQ_0(dcache_current_response),
        .resolved_read(dcache_resolved_load),
        .request_failed(dcache_request_failed), 

        // debugging sq signals
        // .sq_entries(sq_entries), 
        // .sq_eff_add_ready_list(sq_eff_add_ready_list), 
        // .sq_eff_add_ready_index(sq_eff_add_ready_index),
        // .sq_count(sq_count),
        // .sq_head_index(sq_head_index), 
        // .sq_tail_index(sq_tail_index), 

        // // debugging lb signals
        // .lb_entries(lb_entries), 
        // .lb_free_list(lb_free_list), 
        // .lb_count(lb_count), 
        // .lb_base_addr_ready_list(lb_base_addr_ready_list),
        // .lb_ready_to_go_list(lb_ready_to_go_list), 
        // .lb_ready_cdb_list(lb_ready_cdb_list), 
        // .lb_base_addr_ready_index(lb_base_addr_ready_index), 
        // .lb_ready_to_go_index(lb_ready_to_go_index), 
        // .lb_ready_cdb_index(lb_ready_cdb_index),
        // .lb_request_success(lb_request_success), 

        .LSQ_cache_0(lsq_request),
        .LSQ_output(lsq_ex_inst),

        .full(lsq_full),
        .almost_full(lsq_almost_full)
    );

    dcache dcache_0 (
        .clock(clock),
        .reset(reset),
        .nuke({rob1_nuke, rob0_nuke}),

        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(mem2proc_data),
        .Dmem2proc_tag(mem2proc_tag),

        .lsq_request_1(lsq_request),
                
        .Dcache_data_1(dcachemem_data_out),                 
        .Dcache_valid_1(dcachemem_valid_out),   

        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2mem_data),

        .wr1_req_idx(dcache_wr_req_idx),
        .wr1_req_tag(dcache_wr_req_tag), 
        .wr1_req_data(dcache_wr_req_data),
            
        .wr1_missed_load_idx(dcache_wr_missed_load_idx),                 
        .wr1_missed_load_tag(dcache_wr_missed_load_tag), 

        .wr1_req_en(dcache_wr_req_en),
        .wr1_missed_load_en(dcache_wr_missed_load_en),

        .rd1_idx(dcache_rd_idx),
        .rd1_tag(dcache_rd_tag),
        .proc2Dcache_command_1(proc2Dcache_command_1),

        .LB_response(dcache_resolved_load),
        .current_response(dcache_current_response), 
        .Mem_request_failed(dcache_request_failed)

/*        .Request_buff(dcache_request_buff),   

        .head_index(dcache_head_index),  
        .tail_index(dcache_tail_index),  
        .count(dcache_count)*/
    );

    dcachemem dcachemem_0 (

        .clock(clock),
        .reset(reset),

        .wr1_req_en(dcache_wr_req_en),
        .wr1_missed_load_en(dcache_wr_missed_load_en),

        .wr1_req_idx(dcache_wr_req_idx), 
        .wr1_req_tag(dcache_wr_req_tag),        
        .wr1_req_data(dcache_wr_req_data), 

        .wr1_missed_load_idx(dcache_wr_missed_load_idx),
        .wr1_missed_load_tag(dcache_wr_missed_load_tag), 

        .rd1_idx(dcache_rd_idx),
        .rd1_tag(dcache_rd_tag),

        .wr1_data_from_Mem(mem2proc_data),
        .proc2Dcache_command_1(proc2Dcache_command_1),

        .rd1_data(dcachemem_data_out),
        .rd1_valid(dcachemem_valid_out)
    );
endmodule
