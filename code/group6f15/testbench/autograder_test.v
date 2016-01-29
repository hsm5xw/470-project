`timescale 1ns/100ps

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

  PRF_DATA    [`PR_SIZE-1:0] prf_arr;
  ROB_RRAT           [1:0] rob0_rrat_inst;
  ROB_RRAT           [1:0] rob1_rrat_inst;
  logic                    rob0_halt;
  logic                    rob1_halt;

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

    // .proc2Imem_addr    (proc2Imem_addr),
    // .proc2Imem_command (proc2Imem_command),
    // .Imem2proc_response(Imem2proc_response),

    // .proc2Dmem_addr(proc2Dmem_addr),
    // .proc2Dmem_command(proc2Dmem_command),
    // .Dmem2proc_response(Dmem2proc_response),

    // .icachemem_data_out     (icachemem_data_out),
    // .icachemem_valid_out    (icachemem_valid_out),
    // .icache_rd_idx     (icache_rd_idx),
    // .icache_rd_tag     (icache_rd_tag),
    // .icache_wr_idx     (icache_wr_idx),
    // .icache_wr_tag     (icache_wr_tag),
    // .icache_wr_en      (icache_wr_en),
    // .icache0_data      (icache0_data),
    // .proc2Icache0_addr (proc2Icache0_addr),
    // .icache0_valid     (icache0_valid),

    // // debugging prefetch
    // .icache_tag_arr(icache_tag_arr), 
    // .icache_addr_arr(icache_addr_arr), 
    // .icache_prefetch_pc(icache_prefetch_pc), 
    // .icache_prefetch_thread(icache_prefetch_thread), 
    // .icache_head_index(icache_head_index), 
    // .icache_tail_index(icache_tail_index), 

    // // debugging IF
    // .if_smt_mode       (if_smt_mode),
    // .if_active_thread  (if_active_thread),

    // // debugging icache
    // .icachemem_valids  (icachemem_valids), 
    // .icachemem_data    (icachemem_data), 
    // .icachemem_tags    (icachemem_tags),

    // // debugging rrat
    // .rat_arr           (rat_arr),
    // .rrat_arr          (rrat_arr),
    // .rrat_free_list    (rrat_free_list), 
    // .rrat_committed_prn(rrat_committed_prn), 

    // // debugging prf
    // .prf_arr           (prf_arr),
    // .prf_free_list     (prf_free_list),
    // .prf_free_prn      (prf_free_prn), 

    // // debugging rob
    .rob0_rrat_inst(rob0_rrat_inst), 
    .rob0_halt(rob0_halt), 
    .prf_arr(prf_arr), 
    // .rob0_nuke(rob0_nuke), 
    // .rob0_if_inst(rob0_if_inst), 
    // .rob0_arr(rob0_arr), 

    // .rob0_count(rob0_count), 
    // .rob0_head_index(rob0_head_index), 
    // .rob0_n_head_index(rob0_n_head_index), 
    // .rob0_tail_index(rob0_tail_index), 
    // .rob0_n_tail_index(rob0_n_tail_index), 
    // .rob0_fork_committed(rob0_fork_committed), 

    .rob1_rrat_inst(rob1_rrat_inst), 
    .rob1_halt(rob1_halt)
    // .rob1_nuke(rob1_nuke), 
    // .rob1_if_inst(rob1_if_inst), 
    // .rob1_arr(rob1_arr), 

    // .rob1_count(rob1_count), 
    // .rob1_head_index(rob1_head_index), 
    // .rob1_n_head_index(rob1_n_head_index), 
    // .rob1_tail_index(rob1_tail_index), 
    // .rob1_n_tail_index(rob1_n_tail_index), 

    // // debugging RS
    // .rs_dispatch_free_list(rs_dispatch_free_list), 
    // .rs_awaken_alu_list   (rs_awaken_alu_list), 
    // .rs_awaken_mult_list  (rs_awaken_mult_list), 
    // .rs_awaken_branch_list(rs_awaken_branch_list), 
    // .rs_array             (rs_array), 
    // .rs_count             (rs_count), 

    // // instruction struct
    // .if_id_inst        (if_id_inst), 
    // .id_dispatch_inst  (id_dispatch_inst), 
    // .prf_dispatch_inst (prf_dispatch_inst),
    // .dispatch_rob_inst (dispatch_rob_inst), 
    // .dispatch_rs_inst  (dispatch_rs_inst),
    // .rs_ex_inst        (rs_ex_inst),
    // .n_rs_ex_inst      (n_rs_ex_inst),
    // .dispatch_lsq_inst (dispatch_lsq_inst),
    // .rat_prf_inst      (rat_prf_inst),

    // // debugging cdb
    // .cdb_0(cdb_0),
    // .cdb_1(cdb_1), 
    // .dispatch_stall(dispatch_stall), 

    // // debugging dcache
    // .dcache_current_response(dcache_current_response),
    // .dcache_resolved_load(dcache_resolved_load),
    // .dcache_request_failed(dcache_request_failed),
    // .dcache_wr_req_idx(dcache_wr_req_idx),                  
    // .dcache_wr_req_tag(dcache_wr_req_tag), 
    // .dcache_wr_req_data(dcache_wr_req_data),
    // .dcache_wr_missed_load_idx(dcache_wr_missed_load_idx),                  
    // .dcache_wr_missed_load_tag(dcache_wr_missed_load_tag), 
    // .dcache_wr_req_en(dcache_wr_req_en), 
    // .dcache_wr_missed_load_en(dcache_wr_missed_load_en), 
    // .dcache_rd_idx(dcache_rd_idx),
    // .dcache_rd_tag(dcache_rd_tag), 

    // .dcache_request_buff(dcache_request_buff), 
    // .dcache_head_index(dcache_head_index),  
    // .dcache_tail_index(dcache_tail_index),  
    // .dcache_count(dcache_count),              

    // // debugging dcachemem
    // .dcachemem_data(dcachemem_data),
    // .dcachemem_tags(dcachemem_tags),
    // .dcachemem_valids(dcachemem_valids),
    // .dcachemem_data_out(dcachemem_data_out),
    // .dcachemem_valid_out(dcachemem_valid_out), 

    // // debugging lsq
    // .lsq_request(lsq_request),
    // .lsq_ex_inst(lsq_ex_inst),
    // .lsq_full(lsq_full),
    // .lsq_almost_full(lsq_almost_full),

    // // debugging sq 
    // .sq_entries(sq_entries), 
    // .sq_eff_add_ready_list(sq_eff_add_ready_list), 
    // .sq_eff_add_ready_index(sq_eff_add_ready_index),
    // .sq_count(sq_count),
    // .sq_head_index(sq_head_index), 
    // .sq_tail_index(sq_tail_index), 

    // // debugging lb 
    // .lb_entries(lb_entries), 
    // .lb_free_list(lb_free_list), 
    // .lb_base_addr_ready_list(lb_base_addr_ready_list),
    // .lb_count(lb_count), 
    // .lb_ready_to_go_list(lb_ready_to_go_list), 
    // .lb_ready_cdb_list(lb_ready_cdb_list), 
    // .lb_base_addr_ready_index(lb_base_addr_ready_index), 
    // .lb_ready_to_go_index(lb_ready_to_go_index), 
    // .lb_ready_cdb_index(lb_ready_cdb_index),
    // .lb_request_success(lb_request_success), 

    // // debugging FU stuff
    // .ALU_0_sent(ALU_0_sent), 
    // .ALU_1_sent(ALU_1_sent), 
    // .Mult_sent(Mult_sent),
    // .Branch_sent(Branch_sent) 
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

  // Task to display # of elapsed clock edges
  task show_clk_count;
    real cpi;
    begin
      cpi = (clock_count + 1.0) / instr_count;
      $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
      clock_count+1, instr_count, cpi);
      $display("@@  %4.2f ns total time to execute\n@@\n",
      clock_count*`VIRTUAL_CLOCK_PERIOD);
    end
  endtask  // task show_clk_count 

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
        
    @(negedge clock);
    repeat(500000) @(negedge clock);
    $fclose(wb_fileno);
    $fclose(wb_fileno1);
    $finish;
  end 

  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock or posedge reset)
  begin
    if(reset)
    begin
      clock_count <= `SD 0;
      instr_count <= `SD 0;
    end
    else
    begin
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

  always @(negedge clock) begin
    if(reset)
      $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
               $realtime);
    else begin
      `SD;
      `SD;

      // print the writeback information for thread 0 to writeback.out
      for(int i=0; i<2; i++) begin
        if(rob0_rrat_inst[i].committed) begin
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
        show_clk_count;
        $fclose(wb_fileno);
        $fclose(wb_fileno1);
        #100 $finish;
      end

    end
  end 
endmodule
