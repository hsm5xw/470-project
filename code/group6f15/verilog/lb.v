`timescale 1ns/100ps

module lb #(parameter THREAD_ID=0) (
	input                      clock,
	input                      reset,

	input                      Dcache_valid, // if valid, use the data
	input               [63:0] Dcache_data, 
	input       [`LB_BITS-1:0] Dcache_index,
	input                      Dcache_req_successful, // If the request is rejected, resend the request

	input                      Memory_valid, // Data comes from memory due to cache miss
	input               [63:0] Memory_data,
	input       [`LB_BITS-1:0] Memory_index,

	input CDB                  CDB_0, 
	input CDB                  CDB_1, 
	input SQ_ADDER_DATA        resolved_store, // Once a store computes its address, broadcast to loads to check dependencies
	input SQ_ALL_DATA          all_stores,
	input SQ_RETIRED_DATA      committed_store, 
	input DISPATCH_LSQ   [1:0] inst_in,

	input       [`SQ_BITS-1:0] sq_head_index,
	input       [`SQ_BITS-1:0] sq_tail_index,
	input                      mispredict,

	output logic               load_req_is_ldl_mem,
	output logic               almost_full,
	output logic               full,
	output logic               valid_request, // valid request to the Dcache
	output logic[`LB_BITS-1:0] proc2Dcache_index, // Index of the LB that is making the request
	output logic        [63:0] proc2Dcache_addr,

	output FU_RESULT           output_to_CDB,
	output logic			   output_ldl_mem, // output with cdb stuff
	output logic        [63:0] output_addr,
	output logic  [`LB_BITS:0] count
);

	LB_DATA [`LB_SIZE-1:0] entries; 
	logic   [`LB_SIZE-1:0] free_list; 
	logic   [`LB_SIZE-1:0] base_addr_ready_list;
	logic   [`LB_SIZE-1:0] ready_to_go_list; 
	logic   [`LB_SIZE-1:0] ready_cdb_list; 
	logic   [`LB_BITS-1:0] base_addr_ready_index; 
	logic   [`LB_BITS-1:0] ready_to_go_index; 
	logic   [`LB_BITS-1:0] ready_cdb_index;

	LB_DATA     [`LB_SIZE-1:0] n_entries;
	logic [1:0] [`SQ_BITS-1:0] upper_bounds, lower_bounds; // current head and tail
	logic                [1:0] allocate_entry; // bit vector to decide 
	logic       [`SQ_BITS-1:0] sq_tail_index_minus1;

	logic       [`LB_SIZE-1:0] n_free_list, n_base_addr_ready_list, n_ready_to_go_list, n_ready_cdb_list; 

	logic       [`LB_SIZE-1:0] free_gnt, base_addr_ready_gnt, ready_to_go_gnt, ready_cdb_gnt;

	logic [1:0] [`LB_SIZE-1:0] free_gnt_bus;
	logic       [`LB_SIZE-1:0] base_addr_ready_gnt_bus, ready_to_go_gnt_bus, ready_cdb_gnt_bus;
	logic                      free_empty, base_addr_ready_empty, ready_to_go_empty, ready_cdb_empty;

	logic [1:0] [`LB_BITS-1:0] free_index;

	logic                [1:0] count_inc, count_increment;
	logic                      count_dec;
	logic                      n_full, n_almost_full;
	logic         [`LB_BITS:0] n_count;
	logic                      valid_address, count_dec_invalid;

	// Disptach priority selector and encoder
	psel_gen #(.REQS(2), .WIDTH(`LB_SIZE)) dispatch_priority_selector (
		.req(free_list),
		.gnt(free_gnt),
		.gnt_bus(free_gnt_bus), 
		.empty(free_empty)
	);

	pe #(.OUT_WIDTH(`LB_BITS), .IN_WIDTH(`LB_SIZE)) dispatch_encoded [1:0] (
		.gnt(free_gnt_bus),
		.enc(free_index)
	);

	// Adder priority selector and encoder
	psel_gen #(.REQS(1), .WIDTH(`LB_SIZE)) adder_priority_selector (
		.req(base_addr_ready_list),
		.gnt(base_addr_ready_gnt),
		.gnt_bus(base_addr_ready_gnt_bus), 
		.empty(base_addr_ready_empty)
	);

	pe #(.OUT_WIDTH(`LB_BITS), .IN_WIDTH(`LB_SIZE)) adder_encoded (
		.gnt(base_addr_ready_gnt_bus),
		.enc(base_addr_ready_index)
	);

	// D-cache requests 
	psel_gen #(.REQS(1), .WIDTH(`LB_SIZE)) d_cache_priority_selector (
		.req(ready_to_go_list),
		.gnt(ready_to_go_gnt),
		.gnt_bus(ready_to_go_gnt_bus), 
		.empty(ready_to_go_empty)
	);

	pe #(.OUT_WIDTH(`LB_BITS), .IN_WIDTH(`LB_SIZE)) d_cache_encoded (
		.gnt(ready_to_go_gnt_bus),
		.enc(ready_to_go_index)
	);

	// Broadcast the load's values when it gets it
	psel_gen #(.REQS(1), .WIDTH(`LB_SIZE)) cdb_priority_selector (
		.req(ready_cdb_list),
		.gnt(ready_cdb_gnt),
		.gnt_bus(ready_cdb_gnt_bus), 
		.empty(ready_cdb_empty)
	);

	pe #(.OUT_WIDTH(`LB_BITS), .IN_WIDTH(`LB_SIZE)) cdb_encoded (
		.gnt(ready_cdb_gnt_bus),
		.enc(ready_cdb_index)
	);

	always_comb begin
		load_req_is_ldl_mem  = 0;

		allocate_entry[0]    = inst_in[0].dispatch && inst_in[0].rd_mem && inst_in[0].thread_ID == THREAD_ID;
		upper_bounds[0]      = sq_head_index;
		lower_bounds[0]      = sq_tail_index;

		sq_tail_index_minus1 = sq_tail_index - 1;
		allocate_entry[1]    = inst_in[1].dispatch && inst_in[1].rd_mem && inst_in[1].thread_ID == THREAD_ID;
		upper_bounds[1]      = sq_head_index;
		lower_bounds[1]      = inst_in[0].dispatch && inst_in[0].wr_mem && inst_in[0].thread_ID == THREAD_ID ? sq_tail_index_minus1 : sq_tail_index;

		n_entries              = entries;
		n_free_list            = free_list;
		n_base_addr_ready_list = base_addr_ready_list;
		n_ready_to_go_list     = ready_to_go_list;
		n_ready_cdb_list       = ready_cdb_list;

		n_count   = count;
		count_dec = 0; 
		count_inc = 0;

		count_dec_invalid = 0;

		// Dispatch into the LB
		for(int j=0; j<2; j++) begin
			if(allocate_entry[j]) begin
				count_increment[j] = 1'b1;

				n_free_list[free_index[j]] = 1'b0;
				n_base_addr_ready_list[free_index[j]]      = inst_in[j].base_addr_ready;

				n_entries[free_index[j]].ldl_mem           = inst_in[j].ldl_mem;
				n_entries[free_index[j]].request_succeed   = 1'b0;
				n_entries[free_index[j]].thread_ID         = inst_in[j].thread_ID;
				n_entries[free_index[j]].address_resolved  = 1'b0;
				n_entries[free_index[j]].effective_address = 64'b0;
				n_entries[free_index[j]].base_addr         = inst_in[j].base_addr;
				n_entries[free_index[j]].base_addr_ready   = inst_in[j].base_addr_ready;
				n_entries[free_index[j]].base_addr_PRN     = inst_in[j].base_addr_PRN;
				n_entries[free_index[j]].offset            = inst_in[j].offset;
				n_entries[free_index[j]].data_from_cache   = 64'hDEAD_DEAD_DEAD_DEAD;
				n_entries[free_index[j]].PRN_dest          = inst_in[j].PRN_dest;
				n_entries[free_index[j]].ROB_index         = inst_in[j].ROB_index;

				// Update the load's relationship to stores currently in the SQ
				// It only listens to the stores between the SQ's head and tail pointer.
				// Other stores are ignored (not dependent by order)
				for(int k=0; k<`SQ_SIZE; k++) begin
					if(upper_bounds[j]>lower_bounds[j] && k<=upper_bounds[j] && k>lower_bounds[j]) begin
						n_entries[free_index[j]].sq_status[k] = UNKNOWN;

					end else if(upper_bounds[j]<lower_bounds[j] && (k<=upper_bounds[j] || k>lower_bounds[j])) begin
						n_entries[free_index[j]].sq_status[k] = UNKNOWN;

					end else begin
						n_entries[free_index[j]].sq_status[k] = NOT_DEP_BY_ORDER;
					end
				end
			end else begin
				count_increment[j] = 1'b0;
			end
		end

		// CDB Broadcast to the load buffer
		if(CDB_0.valid || CDB_1.valid) begin
			for(int j=0; j<`LB_SIZE; j++) begin

				// If the entry is occupied and the PRN matches, assign the base address
				if(CDB_0.valid && !n_free_list[j] && (CDB_0.PRN == n_entries[j].base_addr_PRN)) begin
					n_entries[j].base_addr_ready = 1'b1;
					n_entries[j].base_addr       = CDB_0.FU_result;
					n_base_addr_ready_list[j]    = 1'b1;
				end

				if(CDB_1.valid && !n_free_list[j] && (CDB_1.PRN == n_entries[j].base_addr_PRN)) begin
					n_entries[j].base_addr_ready = 1'b1;
					n_entries[j].base_addr       = CDB_1.FU_result;
					n_base_addr_ready_list[j]    = 1'b1;
				end
			end
		end

		// Do 1 addition. Once the address has been computed, compare it to all the stores in the SQ.
		if(!base_addr_ready_empty && !free_list[base_addr_ready_index]) begin
			
			n_entries[base_addr_ready_index].effective_address = entries[base_addr_ready_index].offset + 
			                                                     entries[base_addr_ready_index].base_addr;

            n_base_addr_ready_list[base_addr_ready_index]      = 1'b0;
            n_entries[base_addr_ready_index].address_resolved  = 1'b1;

            // Once the address is computed, it is ready to go to the D-cache.
            // If there are dependent or unknown stores, it cannot go... done below
            //n_ready_to_go_list[base_addr_ready_index] = 1'b1;
           
           	// Recheck the load's relationship to all the stores in SQ once the address has been resolved.
           	// If there are any unknown or dependent stores, the load cannot go to D-cache
            for(int j=0; j<`SQ_SIZE; j++) begin
            	if(entries[base_addr_ready_index].sq_status[j] == NOT_DEP_BY_ORDER) begin
            		// if it is not dependent on the store, do nothing

            	// If the store is unresolved or is a stc_mem, update the status as UNKNOWN
            	end else if(all_stores.valid[j] && !all_stores.address_resolved[j] || all_stores.stc_mem[j]) begin
            		n_entries[base_addr_ready_index].sq_status[j] = UNKNOWN;
            		//n_ready_to_go_list[base_addr_ready_index]     = 1'b0;

            	end else if(all_stores.valid[j] && all_stores.address_resolved[j] && 
            		        all_stores.address[j] == n_entries[base_addr_ready_index].effective_address) begin
            		n_entries[base_addr_ready_index].sq_status[j] = DEPENDENT;
            		//n_ready_to_go_list[base_addr_ready_index]     = 1'b0;

        		end else begin
        			n_entries[base_addr_ready_index].sq_status[j] = NOT_DEP_BY_ADDR;
        		end            	
            end

            valid_address = (n_entries[base_addr_ready_index].effective_address[2:0]==3'b0) && 
			                (n_entries[base_addr_ready_index].effective_address<`MEM_SIZE_IN_BYTES);

            if(!valid_address) begin
            	n_ready_cdb_list[base_addr_ready_index]           = 1'b0;
				n_free_list[base_addr_ready_index]                = 1'b1;
				n_entries[base_addr_ready_index].sq_status        = 1'b0;
				n_entries[base_addr_ready_index].address_resolved = 1'b0;
				count_dec_invalid = 1'b1;
            end
		end

		// Update the all load's relationship to the recently broadcasted store
		if(resolved_store.valid) begin
			for(int j=0; j<`LB_SIZE; j++) begin
				if(n_entries[j].sq_status[resolved_store.sq_index]==NOT_DEP_BY_ORDER || n_free_list[j]) begin
					// if it is not dependent by order, broadcasted store means nothing
					// n_ready_to_go_list[j] = 1'b1; // this might happen in the wrong place, but it works for now

				// Store conditionals are always treated as unknown stores
				end else if(resolved_store.stc_mem) begin
					n_entries[j].sq_status[resolved_store.sq_index] = UNKNOWN;

				end else if(n_entries[j].address_resolved && (n_entries[j].effective_address == resolved_store.sq_address)) begin
					n_entries[j].sq_status[resolved_store.sq_index] = DEPENDENT;

				end else if(n_entries[j].address_resolved && (n_entries[j].effective_address != resolved_store.sq_address)) begin
					n_entries[j].sq_status[resolved_store.sq_index] = NOT_DEP_BY_ADDR;
					// n_ready_to_go_list[j] = 1'b1; // this might happen in the wrong place, but it works for now

				end else begin
					n_entries[j].sq_status[resolved_store.sq_index] = UNKNOWN;
				end
			end
		end

		// Update the committed stores' entries in the LB (zero them out)
		for(int j=0; j<2; j++) begin
			if(committed_store.valid[j]) begin
				for(int k=0; k<`LB_SIZE; k++) begin
					if(!n_free_list[k])
						n_entries[k].sq_status[committed_store.sq_index[j]] = NOT_DEP_BY_ORDER;
				end
			end
		end

		// Select a resolved load that is eligible to make a request to memory
		if(!ready_to_go_empty && !mispredict && !free_list[ready_to_go_index]) begin
			valid_request     = 1'b1;
			proc2Dcache_addr  = n_entries[ready_to_go_index].effective_address;
			proc2Dcache_index = ready_to_go_index;

			load_req_is_ldl_mem = n_entries[ready_to_go_index].ldl_mem;

		end else begin
			valid_request     = 1'b0;
			proc2Dcache_addr  = 64'hDEAD_FACE_DEAD_BEAD;
			proc2Dcache_index = 0;

		end

		if(Dcache_req_successful) begin
			n_ready_to_go_list[ready_to_go_index]        = 1'b0;
			n_entries[ready_to_go_index].request_succeed = 1'b1;
		end

		// If there is a valid response from the d-cache, use the data to update the load's data
		if(Dcache_valid && !free_list[Dcache_index]) begin
			n_entries[Dcache_index].data_from_cache = Dcache_data;
			n_ready_to_go_list[Dcache_index]        = 1'b0;
			n_ready_cdb_list[Dcache_index]          = 1'b1;
			n_entries[Dcache_index].request_succeed = 1'b1;

		// If it is a cache miss, it will go get the data from memory
		end

		// If there is valid data from memory, use it
		if(Memory_valid && !mispredict && !free_list[Memory_index]) begin
			n_ready_to_go_list[Memory_index] = 1'b0;
			n_entries[Memory_index].data_from_cache = Memory_data;
			n_ready_cdb_list[Memory_index] = 1'b1;
			//n_entries[Memory_index].request_succeed = 1'b1;
		end

		// Update which loads can make a request to the d-cache
		// If there are dependent or unknown stores in the SQ, or if the load
		// has already made a request, don't update the list
		for(int j=0; j<`LB_SIZE; j++) begin

			n_ready_to_go_list[j] = n_entries[j].address_resolved && !n_entries[j].request_succeed;

			for(int k=0; k<`SQ_SIZE; k++) begin
				if(n_entries[j].sq_status[k] == DEPENDENT || n_entries[j].sq_status[k] == UNKNOWN) begin
					n_ready_to_go_list[j] = 1'b0;
				end
			end
		end

		// If a load's data is ready, broadcast to the CDB
		if(!ready_cdb_empty && !mispredict && !free_list[ready_cdb_index]) begin
			output_to_CDB.result    = entries[ready_cdb_index].data_from_cache;			
			output_to_CDB.PRN_index = entries[ready_cdb_index].PRN_dest;			
			output_to_CDB.ROB_index = entries[ready_cdb_index].ROB_index;
			output_to_CDB.thread_ID = entries[ready_cdb_index].thread_ID;
			output_to_CDB.FU_done   = 1'b1;
			output_ldl_mem          = entries[ready_cdb_index].ldl_mem;
			output_addr             = entries[ready_cdb_index].effective_address;

			n_ready_cdb_list[ready_cdb_index]    = 1'b0;
			n_free_list[ready_cdb_index]         = 1'b1;
			n_entries[ready_cdb_index].sq_status = 1'b0;
			n_entries[ready_cdb_index].address_resolved = 1'b0;
			count_dec = 1'b1;
		end else begin
			output_to_CDB.result    = 64'hDEAD_DEAD_DEAD_DEAD;   
			output_to_CDB.PRN_index = 0;
			output_to_CDB.ROB_index = 0;
			output_to_CDB.thread_ID = 1'b0;
			output_to_CDB.FU_done   = 1'b0;

			output_ldl_mem          = 1'b0;
			output_addr             = 64'b0;

			count_dec = 1'b0;
		end

		case(count_increment)
			2'b00:   count_inc = 2'b00;
			2'b01:   count_inc = 2'b01;
			2'b10:   count_inc = 2'b01;
			2'b11:   count_inc = 2'b10;
			//default: count_inc = 2'b00;
		endcase

		n_count       = count + count_inc - count_dec - count_dec_invalid;
		n_full        = n_count >= `LB_SIZE - 2;
		n_almost_full = n_count == `LB_SIZE - 3;
		
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock)
	begin
		if(reset) begin
			for(int j=0; j<`LB_SIZE; j++) begin
				entries[j].ldl_mem           <= #1 0;
				entries[j].request_succeed   <= #1 0;
				entries[j].sq_status         <= #1 0;
				entries[j].thread_ID         <= #1 0;
				entries[j].address_resolved  <= #1 0;
				entries[j].effective_address <= #1 64'b0;
				entries[j].base_addr         <= #1 64'b0;

				entries[j].base_addr_ready <= #1 0;
				entries[j].base_addr_PRN   <= #1 `ZERO_REG_PRN;
				entries[j].offset          <= #1 64'b0;
				entries[j].data_from_cache <= #1 64'b0;
				entries[j].PRN_dest        <= #1 `ZERO_REG_PRN;
				entries[j].ROB_index       <= #1 0;
			end

			free_list            <= #1 {`LB_SIZE{1'b1}};
			base_addr_ready_list <= #1 0;
			ready_to_go_list     <= #1 0;
			ready_cdb_list       <= #1 0;
			count                <= #1 0;
			full                 <= #1 0;
			almost_full          <= #1 0;

		end else if(mispredict) begin
			for(int j=0; j<`LB_SIZE; j++) begin
				entries[j].ldl_mem           <= #1 0;
				entries[j].request_succeed   <= #1 0;
				entries[j].sq_status         <= #1 0;
				entries[j].thread_ID         <= #1 0;
				entries[j].address_resolved  <= #1 0;
				entries[j].effective_address <= #1 64'b0;
				entries[j].base_addr         <= #1 64'b0;

				entries[j].base_addr_ready <= #1 0;
				entries[j].base_addr_PRN   <= #1 `ZERO_REG_PRN;
				entries[j].offset          <= #1 64'b0;
				entries[j].data_from_cache <= #1 64'b0;
				entries[j].PRN_dest        <= #1 `ZERO_REG_PRN;
				entries[j].ROB_index       <= #1 0;
			end

			free_list            <= #1 {`LB_SIZE{1'b1}};
			base_addr_ready_list <= #1 0;
			ready_to_go_list     <= #1 0;
			ready_cdb_list       <= #1 0;
			count                <= #1 0;
			full                 <= #1 0;
			almost_full          <= #1 0;
		end else begin
			entries              <= #1 n_entries;
			free_list            <= #1 n_free_list;
			base_addr_ready_list <= #1 n_base_addr_ready_list;
			ready_to_go_list     <= #1 n_ready_to_go_list;
			ready_cdb_list       <= #1 n_ready_cdb_list;
			count                <= #1 n_count;
			full                 <= #1 n_full;
			almost_full          <= #1 n_almost_full;
		end
	end
endmodule