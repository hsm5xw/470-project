`timescale 1ns/100ps

module testbench();
	logic 					clock;
	logic 					reset;
	CDB	  					cdb0;
	CDB   					cdb1;
	logic [`ROB_BITS-1:0]	ROB_head_index;
	logic					mispredict;
	DISPATCH_LSQ	[1:0]	inst_in;
	logic					D_cache_success;
	//outputs
	SQ_ADDER_DATA			resolved_store;
	SQ_RETIRED_DATA			committed_store;
	logic					full;
	logic					sq_all;
	logic					almost_full;
	logic					store_success;
	logic					store_request;
	logic			[63:0]	store_data;
	logic			[63:0]	proc2Dcache_addr;
	logic   [`SQ_BITS-1:0]	head_index;
	logic	[`SQ_BITS-1:0]	tail_index;

	sq sq0(
		.clock(clock),
		.reset(reset),
		.cdb0(cdb0),
		.cdb1(cdb1),
		.ROB_head_index(ROB_head_index),
		.mispredict(mispredict),
		.D_cache_success(D_cache_success),
		.inst_in(inst_in), 
		//outputs
		.resolved_store(resolved_store),
		.committed_store(committed_store),
		.full(full),
		.sq_all(sq_all), 
		.ROB_index(ROB_index),
		.almost_full(almost_full),
		.store_success(store_success),
		.store_request(store_request), 
		.store_data(store_data), 
		.proc2Dcache_addr(proc2Dcache_addr),
		.head_index(head_index),
		.tail_index(tail_index)
		);

	always begin
		#5;
		clock = ~clock;
	end

	task assert_and_message;
		input condition;
		input [239:0] message;
		begin
			if(!condition) begin
				$display("%s \n@@@Failed", message);
				$finish;
			end
		end
	endtask

	task reset_inputs;
		reset                = 1;
		cdb0.FU_result   	 = 64'b0;
		cdb0.PRN 		 	 = 7'b0;
		cdb0.ROB_index   	 = 5'b0;
		cdb0.mispredict  	 = 0;
		cdb0.valid			 = 0;
		cdb0.thread_ID       = 0;
		cdb0.branch_actually_taken = 0;
		cdb1.FU_result   	 = 64'b0;
		cdb1.PRN 		 	 = 7'b0;
		cdb1.ROB_index   	 = 5'b0;
		cdb1.mispredict  	 = 0;
		cdb1.valid	         = 0;
		cdb1.thread_ID       = 0;
		cdb1.branch_actually_taken = 0;		
		ROB_head_index       = 5'b0;
		mispredict           = 0;
		inst_in[0].rd_mem    = 0;
		inst_in[0].wr_mem    = 0;
		inst_in[0].ldl_mem   = 0;
		inst_in[0].stc_mem   = 0;
		inst_in[0].thread_ID = 0;
		inst_in[0].dispatch  = 0;
		inst_in[0].value_to_store       = 64'b0;
		inst_in[0].value_to_store_ready = 0;
		inst_in[0].op1_PRN              = 7'b0;
		inst_in[0].base_addr_ready      = 0; 
		inst_in[0].base_addr     		= 64'b0;
		inst_in[0].base_addr_PRN		= 7'b0;
		inst_in[0].offset				= 64'b0;
		inst_in[0].PRN_dest				= 7'b0;
		inst_in[0].ROB_index            = 5'b0; 
		inst_in[1].rd_mem    = 0;
		inst_in[1].wr_mem    = 0;
		inst_in[1].ldl_mem   = 0;
		inst_in[1].stc_mem   = 0;
		inst_in[1].thread_ID = 0;
		inst_in[1].dispatch  = 0;
		inst_in[1].value_to_store       = 64'b0;
		inst_in[1].value_to_store_ready = 0;
		inst_in[1].op1_PRN              = 7'b0;
		inst_in[1].base_addr_ready      = 0; 
		inst_in[1].base_addr     		= 64'b0;
		inst_in[1].base_addr_PRN		= 7'b0;
		inst_in[1].offset				= 64'b0;
		inst_in[1].PRN_dest				= 7'b0;
		inst_in[1].ROB_index            = 5'b0; 
	endtask

	task insert_two_stores;
		inst_in[0].wr_mem   = 1;
		inst_in[0].dispatch = 1;
		inst_in[0].ROB_index = 5'b00001;
		inst_in[0].PRN_dest  = 7'b10000;
		inst_in[1].wr_mem   = 1;
		inst_in[1].dispatch = 1;
		inst_in[1].ROB_index = 5'b00011;
		@(negedge clock);
		inst_in[0].wr_mem   = 0;
		inst_in[0].dispatch = 0;
		inst_in[0].ROB_index = 5'b0;
		inst_in[1].wr_mem   = 0;
		inst_in[1].dispatch = 0;
		inst_in[1].ROB_index = 5'b0;
		@(negedge clock);
	endtask

	task insert_one_store;
		inst_in[0].wr_mem   = 1;
		inst_in[0].dispatch = 1;
		inst_in[0].ROB_index = 5'b00001;
		@(negedge clock);
		inst_in[0].wr_mem   = 0;
		inst_in[0].dispatch = 0;
		inst_in[0].ROB_index = 5'b0;
		@(negedge clock);
	endtask

	task committed_store_task;
		cdb0.PRN       = 7'b0;
		D_cache_success = 1;
		@(negedge clock);
		cdb0.valid     = 0;
		D_cache_success = 0;
	endtask

	initial 
	begin
		reset_inputs();
		clock = 0;
		@(negedge clock);
		clock = 0;
		reset = 0;
		@(negedge clock);
		//inserts 12 data entries in the SQ. It shouldn't be full yet. Nothing should resolve 
		for(int i = 0; i < 6; i ++) begin
			insert_two_stores();
			assert_and_message(full == 0 && almost_full == 0 && !resolved_store.valid, "Testing if full and almost full is zero");
		end
		//start to fill it up. 
		insert_one_store();
		assert_and_message(full == 0 && almost_full == 1 && !resolved_store.valid, "Testing if almost full works");
		//says it is full with two empty entries due to pipeline 
		insert_one_store();
		assert_and_message(full == 1 && almost_full == 0 && !resolved_store.valid, "Testing if full works");	
		//insert the two from pipeline. It is truely full now.
		insert_two_stores();
		assert_and_message(full == 1 && almost_full == 0 && tail_index == 4'hf && !resolved_store.valid, "Testing to see if no dispatch");
		//Here everything will be ready and the effective address will be ready to calculate
		cdb0.valid     = 1;	
		committed_store_task();
		//Things should start to resolve but it won't commit since the ROB head isn't there yet
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'hf && committed_store.sq_index == 4'h0 && !committed_store.valid, "Testing resolve logic 15");
		@(negedge clock);
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'he && committed_store.sq_index == 4'h0 && !committed_store.valid, "Testing resolve logic 14");
		@(negedge clock);
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'hd && committed_store.sq_index == 4'h0 && !committed_store.valid, "Testing resolve logic 13");
		//since D_cache is success and the ROB_index is in the right spot things will start to commit
		ROB_head_index = 5'b00001; 
		D_cache_success = 1;
		@(posedge clock);
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'hd && committed_store.sq_index[0] == 4'hf && store_success && store_request, "testing committed_store");
		@(negedge clock);
		ROB_head_index = 5'b00011; 
		@(posedge clock);
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'hc && committed_store.sq_index[0] == 4'he && store_success && store_request, "Testing committed_store 2");
		@(negedge clock);
		ROB_head_index = 5'b00001; 
		@(posedge clock);
		assert_and_message(full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'hb && committed_store.sq_index[0] == 4'hd && store_success && store_request, "Testing committed_store 3");
		@(negedge clock);
		ROB_head_index = 5'b00011; 
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 1 && tail_index == 4'hf && resolved_store.sq_index == 4'ha && committed_store.sq_index[0] == 4'hc && store_success && store_request, "Testing committed_store 4");
		@(negedge clock);
		//the ROB head index doesn't match the one in the SQ data so it shouldn't commit
		ROB_head_index = 5'b00011; 
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hf && resolved_store.sq_index == 4'h9 && committed_store.sq_index[0] == 4'h0 && !store_success && !store_request, "Testing committed_store 5");
		@(negedge clock);
		//starts to commit again
		ROB_head_index = 5'b00001; 
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hf && resolved_store.sq_index == 4'h8 && committed_store.sq_index[0] == 4'hb && store_success && store_request, "Testing committed_store 6");
		@(negedge clock);
		//this will commit one and dispatch two at the same time
		ROB_head_index = 5'b00011;
		inst_in[0].wr_mem   = 1;
		inst_in[0].dispatch = 1;
		inst_in[0].ROB_index = 5'b00001;
		inst_in[0].PRN_dest  = 7'b1000000;
		inst_in[0].op1_PRN   = 7'b1000100;
		inst_in[0].base_addr_PRN = 7'b1001000;
		inst_in[1].wr_mem   = 1;
		inst_in[1].dispatch = 1;
		inst_in[1].ROB_index = 5'b00011;
		inst_in[1].op1_PRN   = 7'b1000101;
		inst_in[1].base_addr_PRN = 7'b1001001;
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hf && resolved_store.sq_index == 4'h7 && committed_store.sq_index[0] == 4'ha && store_success && store_request, "Testing to see if dispatch");
		@(negedge clock);
		inst_in[0].wr_mem   = 0;
		inst_in[0].dispatch = 0;
		inst_in[0].ROB_index = 5'b0;
		inst_in[0].op1_PRN   = 7'b0;
		inst_in[0].base_addr_PRN = 7'b0;
		inst_in[1].wr_mem   = 0;
		inst_in[1].dispatch = 0;
		inst_in[1].ROB_index = 5'b0;
		inst_in[1].op1_PRN   = 7'b0;
		inst_in[1].base_addr_PRN = 7'b0;
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hd && head_index == 4'h9, "see if head and tail was updated right");
		@(negedge clock);
		mispredict = 1;
		@(negedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hf && head_index == 4'hf, "Testing to see mispredict");
		@(negedge clock);
		mispredict = 0;
		inst_in[0].wr_mem   = 1;
		inst_in[0].offset = 64'h5;
		inst_in[0].dispatch = 1;
		inst_in[0].ROB_index = 5'b00001;
		inst_in[0].PRN_dest  = 7'b1000000;
		inst_in[0].op1_PRN   = 7'b1000100;
		inst_in[0].base_addr_PRN = 7'b1001000;
		inst_in[1].wr_mem   = 1;
		inst_in[1].dispatch = 1;
		inst_in[1].ROB_index = 5'b00011;
		inst_in[1].op1_PRN   = 7'b1000101;
		inst_in[1].base_addr_PRN = 7'b1001001;
		@(negedge clock);
		inst_in[0].wr_mem   = 0;
		inst_in[0].dispatch = 0;
		inst_in[0].ROB_index = 5'b0;
		inst_in[0].op1_PRN   = 7'b0;
		inst_in[0].base_addr_PRN = 7'b0;
		inst_in[1].wr_mem   = 0;
		inst_in[1].dispatch = 0;
		inst_in[1].ROB_index = 5'b0;
		inst_in[1].op1_PRN   = 7'b0;
		inst_in[1].base_addr_PRN = 7'b0;
		assert_and_message(tail_index == 4'hd && head_index == 4'hf, "testing head and tail after mispredict");
		@(negedge clock);
		cdb0.valid = 1;
		cdb1.valid = 1;
		cdb1.PRN = 7'b1000100;
		cdb1.FU_result = 64'h3;
		cdb0.PRN = 7'b1001000;
		cdb0.FU_result = 64'h5;
		@(negedge clock);
		ROB_head_index = 5'b00001;
		D_cache_success = 0;
		//checks to see if the CDB broadcast right and if the D_cache is full we will keeping trying the same instruction
		@(negedge clock);
		@(negedge clock);
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hd && head_index == 4'hf && !store_success && store_request, "See if CDB broadcast right");
		@(negedge clock);
		D_cache_success = 1;
		@(posedge clock);
		assert_and_message(full == 0 && almost_full == 0 && tail_index == 4'hd && head_index == 4'hf && store_success && committed_store.sq_index[0] == 4'hf && committed_store.sq_address[0] == 64'ha && committed_store.sq_value[0] == 64'h3 && store_request, "See if commits right");
		@(negedge clock);
		$display("@@@PASSED!");
        $finish;

	end




endmodule




