`timescale 1ns/100ps

module testbench();

	logic clock;
	logic reset;

	logic                Dcache_valid;
	logic         [63:0] Dcache_data;
	logic [`LB_BITS-1:0] Dcache_index;
	logic                Dcache_req_successful;

	logic                Memory_valid;
	logic         [63:0] Memory_data;
	logic [`LB_BITS-1:0] Memory_index;

	CDB                  CDB_0;
	CDB                  CDB_1;	
	SQ_ADDER_DATA        resolved_store;
	SQ_ALL_DATA          all_stores;	
	SQ_RETIRED_DATA      committed_stores;	
	DISPATCH_LSQ   [1:0] inst_in;

	logic [`SQ_BITS-1:0] sq_head_index;
	logic [`SQ_BITS-1:0] sq_tail_index;	
	logic                mispredict;

	logic almost_full, full, valid_request;
	logic [`LB_BITS-1:0] proc2Dcache_index;
	logic         [63:0] proc2Dcache_addr;	

	FU_RESULT            output_to_CDB;
	logic                output_ldl_mem;
	logic         [63:0] output_addr;
	logic   [`LB_BITS:0] count;

	lb lb_0 (
		.clock (clock), 
		.reset (reset), 
		
		.Dcache_valid(Dcache_valid),
		.Dcache_data(Dcache_data),
		.Dcache_index(Dcache_index),
		.Dcache_req_successful(Dcache_req_successful),

		.Memory_valid(Memory_valid),
		.Memory_data(Memory_data),
		.Memory_index(Memory_index),

		.CDB_0(CDB_0),
		.CDB_1(CDB_1),
		.resolved_store(resolved_store),
		.all_stores(all_stores),
		.committed_stores(committed_stores),		
		.inst_in(inst_in),

		.sq_head_index(sq_head_index),
		.sq_tail_index(sq_tail_index),		
		.mispredict(mispredict),

		.almost_full(almost_full),
		.full(full),
		.valid_request(valid_request),
		.proc2Dcache_index(proc2Dcache_index),
		.proc2Dcache_addr(proc2Dcache_addr),

		.output_to_CDB(output_to_CDB),
		.output_ldl_mem(output_ldl_mem),
		.output_addr(output_addr),
		.count(count)
		);

	always begin
		#5;
		clock = ~clock;
	end

	task reset_inputs;

		Dcache_valid = 0;
		Dcache_data  = 64'b0;
		Dcache_index = 0;
		Dcache_req_successful = 0;
		Memory_valid = 0;
		Memory_data = 64'b0;
		Memory_index = 0;

		for(int j=0; j<2; j++) begin
			inst_in[j].rd_mem               = 0;
			inst_in[j].wr_mem               = 0;
			inst_in[j].ldl_mem              = 0;
			inst_in[j].stc_mem              = 0;
			inst_in[j].thread_ID            = 0;
			inst_in[j].dispatch             = 0;
			inst_in[j].value_to_store       = 64'b0;
			inst_in[j].op1_PRN              = 64'b0;
			inst_in[j].value_to_store_ready = 1'b0;
			inst_in[j].base_addr_ready      = 0;
			inst_in[j].base_addr            = 64'b0;
			inst_in[j].base_addr_PRN        = 0;
			inst_in[j].offset               = 64'b0;
			inst_in[j].PRN_dest             = 0;
			inst_in[j].ROB_index            = 0;

			committed_stores.valid[j]       = 0;
			committed_stores.sq_index[j]    = 0;
			committed_stores.sq_address[j]  = 64'b0;
			committed_stores.sq_value[j]    = 64'b0;
		end

		for(int j=0; j<`SQ_SIZE; j++) begin
			all_stores.valid[j] = 1'b0;
			all_stores.stc_mem[j] = 1'b0;
			all_stores.address_resolved[j] = 1'b0;
			all_stores.address[j] = 64'hDEAD_DEAD;
		end

		CDB_0.FU_result             = 64'hAAAA_AAAA_AAAA_AAAA;
		CDB_0.PRN                   = 0;
		CDB_0.ROB_index             = 0;
		CDB_0.mispredict            = 0;
		CDB_0.valid 	            = 0;
		CDB_0.thread_ID             = 0;
		CDB_0.branch_actually_taken = 1'b0;
		CDB_1.FU_result             = 64'hBBBB_BBBB_BBBB_BBBB;
		CDB_1.PRN                   = 1;
		CDB_1.ROB_index             = 1;
		CDB_1.mispredict            = 0;
		CDB_1.valid                 = 0;
		CDB_1.thread_ID             = 0;
		CDB_1.branch_actually_taken = 1'b0;

		resolved_store.valid        = 0;
		resolved_store.stc_mem      = 0;
		resolved_store.sq_index     = 0;
		resolved_store.sq_address   = 64'b0;
		
		sq_head_index = 0;
		sq_tail_index = 0;
		mispredict    = 0;
		
	endtask

	task reset_LB;
		reset = 1;
		reset_inputs();
		@(negedge clock);
		reset = 0;
	endtask

	task assert_and_message;
		input condition;
		input [255:0] message;
		begin
			if(!condition) begin
				$display("%s \n@@@Failed", message);
				$finish;
			end
		end
	endtask

	task fill_buffer;
		input [`LB_BITS:0] num_inst;
		input [`SQ_BITS-1:0] sq_h;
		input [`SQ_BITS-1:0] sq_t;
		begin
			@(negedge clock);

			for(int i=0; i< num_inst; i++ ) begin
				@(negedge clock);

				inst_in[0].rd_mem          = 1;
				inst_in[0].wr_mem          = 0;
				inst_in[0].ldl_mem         = 0;
				inst_in[0].stc_mem         = 0;
				inst_in[0].thread_ID       = 0;
				inst_in[0].dispatch        = 1;
				inst_in[0].value_to_store  = 64'b0;
				inst_in[0].base_addr_ready = 1;
				inst_in[0].base_addr       = 64'h600;
				inst_in[0].base_addr_PRN   = i;
				inst_in[0].offset          = 64'h200;
				inst_in[0].PRN_dest        = 0;
				inst_in[0].ROB_index       = 0;
				sq_head_index              = sq_h;
				sq_tail_index              = sq_t;

			end
			@(negedge clock);
			inst_in[0].dispatch = 0;
			inst_in[1].dispatch = 0;
		end
	endtask
	
	task dispatch_1_base_not_ready;
		input [`SQ_BITS-1:0] sq_h;
		input [`SQ_BITS-1:0] sq_t;
		input [`PR_BITS-1:0] prn;
		begin
			@(negedge clock);
			inst_in[0].rd_mem          = 1;
			inst_in[0].wr_mem          = 0;
			inst_in[0].ldl_mem         = 0;
			inst_in[0].stc_mem         = 0;
			inst_in[0].thread_ID       = 0;
			inst_in[0].dispatch        = 1;
			inst_in[0].value_to_store  = 64'b0;
			inst_in[0].base_addr_ready = 0;
			inst_in[0].base_addr       = 64'h0;
			inst_in[0].base_addr_PRN   = prn;
			inst_in[0].offset          = 64'h0;
			inst_in[0].PRN_dest        = 0;
			inst_in[0].ROB_index       = 0;
			sq_head_index              = sq_h;
			sq_tail_index              = sq_t;
		end
			@(negedge clock);
			inst_in[0].rd_mem = 0;
			inst_in[0].dispatch = 0;
	endtask

	task dispatch_1_base_ready;
		input [`SQ_BITS-1:0] sq_h;
		input [`SQ_BITS-1:0] sq_t;
		input         [63:0] addr;
		begin
			@(negedge clock);
			inst_in[0].rd_mem          = 1;
			inst_in[0].wr_mem          = 0;
			inst_in[0].ldl_mem         = 0;
			inst_in[0].stc_mem         = 0;
			inst_in[0].thread_ID       = 0;
			inst_in[0].dispatch        = 1;
			inst_in[0].value_to_store  = 64'b0;
			inst_in[0].base_addr_ready = 1;
			inst_in[0].base_addr       = addr;
			inst_in[0].base_addr_PRN   = 0;
			inst_in[0].offset          = 64'h0;
			inst_in[0].PRN_dest        = 0;
			inst_in[0].ROB_index       = 0;
			sq_head_index              = sq_h;
			sq_tail_index              = sq_t;
		end
			@(negedge clock);
			inst_in[0].rd_mem = 0;
			inst_in[0].dispatch = 0;
	endtask

	task insert_store;
		input [`SQ_BITS-1:0] index;
		input addr_res;
		input [63:0] address;

		begin
			all_stores.valid[index]            = 1'b1;
			all_stores.address_resolved[index] = addr_res;
			all_stores.address[index]          = address;
		end
	endtask

	task CDB_broadcast_once;
		input CDB_0_valid;
		input CDB_1_valid;
		input [`PR_BITS-1:0] pr_1;
		input [`PR_BITS-1:0] pr_2;

		begin
			@(negedge clock);

			CDB_0.valid = CDB_0_valid;
			CDB_1.valid = CDB_1_valid;

			CDB_0.FU_result = 100;
			CDB_1.FU_result = 200;

			CDB_0.PRN = pr_1;
			CDB_1.PRN = pr_2;
		
			@(negedge clock);

			CDB_0.valid = 0;
			CDB_1.valid = 0;
		end
	endtask

	task store_broadcast;
		input [`SQ_BITS-1:0] sq_ind;
		input         [63:0] addr;

		begin
		 	@(negedge clock);
		 		resolved_store.valid      = 1'b1;
		 		resolved_store.sq_index   = sq_ind;
		 		resolved_store.sq_address = addr;
		 	@(negedge clock);
		 		resolved_store.valid      = 1'b0;
		end
	endtask

	task store_leaves;
		input [`SQ_BITS-1:0] sq_ind;
		input         [63:0] addr;
		input         [63:0] val;

		begin
		 	@(negedge clock);
		 		committed_stores.valid      = 1'b1;
		 		committed_stores.sq_index   = sq_ind;
		 		committed_stores.sq_address = addr;
		 		committed_stores.sq_value   = val;
		 	@(negedge clock);
		 		committed_stores.valid      = 1'b0;
		end
	endtask

	task d_cache_in;
		input         [63:0] data;
		input [`LB_BITS-1:0] lb_index;

		begin
			@(negedge clock);
				Dcache_valid = 1'b1;
				Dcache_data  = data;
				Dcache_index = lb_index;
			@(negedge clock);
				Dcache_valid = 1'b0;
		end
	endtask

	initial 
	begin
		clock = 0;

		//$display("Fill up the LB with entries");
		reset_LB();
		@(negedge clock);
		fill_buffer(`LB_SIZE, `SQ_SIZE-1, `SQ_SIZE-5);
		@(negedge clock);
		assert_and_message(count == `LB_SIZE, "LB should be almost full");
		reset_LB();
		@(negedge clock);

		//$display("See whether a load with invalid op1 computes its address and makes request to Dcache");
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-4, 15);
		@(negedge clock);
		CDB_broadcast_once(1,0,15,12);
		@(negedge clock);
		assert_and_message(valid_request, "Load should compute its address and request");
		reset_LB();
		@(negedge clock);

		//$display("Dependent store in SQ... what will the load do???");	
		insert_store(`SQ_SIZE-1, 1, 64'h200);
		insert_store(`SQ_SIZE-2, 1, 64'h300);
		insert_store(`SQ_SIZE-3, 1, 64'h400);	
		dispatch_1_base_ready(`SQ_SIZE-1, `SQ_SIZE-4, 64'h200);
		
		@(negedge clock);
		@(negedge clock);
		assert_and_message(!valid_request, "Load should not make request to memory while dependent on store");
		reset_LB();
		@(negedge clock);

		insert_store(`SQ_SIZE-1, 0, 64'h200);
		insert_store(`SQ_SIZE-2, 0, 64'h300);
		insert_store(`SQ_SIZE-3, 0, 64'h400);	
		dispatch_1_base_ready(`SQ_SIZE-1, `SQ_SIZE-2, 64'h200);
		
		@(negedge clock);
		@(negedge clock);
		assert_and_message(!valid_request, "Load should not make request to memory while there's unknown stores");

		store_broadcast(`SQ_SIZE-1, 64'h200);
		store_broadcast(`SQ_SIZE-2, 64'h300);
		store_broadcast(`SQ_SIZE-3, 64'h400);

		@(negedge clock);
		assert_and_message(!valid_request, "Load should not make request to memory while dependent on store");

		reset_LB();
		@(negedge clock);

		insert_store(`SQ_SIZE-1, 0, 64'h600);
		insert_store(`SQ_SIZE-2, 0, 64'h700);
		insert_store(`SQ_SIZE-3, 0, 64'h800);
		insert_store(`SQ_SIZE-4, 1, 64'h600);
		insert_store(`SQ_SIZE-5, 1, 64'h700);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);

		@(negedge clock);
		CDB_broadcast_once(1,0,30,0);
		@(negedge clock);
		assert_and_message(!valid_request, "Load should not make request with unknown stores in SQ");
		@(negedge clock);
		store_broadcast(`SQ_SIZE-1, 64'h1000);
		store_broadcast(`SQ_SIZE-2, 64'h1000);
		store_broadcast(`SQ_SIZE-3, 64'h1000);
		@(negedge clock);

		assert_and_message(valid_request, "Load should make request to memory after resolving all stores");

		reset_LB();
		@(negedge clock);

		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		dispatch_1_base_not_ready(`SQ_SIZE-1, `SQ_SIZE-6, 30);
		assert_and_message(count == `LB_SIZE, "LB should be full");

		@(negedge clock);
		CDB_broadcast_once(1,0,30,0);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		// The addresses are computed one at a time, and are ready to make a request to cdb.
		// Visual check on DVE.

		Dcache_valid = 1'b1;
		Dcache_index = 7;
		Dcache_data = 64'h90;

		@(negedge clock);
		Dcache_valid = 1'b1;
		Dcache_index = 7;
		Dcache_data = 64'h90;

		// One entry is ready to broadcast on CDB. Updates the ready_to_go list and cdb_ready list.
		// Visual check on DVE.
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);

		$display("\n@@@PASSED!");
		$finish;
	end // initial
endmodule