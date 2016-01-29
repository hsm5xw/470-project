`timescale 1ns/100ps

module lsq (
  input clock,
  input reset,

  input nuke_thread_0,
  input nuke_thread_1,

  input CDB cdb_0,
  input CDB cdb_1,

  input [`ROB_BITS-1:0] ROB_0_head_index,
  input [`ROB_BITS-1:0] ROB_1_head_index,

  input DISPATCH_LSQ [1:0] disp_LSQ,
  
  input            request_failed,
  input DCACHE_LSQ cache_LSQ_0,
  input DCACHE_LSQ resolved_read,

  output LSQ_DCACHE LSQ_cache_0,
  output FU_RESULT [1:0] LSQ_output,

  output logic full,
  output logic almost_full
);

  LDL_STC_REG sp_reg_0, sp_reg_1, n_sp_reg_0, n_sp_reg_1;

    // debugging sq signals
  SQ_DATA [1:0] [`SQ_SIZE-1:0] sq_entries; 
  logic   [1:0] [`SQ_SIZE-1:0] sq_eff_add_ready_list; 
  logic   [1:0] [`SQ_BITS-1:0] sq_eff_add_ready_index;
  logic   [1:0] [`SQ_BITS:0]   sq_count;
  logic   [1:0] [`SQ_BITS-1:0] sq_head_index; 
  logic   [1:0] [`SQ_BITS-1:0] sq_tail_index;

  // debugging lb signals
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

  DISPATCH_LSQ [1:0] to_LB_0;
  DISPATCH_LSQ [1:0] to_LB_1;
  DISPATCH_LSQ [1:0] to_SQ_0;
  DISPATCH_LSQ [1:0] to_SQ_1;

  DCACHE_LSQ [1:0] cache_LB;
  DCACHE_LSQ [1:0] res_read_LB;

  logic [1:0][63:0] store_data;
  logic [1:0][63:0] store_data_address;

  SQ_ADDER_DATA   [1:0] resolved_store;
  SQ_RETIRED_DATA [1:0] committed_store;
  SQ_ALL_DATA     [1:0] SQ_all;

  logic               [1:0] store_request;
  logic               [1:0] SQ_request_success;

  logic [1:0][`ROB_BITS-1:0] store_ROB_index;
  logic  [1:0][`PR_BITS-1:0] store_PRN_dest;

  logic       [1:0] [63:0] load_data_address;
  logic [1:0] [`LB_BITS-1:0] load_data_index;
  
  logic [1:0] load_req_is_ldl_mem;
  logic [1:0] SQ_full, SQ_almost_full;
  logic [1:0] LB_full, LB_almost_full;

  logic  [1:0] allowed_to_store, store_result;
  logic  [1:0] load_request, store_is_stc_mem, LB_output_ldl_mem, store_success;
  logic [1:0] [63:0] LB_output_addr;

  logic mispredicted_load;
  logic priority_thread, n_priority_thread;
  logic [1:0] load_priority, store_priority, valid_load, valid_store;


  FU_RESULT [1:0] LB_output;

  LSQ_DCACHE n_LSQ_cache_0;

  assign full        = SQ_full[0] || SQ_full[1] || LB_full[0] || LB_full[1];

  assign almost_full = SQ_almost_full[0] || SQ_almost_full[1] || 
                       LB_almost_full[0] || LB_almost_full[1];


  // sort the cache_LSQ structs based on thread_ID
  assign cache_LB[0] = cache_LSQ_0.thread_ID ? 0 : cache_LSQ_0;
  assign cache_LB[1] = cache_LSQ_0.thread_ID ? cache_LSQ_0 : 0;

  assign res_read_LB[0] = resolved_read.thread_ID ? 0 : resolved_read;
  assign res_read_LB[1] = resolved_read.thread_ID ? resolved_read : 0;  

  // no need to check for mispredicted stores since LSQ_cache_0.command==COMMAND_STORE iff stq is at the head of the ROB
  assign mispredicted_load = (LSQ_cache_0.command==COMMAND_LOAD && !LSQ_cache_0.thread_ID && nuke_thread_0) || 
                             (LSQ_cache_0.command==COMMAND_LOAD && LSQ_cache_0.thread_ID && nuke_thread_1);

  // 2 SQ's and 1 LB?

  // Special registers will also be found here, ignore until after ms3?

  // Logic for giving which modules (sq_0,1 or lb) the ability to make
  //   a request to memory
  always_comb begin
    n_LSQ_cache_0       = LSQ_cache_0;
    SQ_request_success = 0;
    lb_request_success = 0;
    n_sp_reg_0 = sp_reg_0;
    n_sp_reg_1 = sp_reg_1;


    valid_load[0]  = load_request[0] && !nuke_thread_0;
    valid_load[1]  = load_request[1] && !nuke_thread_1;

    valid_store[0] = store_request[0] && !nuke_thread_0 && (!LB_output[0].FU_done || !LB_output[1].FU_done);
    valid_store[1] = store_request[1] && !nuke_thread_1 && (!LB_output[0].FU_done || !LB_output[1].FU_done);

    load_priority  = 0;
    store_priority = 0;

    if(priority_thread) begin

      n_priority_thread = 0;
      load_priority[1]  = valid_load[1];
      store_priority[1] = valid_store[1];
      
      if(!valid_load[1] && !valid_store[1]) begin
        load_priority[0]  = valid_load[0];
        store_priority[0] = valid_store[0];
        n_priority_thread = 1;
      end
    end else begin

      n_priority_thread = 1;
      load_priority[0]  = valid_load[0];
      store_priority[0] = valid_store[0];
      
      if(!valid_load[0] && !valid_store[0]) begin
        load_priority[1]  = valid_load[1];
        store_priority[1] = valid_store[1];
        n_priority_thread = 0;
      end

    end

    if(!request_failed || cache_LSQ_0.valid || LSQ_cache_0.command==COMMAND_NONE || mispredicted_load) begin
      
      if(load_priority[0]) begin
        n_LSQ_cache_0.command = COMMAND_LOAD;
        n_LSQ_cache_0.index   = load_data_index[0];
        n_LSQ_cache_0.addr    = load_data_address[0];
        n_LSQ_cache_0.data    = 0;
        n_LSQ_cache_0.thread_ID = 0;

        lb_request_success[0] = 1;

        if(load_req_is_ldl_mem[0]) begin
          n_sp_reg_0.addr   = load_data_address[0];
          n_sp_reg_0.loaded = 1;
        end

      end // load_request[0]
      else if(store_priority[0]) begin

        if(store_is_stc_mem[0]) begin
          if((sp_reg_0.addr == store_data_address[0]) && sp_reg_0.loaded) begin // the sp register hasn't been modified since the load
            n_LSQ_cache_0.command = COMMAND_STORE;
            n_LSQ_cache_0.index   = 0;
            n_LSQ_cache_0.addr    = store_data_address[0];
            n_LSQ_cache_0.data    = store_data[0];
            n_LSQ_cache_0.thread_ID = 0;
          end 
          else begin // if the 
            n_LSQ_cache_0 = 0;
          end
        end // stc mem
        else begin
          n_LSQ_cache_0.command = COMMAND_STORE;
          n_LSQ_cache_0.index   = 0;
          n_LSQ_cache_0.addr    = store_data_address[0];
          n_LSQ_cache_0.data    = store_data[0];
          n_LSQ_cache_0.thread_ID = 0;
        end // not stc mem

        SQ_request_success[0] = 1;
      end // store_request[0]
      
      else if(load_priority[1]) begin
        n_LSQ_cache_0.command = COMMAND_LOAD;
        n_LSQ_cache_0.index   = load_data_index[1];
        n_LSQ_cache_0.addr    = load_data_address[1];
        n_LSQ_cache_0.data    = 0;
        n_LSQ_cache_0.thread_ID = 1;

        lb_request_success[1] = 1;

        if(load_req_is_ldl_mem[1]) begin
          n_sp_reg_1.addr   = load_data_address[1];
          n_sp_reg_1.loaded = 1;
        end

      end // load_request[1]
      else if(store_priority[1]) begin

        if(store_is_stc_mem[1]) begin
          if((sp_reg_1.addr == store_data_address[1]) && sp_reg_1.loaded) begin
            n_LSQ_cache_0.command = COMMAND_STORE;
            n_LSQ_cache_0.index   = 0;
            n_LSQ_cache_0.addr    = store_data_address[1];
            n_LSQ_cache_0.data    = store_data[1];
            n_LSQ_cache_0.thread_ID = 1;
          end 
          else begin // memory address was modified since the load
            n_LSQ_cache_0 = 0;
          end
        end
        else begin
          n_LSQ_cache_0.command = COMMAND_STORE;
          n_LSQ_cache_0.index   = 0;
          n_LSQ_cache_0.addr    = store_data_address[1];
          n_LSQ_cache_0.data    = store_data[1];
          n_LSQ_cache_0.thread_ID = 1;
        end
        SQ_request_success[1] = 1;
      end // store_request[1]
      else begin
        n_LSQ_cache_0       = 0;
      end
    end

    LSQ_output = 0;

    if(LB_output[0].FU_done) begin
      LSQ_output[0] = LB_output[0];
    end
    if(LB_output[1].FU_done) begin
      LSQ_output[1] = LB_output[1];
    end

    allowed_to_store[0] = (store_data_address[0] == sp_reg_0.addr) && sp_reg_0.loaded;
    
    if(allowed_to_store[0] && SQ_request_success[0]) begin
      n_sp_reg_0.loaded = 0;
      n_sp_reg_0.addr   = 0;

      if(sp_reg_1.addr == sp_reg_0.addr)
        n_sp_reg_1 = 0;
    end

    store_result[0]     = allowed_to_store[0];

    allowed_to_store[1] = (store_data_address[1] == sp_reg_1.addr) && sp_reg_1.loaded;
    
    if(allowed_to_store[1] && SQ_request_success[1]) begin
      n_sp_reg_1.loaded = 0;
      n_sp_reg_1.addr   = 0;

      if(sp_reg_1.addr == sp_reg_0.addr)
        n_sp_reg_0 = 0;
    end

    store_result[1]     = allowed_to_store[1];

    if(!LB_output[0].FU_done) begin
      if(SQ_request_success[0]) begin
        LSQ_output[0].FU_done   = 1;
        LSQ_output[0].result    = store_result[0];
        LSQ_output[0].ROB_index = store_ROB_index[0];
        LSQ_output[0].PRN_index = store_PRN_dest[0];  // will need to change for store conditional
        LSQ_output[0].thread_ID = 0;

/*        n_sp_reg_0.loaded = 0;
        if(sp_reg_1.addr == store_data_address[0]) begin
          n_sp_reg_1.loaded = 0;
        end */
      end
      else if(SQ_request_success[1]) begin
        LSQ_output[0].FU_done   = 1;
        LSQ_output[0].result    = store_result[1];  // this will need to be changed for store conditionally stuff
        LSQ_output[0].ROB_index = store_ROB_index[1];
        LSQ_output[0].PRN_index = store_PRN_dest[1];
        LSQ_output[0].thread_ID = 1;

/*        n_sp_reg_1.loaded = 0;
        if(sp_reg_0.addr == store_data_address[1]) begin
          n_sp_reg_0.loaded = 0;
        end */
      end
    end // LB_output[0] wasn't valid, so can use LSQ_output[0]
    else if(!LB_output[1].FU_done) begin
      if(SQ_request_success[0]) begin
        LSQ_output[1].FU_done   = 1;
        LSQ_output[1].result    = store_result[0];  // this will need to be changed for store conditionally stuff
        LSQ_output[1].ROB_index = store_ROB_index[0];
        LSQ_output[1].PRN_index = store_PRN_dest[0];
        LSQ_output[1].thread_ID = 0;

/*        n_sp_reg_0.loaded = 0;
        if(sp_reg_1.addr == store_data_address[0]) begin
          n_sp_reg_1.loaded = 0;
        end*/
      end
      else if(SQ_request_success[1]) begin
        LSQ_output[1].FU_done   = 1;
        LSQ_output[1].result    = store_result[1];  // this will need to be changed for store conditionally stuff
        LSQ_output[1].ROB_index = store_ROB_index[1];
        LSQ_output[1].PRN_index = store_PRN_dest[1];
        LSQ_output[1].thread_ID = 1;

/*        n_sp_reg_1.loaded = 0;
        if(sp_reg_0.addr == store_data_address[1]) begin
          n_sp_reg_0.loaded = 0;
        end*/
      end
    end // otherwise if LB_output[1] wasn't valid, can use LSQ_output[1]

    if(nuke_thread_0)
      n_sp_reg_0 = 0;
    if(nuke_thread_1)
      n_sp_reg_1 = 0;
  end

/*
  // Determining what to broadcast (assumes if theres 2 loads the store(s) will stall, makes logic easier)
  always_comb begin

    MOVED TO ABOVE COMB BLOCK

  end
*/
  // always_ff block for output to cache

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
      if(reset) begin
          priority_thread   <= `SD 0;
          LSQ_cache_0       <= `SD 0;  // command COMMAND_NONE is enumerated as 0, this effectively
                                       //   says the request isn't a valid one.
      end else begin
          priority_thread   <= `SD n_priority_thread;
          LSQ_cache_0       <= `SD n_LSQ_cache_0;
      end
  end

  // always_ff block for special registers

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
      if(reset) begin
          sp_reg_0 <= `SD 0;
          sp_reg_1 <= `SD 0;  // command COMMAND_NONE is enumerated as 0, this effectively
                                       //   says the request isn't a valid one.
      end 
      else begin
          sp_reg_0 <= `SD n_sp_reg_0;
          sp_reg_1 <= `SD n_sp_reg_1;
      end
  end  

  // Instantiating sq_0 and lb_0
  sq #(.THREAD_ID(0)) sq_0 (
    .clock(clock),
    .reset(reset),
    
    .cdb0(cdb_0),
    .cdb1(cdb_1),

    .ROB_head_index(ROB_0_head_index),
    .D_cache_success(SQ_request_success[0]),

    .mispredict(nuke_thread_0),
    .inst_in(disp_LSQ),
    
    .resolved_store(resolved_store[0]),
    .committed_store(committed_store[0]),
    .sq_all(SQ_all[0]),

    .full(SQ_full[0]),
    .almost_full(SQ_almost_full[0]),

    .store_success(store_success[0]),

    // debugging sq signals
    // .sq_entries(sq_entries[0]), 
    // .eff_add_ready_list(sq_eff_add_ready_list[0]), 
    // .eff_add_ready_index(sq_eff_add_ready_index[0]),
    // .count(sq_count[0]), 
    
    .store_data(store_data[0]),
    .store_request(store_request[0]),
    .ROB_index(store_ROB_index[0]),
    .PRN_dest(store_PRN_dest[0]),
    .is_stc_mem(store_is_stc_mem[0]),
    .proc2Dcache_addr(store_data_address[0]),
    .head_index(sq_head_index[0]),
    .tail_index(sq_tail_index[0])
  );

  lb #(.THREAD_ID(0)) lb_0 (
    .clock(clock),
    .reset(reset),
    
    .Dcache_valid(cache_LB[0].valid),
    .Dcache_data(cache_LB[0].data),
    .Dcache_index(cache_LB[0].index),
    .Dcache_req_successful(lb_request_success[0]),

    .Memory_valid(res_read_LB[0].valid),
    .Memory_data(res_read_LB[0].data),
    .Memory_index(res_read_LB[0].index),

    .CDB_0(cdb_0),
    .CDB_1(cdb_1),

    .resolved_store(resolved_store[0]),
    .all_stores(SQ_all[0]),
    .sq_head_index(sq_head_index[0]),
    .sq_tail_index(sq_tail_index[0]),
    .committed_store(committed_store[0]),

    .inst_in(disp_LSQ),
    .mispredict(nuke_thread_0),

    // debugging lb signals
    // .entries(lb_entries[0]), 
    // .free_list(lb_free_list[0]), 
    // .base_addr_ready_list(lb_base_addr_ready_list[0]),
    // .ready_to_go_list(lb_ready_to_go_list[0]), 
    // .ready_cdb_list(lb_ready_cdb_list[0]), 
    // .base_addr_ready_index(lb_base_addr_ready_index[0]), 
    // .ready_to_go_index(lb_ready_to_go_index[0]), 
    // .ready_cdb_index(lb_ready_cdb_index[0]),// debugging lb signals

    .load_req_is_ldl_mem(load_req_is_ldl_mem[0]),
    .almost_full(LB_almost_full[0]),
    .full(LB_full[0]),

    .valid_request(load_request[0]),
    .proc2Dcache_index(load_data_index[0]),
    .proc2Dcache_addr(load_data_address[0]),

    .output_to_CDB(LB_output[0]),
    .output_ldl_mem(LB_output_ldl_mem[0]),
    .output_addr(LB_output_addr[0]),
    .count(lb_count[0])
  );

  // Instantiating sq_1 and lb_1
  sq #(.THREAD_ID(1)) sq_1 (
    .clock(clock),
    .reset(reset),
    
    .cdb0(cdb_0),
    .cdb1(cdb_1),

    .ROB_head_index(ROB_1_head_index),
    .D_cache_success(SQ_request_success[1]),

    .mispredict(nuke_thread_1),
    .inst_in(disp_LSQ),
    
    .resolved_store(resolved_store[1]),
    .committed_store(committed_store[1]),
    .sq_all(SQ_all[1]),

    .full(SQ_full[1]),
    .almost_full(SQ_almost_full[1]),

    .store_success(store_success[1]),

    // debugging sq signals
    // .sq_entries(sq_entries[1]), 
    // .eff_add_ready_list(sq_eff_add_ready_list[1]), 
    // .eff_add_ready_index(sq_eff_add_ready_index[1]),
    // .count(sq_count[1]), 

    .store_data(store_data[1]),
    .store_request(store_request[1]),
    .ROB_index(store_ROB_index[1]),
    .PRN_dest(store_PRN_dest[1]),
    .is_stc_mem(store_is_stc_mem[1]),
    .proc2Dcache_addr(store_data_address[1]),
    .head_index(sq_head_index[1]),
    .tail_index(sq_tail_index[1])
  );

  lb #(.THREAD_ID(1)) lb_1 (
    .clock(clock),
    .reset(reset),
    
    .Dcache_valid(cache_LB[1].valid),
    .Dcache_data(cache_LB[1].data),
    .Dcache_index(cache_LB[1].index),
    .Dcache_req_successful(lb_request_success[1]),

    .Memory_valid(res_read_LB[1].valid),
    .Memory_data(res_read_LB[1].data),
    .Memory_index(res_read_LB[1].index),

    .CDB_0(cdb_0),
    .CDB_1(cdb_1),

    .resolved_store(resolved_store[1]),
    .all_stores(SQ_all[1]),
    .sq_head_index(sq_head_index[1]),
    .sq_tail_index(sq_tail_index[1]),
    .committed_store(committed_store[1]),

    .inst_in(disp_LSQ),
    .mispredict(nuke_thread_1),

    // debugging lb signals
    // .entries(lb_entries[1]), 
    // .free_list(lb_free_list[1]), 
    // .base_addr_ready_list(lb_base_addr_ready_list[1]),
    // .ready_to_go_list(lb_ready_to_go_list[1]), 
    // .ready_cdb_list(lb_ready_cdb_list[1]), 
    // .base_addr_ready_index(lb_base_addr_ready_index[1]), 
    // .ready_to_go_index(lb_ready_to_go_index[1]), 
    // .ready_cdb_index(lb_ready_cdb_index[1]),// debugging lb signals

    .load_req_is_ldl_mem(load_req_is_ldl_mem[1]),
    .almost_full(LB_almost_full[1]),
    .full(LB_full[1]),

    .valid_request(load_request[1]),
    .proc2Dcache_index(load_data_index[1]),
    .proc2Dcache_addr(load_data_address[1]),

    .output_to_CDB(LB_output[1]),
    .output_ldl_mem(LB_output_ldl_mem[1]),
    .output_addr(LB_output_addr[1]),
    .count(lb_count[1])
  );

endmodule