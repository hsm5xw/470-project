`timescale 1ns/100ps

module sq #(parameter THREAD_ID=0) (
	input                      clock,
	input                      reset,
	input CDB                  cdb0, 
	input CDB                  cdb1,
	input [`ROB_BITS-1:0]	   ROB_head_index,
	input					   D_cache_success,
	input					   mispredict,
	input DISPATCH_LSQ   [1:0] inst_in,


	output SQ_ADDER_DATA       resolved_store,
	output SQ_RETIRED_DATA	   committed_store,
	output SQ_ALL_DATA		   sq_all, 
	output logic               full,
	output logic 			   almost_full,
	output logic 			   store_success,
	output logic			   store_request,
	output logic        [`ROB_BITS-1:0]  ROB_index,
	output logic        [`PR_BITS-1:0]  PRN_dest,
	output logic					     is_stc_mem,
	output logic		[63:0]           store_data,
	output logic        [63:0]           proc2Dcache_addr,
	output logic 		[`SQ_BITS-1:0]   head_index,
	output logic		[`SQ_BITS-1:0]   tail_index

);

	SQ_DATA [`SQ_SIZE-1:0] sq_entries; 
	logic [`SQ_SIZE-1:0] eff_add_ready_list; 
	logic [`SQ_BITS-1:0] eff_add_ready_index;
	logic [`SQ_BITS:0]   count;

	logic [`SQ_BITS-1:0]   n_head_index;
	logic [`SQ_BITS-1:0]   n_tail_index;
	logic [`ROB_BITS-1:0]  ROB_head_index_plus_1;
	logic [`SQ_BITS:0]     n_count;
	logic [`SQ_BITS-1:0]   head_index_minus_1, tail_index_minus_1;
	logic [`SQ_BITS-1:0]   n_head_index_minus_1, n_tail_index_minus_1;
	logic				   two_commit, one_commit, dispatch_1, dispatch_2, n_full, n_almost_full;
	logic [`SQ_SIZE-1:0]   n_eff_add_ready_list;
	logic [`SQ_SIZE-1:0]   eff_add_ready_gnt, eff_add_ready_gnt_bus;
	logic                  eff_add_ready_empty; 
	logic                  two_committed, one_committed;
	logic                  committed_for_real;

	SQ_DATA [`SQ_SIZE-1:0] n_sq_entries;

	logic first_dispatch, second_dispatch;

	// Adder priority selector and encoder
	psel_gen #(.REQS(1), .WIDTH(`SQ_SIZE)) adder_priority_selector (
		.req(eff_add_ready_list),
		.gnt(eff_add_ready_gnt),
		.gnt_bus(eff_add_ready_gnt_bus), 
		.empty(eff_add_ready_empty)
	);

	pe #(.OUT_WIDTH(`SQ_BITS), .IN_WIDTH(`SQ_SIZE)) adder_encoded (
		.gnt(eff_add_ready_gnt_bus),
		.enc(eff_add_ready_index)
	);

	always_comb begin
		committed_for_real = 0;


		n_count = count;
		head_index_minus_1 = head_index - 1;
		tail_index_minus_1 = tail_index - 1;
		n_head_index_minus_1 = n_tail_index - 1;
		n_tail_index_minus_1 = n_tail_index - 1;
		n_sq_entries = sq_entries;
		n_eff_add_ready_list = eff_add_ready_list;

		for(int i = 0; i < `SQ_SIZE; i ++) begin
			sq_all.valid[i] = sq_entries[i].valid;
			sq_all.stc_mem[i] = sq_entries[i].stc_mem;
			sq_all.address_resolved[i] = sq_entries[i].address_resolved;
			sq_all.address[i] = sq_entries[i].effective_address;
		end

		//This will do one addition. Once the address has been computed it can be sent to the LB
		if(!eff_add_ready_empty  && !mispredict) begin
			n_sq_entries[eff_add_ready_index].effective_address = sq_entries[eff_add_ready_index].offset +
			                                                      sq_entries[eff_add_ready_index].base_addr;
			n_eff_add_ready_list[eff_add_ready_index]           = 1'b0;
			n_sq_entries[eff_add_ready_index].address_resolved  = 1'b1;

			//since we have the effective address we will broadcast to the LB
			resolved_store.valid      = 1;
			resolved_store.sq_index   = eff_add_ready_index;
			resolved_store.sq_address = n_sq_entries[eff_add_ready_index].effective_address;
			resolved_store.stc_mem    = n_sq_entries[eff_add_ready_index].stc_mem;
		end else begin
			//n_sq_entries[eff_add_ready_index].address_resolved = 1'b0;
			resolved_store.valid      = 0;
			resolved_store.sq_index   = 4'b0;
			resolved_store.sq_address = 64'b0;
			resolved_store.stc_mem    = 0;
		end	

		//This tells other logic in SQ if only one or two store will commit
		//its also calculates the new head index
		/*
		if((ROB_head_index == sq_entries[head_index].ROB_index) 
			&& (ROB_head_index_plus_1 == sq_entries[head_index].ROB_index)) begin
			two_commit = 1;
			one_commit = 1;
			n_head_index = head_index + 2;
		*/
		//we will only commit one since the cache can only take in one store at a time
		 	
		if((ROB_head_index == sq_entries[head_index].ROB_index)
					&& sq_entries[head_index].value_to_store_ready && sq_entries[head_index].address_resolved
					&& sq_entries[head_index].base_addr_ready && sq_entries[head_index].valid) begin
			two_commit = 0;
			one_commit = 1;
		end else begin
			two_commit = 0;
			one_commit = 0;
		end

		two_committed = two_commit;
		one_committed = one_commit;
		if(!store_success) begin
			two_committed = 0;
			one_committed = 0;
		end

		//this will tell if one or two stores will dispatch
		//it also calculates the new tail index
		first_dispatch  = inst_in[0].wr_mem && inst_in[0].dispatch && inst_in[0].thread_ID == THREAD_ID;
		second_dispatch = inst_in[1].wr_mem && inst_in[1].dispatch && inst_in[1].thread_ID == THREAD_ID;


		if(first_dispatch && second_dispatch) begin
			dispatch_2 = 1;
			dispatch_1 = 1;
			n_tail_index = tail_index - 2;
		end else if(first_dispatch ^ second_dispatch) begin
			dispatch_2 = 0;
			dispatch_1 = 1;
			n_tail_index = tail_index_minus_1;
		end else begin
			dispatch_2 = 0;
			dispatch_1 = 0;
			n_tail_index = tail_index;
		end

	

	    //next logic for the SQ
		
		//invalidate the entries occupited by committed stores //////////////////////////////////
		if(one_commit && !(dispatch_1 && (head_index == tail_index)) &&
						 !(dispatch_2 && (head_index == tail_index_minus_1))
					  &&  (D_cache_success)) begin
			n_sq_entries[head_index].value_to_store       = 64'b0;
			n_sq_entries[head_index].value_to_store_PRN   = `ZERO_REG_PRN;
			n_sq_entries[head_index].valid				  = 0;
			n_sq_entries[head_index].stc_mem		      = 0;
			n_sq_entries[head_index].value_to_store_ready = 0;
			n_sq_entries[head_index].address_resolved     = 0;
			n_sq_entries[head_index].effective_address    = 64'b0;
			n_sq_entries[head_index].base_addr            = 64'b0;
			n_sq_entries[head_index].base_addr_ready      = 0;
			n_sq_entries[head_index].base_addr_PRN        =`ZERO_REG_PRN;
			n_sq_entries[head_index].PRN_dest			  =`ZERO_REG_PRN;
			n_sq_entries[head_index].offset               = 64'b0;
			n_sq_entries[head_index].ROB_index            = 5'b0;
		end
		/*if(two_commit && !(dispatch_2 && (head_index_minus_1 == tail_index_minus_1))) begin
			n_sq_entries[head_index_minus_1].value_to_store       = 64'b0;
			n_sq_entries[head_index_minus_1].value_to_store_PRN   = `ZERO_REG_PRN;
			n_sq_entries[head_index_minus_1].valid				  = 0;
			n_sq_entries[head_index_minus_1].stc_mem		      = 0;
			n_sq_entries[head_index_minus_1].value_to_store_ready = 0;
			n_sq_entries[head_index_minus_1].address_resolved     = 0;
			n_sq_entries[head_index_minus_1].effective_address    = 64'b0;
			n_sq_entries[head_index_minus_1].base_addr            = 64'b0;
			n_sq_entries[head_index_minus_1].base_addr_ready      = 0;
			n_sq_entries[head_index_minus_1].base_addr_PRN        = `ZERO_REG_PRN;
			n_sq_entries[head_index_minus_1].PRN_dest             = `ZERO_REG_PRN;
			n_sq_entries[head_index_minus_1].offset               = 64'b0;
			n_sq_entries[head_index_minus_1].ROB_index            = 5'b0;
		end*/
		/////////////////////////////////////////////////////////////////////////////////////////////

		if(first_dispatch) begin
			n_sq_entries[tail_index].value_to_store       = inst_in[0].value_to_store;
			n_sq_entries[tail_index].value_to_store_PRN   = inst_in[0].value_to_store_PRN;
			n_sq_entries[tail_index].valid				  = 1;
			n_sq_entries[tail_index].stc_mem			  = inst_in[0].stc_mem;
			n_sq_entries[tail_index].value_to_store_ready = inst_in[0].value_to_store_ready;
			n_sq_entries[tail_index].address_resolved     = 0;
			n_sq_entries[tail_index].effective_address    = 64'b0;
			n_sq_entries[tail_index].base_addr            = inst_in[0].base_addr;
			n_sq_entries[tail_index].base_addr_ready      = inst_in[0].base_addr_ready;
			n_sq_entries[tail_index].base_addr_PRN        = inst_in[0].base_addr_PRN;
			n_sq_entries[tail_index].PRN_dest             = inst_in[0].PRN_dest;
			n_sq_entries[tail_index].offset               = inst_in[0].offset;
			n_sq_entries[tail_index].ROB_index            = inst_in[0].ROB_index;
			n_eff_add_ready_list[tail_index]              = inst_in[0].base_addr_ready;

		end else if(second_dispatch) begin
			n_sq_entries[tail_index].value_to_store       = inst_in[1].value_to_store;
			n_sq_entries[tail_index].value_to_store_PRN   = inst_in[1].value_to_store_PRN;
			n_sq_entries[tail_index].valid				  = 1;
			n_sq_entries[tail_index].stc_mem			  = inst_in[1].stc_mem;
			n_sq_entries[tail_index].value_to_store_ready = inst_in[1].value_to_store_ready;
			n_sq_entries[tail_index].address_resolved     = 0;
			n_sq_entries[tail_index].effective_address    = 64'b0;
			n_sq_entries[tail_index].base_addr            = inst_in[1].base_addr;
			n_sq_entries[tail_index].base_addr_ready      = inst_in[1].base_addr_ready;
			n_sq_entries[tail_index].base_addr_PRN        = inst_in[1].base_addr_PRN;
			n_sq_entries[tail_index].PRN_dest             = inst_in[1].PRN_dest;
			n_sq_entries[tail_index].offset               = inst_in[1].offset;
			n_sq_entries[tail_index].ROB_index            = inst_in[1].ROB_index;
			n_eff_add_ready_list[tail_index]              = inst_in[1].base_addr_ready;
		end

		if(dispatch_2) begin
			n_sq_entries[tail_index_minus_1].value_to_store       = inst_in[1].value_to_store;
			n_sq_entries[tail_index_minus_1].value_to_store_PRN   = inst_in[1].value_to_store_PRN;
			n_sq_entries[tail_index_minus_1].valid				  = 1;
			n_sq_entries[tail_index_minus_1].stc_mem		      = inst_in[1].stc_mem;
			n_sq_entries[tail_index_minus_1].value_to_store_ready = inst_in[1].value_to_store_ready;
			n_sq_entries[tail_index_minus_1].address_resolved     = 0;
			n_sq_entries[tail_index_minus_1].effective_address    = 64'b0;
			n_sq_entries[tail_index_minus_1].base_addr            = inst_in[1].base_addr;
			n_sq_entries[tail_index_minus_1].base_addr_ready      = inst_in[1].base_addr_ready;
			n_sq_entries[tail_index_minus_1].base_addr_PRN        = inst_in[1].base_addr_PRN;
			n_sq_entries[tail_index_minus_1].PRN_dest             = inst_in[1].PRN_dest;
			n_sq_entries[tail_index_minus_1].offset               = inst_in[1].offset;
			n_sq_entries[tail_index_minus_1].ROB_index            = inst_in[1].ROB_index;
			n_eff_add_ready_list[tail_index_minus_1]              = inst_in[1].base_addr_ready;
		end

		//This logic will retire the stores in the SQ//////////////////////////////////////////////////
		//we will won't be commiting two intructions because the cache can only take in one instruction at a time
		if(two_commit && !mispredict) begin //wont happen
			//for head index plus one
			committed_store.valid[1]      = 1;
			committed_store.sq_index[1]   = head_index_minus_1;
			committed_store.sq_address[1] = sq_entries[head_index_minus_1].effective_address;
			committed_store.sq_value[1]   = sq_entries[head_index_minus_1].value_to_store;
			//for just the head index
			committed_store.valid[0]      = 1;
			committed_store.sq_index[0]   = head_index;
			committed_store.sq_address[0] = sq_entries[head_index].effective_address;
			committed_store.sq_value[0]   = sq_entries[head_index].value_to_store;
			ROB_index        = sq_entries[head_index].ROB_index;
			PRN_dest		 = sq_entries[head_index].PRN_dest;
			is_stc_mem		 = sq_entries[head_index].stc_mem;
			store_success    = 0;
			store_request    = 1;
			store_data       = 64'hDEAD_DEAD_DEAD_0000;
		    proc2Dcache_addr = 64'hDEAD_FFFF_DEAD_0000;
		end else if(one_commit && !mispredict) begin
			//for head index plus one
			committed_store.valid[1]      = 0;
			committed_store.sq_index[1]   = 4'b0;
			committed_store.sq_address[1] = 64'b0;
			committed_store.sq_value[1]   = 64'b0;
			
			//this send the data off to the cache
			ROB_index        = sq_entries[head_index].ROB_index;
			PRN_dest		 = sq_entries[head_index].PRN_dest;
			store_data       = sq_entries[head_index].value_to_store;
		    proc2Dcache_addr = sq_entries[head_index].effective_address;
		    is_stc_mem		 = sq_entries[head_index].stc_mem;
		    store_request    = 1;
		    //sometimes the cache will not always be a sucess so we must account for that
		    if(D_cache_success) begin
		    	store_success = 1;
		    	//for just the head index
				committed_store.valid[0]      = 1;
				committed_store.sq_index[0]   = head_index;
				committed_store.sq_address[0] = sq_entries[head_index].effective_address;
				committed_store.sq_value[0]   = sq_entries[head_index].value_to_store;
				n_head_index = head_index_minus_1;
				
				committed_for_real = 1;
		    end else begin
		    	store_success = 0;
		    	//for just the head index
				committed_store.valid[0]      = 0;
				committed_store.sq_index[0]   = 4'b0;
				committed_store.sq_address[0] = 64'b0;
				committed_store.sq_value[0]   = 64'b0;
				n_head_index = head_index;
		    end

		end else begin //if there is no commits you dont want to send anything out 
			//for head index plus one
			committed_store.valid[1]      = 0;
			committed_store.sq_index[1]   = 4'b0;
			committed_store.sq_address[1] = 64'b0;
			committed_store.sq_value[1]   = 64'b0;
			//for just the head index
			committed_store.valid[0]      = 0;
			committed_store.sq_index[0]   = 4'b0;
			committed_store.sq_address[0] = 64'b0;
			committed_store.sq_value[0]   = 64'b0;
			ROB_index        = sq_entries[head_index].ROB_index;
			PRN_dest		 = sq_entries[head_index].PRN_dest;
			is_stc_mem		 = sq_entries[head_index].stc_mem;
			store_request    = 0;
			store_success    = 0;
			store_data       = 64'hDEAD_DEAD_DEAD_DEAD;
		    proc2Dcache_addr = 64'hDEAD_FFFF_DEAD_FFFF;
		    n_head_index = head_index;
		end



		////////////////////////////////////////////////////////////////////////////////////////////////
        
        //This logic listens to the CDB to see if data is ready/////////////////////////////////////////
		 if(cdb0.valid) begin

	    	for(int i=0; i< `SQ_SIZE; i++) begin
	    		if((n_sq_entries[i].value_to_store_PRN == cdb0.PRN) && !n_sq_entries[i].value_to_store_ready && n_sq_entries[i].valid) begin
	    			n_sq_entries[i].value_to_store = cdb0.FU_result;
	    			n_sq_entries[i].value_to_store_ready = 1;
	    		end
	    		if((n_sq_entries[i].base_addr_PRN == cdb0.PRN) && !n_sq_entries[i].base_addr_ready && n_sq_entries[i].valid) begin
	    			n_sq_entries[i].base_addr = cdb0.FU_result;
	    			n_sq_entries[i].base_addr_ready = 1;
	    			n_eff_add_ready_list[i] = 1;
	    		end	
	    	end
	    end 

	    if(cdb1.valid) begin

	    	for(int i = 0; i < `SQ_SIZE; i++) begin
		    	if((n_sq_entries[i].value_to_store_PRN == cdb1.PRN) && !n_sq_entries[i].value_to_store_ready && n_sq_entries[i].valid) begin
		    		n_sq_entries[i].value_to_store = cdb1.FU_result;
		    		n_sq_entries[i].value_to_store_ready = 1;
		    	end
		    	if((n_sq_entries[i].base_addr_PRN == cdb1.PRN) && !n_sq_entries[i].base_addr_ready && n_sq_entries[i].valid) begin
		    		n_sq_entries[i].base_addr = cdb1.FU_result;
		    		n_sq_entries[i].base_addr_ready = 1;
		    		n_eff_add_ready_list[i] = 1;
		    	end
		    end		
	    end

	    //the count logic 
		if(!dispatch_2 && !dispatch_1) begin
			n_count = committed_for_real ? count - 1 : count;
		end			  
		if(dispatch_1) begin
			n_count = committed_for_real ? count     : count+1;
		end
		if(dispatch_2) begin
			n_count = committed_for_real ? count + 1 : count+2;
	    end

	    //full and almost full logic
	    n_full        = n_count >= `SQ_SIZE-2;
	    n_almost_full = n_count == `SQ_SIZE-3;
	    /////////////////////////////////////////////////////////////////////////////////////////////////////
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock)
	begin
		if(reset) begin
			for(int i = 0; i < `SQ_SIZE; i++) begin
				sq_entries[i].value_to_store       <= #1 64'b0;
				sq_entries[i].value_to_store_PRN   <= #1`ZERO_REG_PRN;
				sq_entries[i].valid				   <= #1 0;
				sq_entries[i].stc_mem              <= #1 0;
				sq_entries[i].value_to_store_ready <= #1 0;
				sq_entries[i].address_resolved     <= #1 0;
				sq_entries[i].effective_address    <= #1 64'b0;
				sq_entries[i].base_addr            <= #1 64'b0;
				sq_entries[i].base_addr_ready      <= #1 0;
				sq_entries[i].base_addr_PRN        <= #1`ZERO_REG_PRN;
				sq_entries[i].PRN_dest             <= #1`ZERO_REG_PRN;
				sq_entries[i].offset               <= #1 64'b0;
				sq_entries[i].ROB_index            <= #1 5'b0;
				eff_add_ready_list                 <= #1 0;
			end

			head_index  <= #1 `SQ_SIZE;
			tail_index  <= #1 `SQ_SIZE;
			count       <= #1 0;
			full 	    <= #1 0;
			almost_full <= #1 0;
		end else if(mispredict) begin
			for(int i = 0; i < `SQ_SIZE; i++) begin
				sq_entries[i].value_to_store       <= #1 64'b0;
				sq_entries[i].value_to_store_PRN   <= #1`ZERO_REG_PRN;
				sq_entries[i].valid				   <= #1 0;
				sq_entries[i].stc_mem              <= #1 0;
				sq_entries[i].value_to_store_ready <= #1 0;
				sq_entries[i].address_resolved     <= #1 0;
				sq_entries[i].effective_address    <= #1 64'b0;
				sq_entries[i].base_addr            <= #1 64'b0;
				sq_entries[i].base_addr_ready      <= #1 0;
				sq_entries[i].base_addr_PRN        <= #1`ZERO_REG_PRN;
				sq_entries[i].PRN_dest             <= #1`ZERO_REG_PRN;
				sq_entries[i].offset               <= #1 64'b0;
				sq_entries[i].ROB_index            <= #1 5'b0;
				eff_add_ready_list[i]              <= #1 0;
			end

			head_index  <= #1 `SQ_SIZE;
			tail_index  <= #1 `SQ_SIZE;
			count       <= #1 0;
			full 	    <= #1 0;
			almost_full <= #1 0;
		end else begin

			sq_entries          <= #1 n_sq_entries;
			head_index          <= #1 n_head_index;
			tail_index          <= #1 n_tail_index;
			count               <= #1 n_count;
			full                <= #1 n_full;
			eff_add_ready_list  <= #1 n_eff_add_ready_list;
			almost_full         <= #1 n_almost_full;

	    end
	end
endmodule