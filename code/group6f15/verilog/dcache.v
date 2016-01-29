`timescale 1ns/100ps

module dcache (
	input clock,
	input reset,
	input [1:0] nuke,

	////////////////   INPUTS  ///////////////////////////////////////////////////////////////////
	// From Memory (*** CANNOT BE CHANGED IN ANY WAY)
	input   [3:0]   Dmem2proc_response,
	input  [63:0]   Dmem2proc_data,
	input   [3:0]   Dmem2proc_tag,

	// From request 1
	input LSQ_DCACHE  lsq_request_1,
	
	// From D-Cache (cache output 1)				
	input  [63:0]   Dcache_data_1, 				 
	input           Dcache_valid_1,	
		 
	///////////////  OUTPUTS  /////////////////////////////////////////////////////////////////////////
	// To Memory  (*** CANNOT BE CHANGED IN ANY WAY)
	output BUS_COMMAND   proc2Dmem_command,
	output logic [63:0]  proc2Dmem_addr,
	output logic [63:0]  proc2Dmem_data,

	// To LSQ  (1) 	
	output logic         Mem_request_failed,
	output DCACHE_LSQ    current_response, 
	output DCACHE_LSQ    LB_response,		// response to LB


	// To D-Cache (1)
	output  logic [`INDEX_BITS-1:0]   wr1_req_idx,		  			
	output  logic [`TAG_BITS-1:0]   wr1_req_tag, 
	output  logic [63:0]  wr1_req_data,
		
	output  logic [`INDEX_BITS-1:0]   wr1_missed_load_idx,		  			
	output  logic [`TAG_BITS-1:0]   wr1_missed_load_tag, 

	output  logic	      wr1_req_en,		// write enable for request from SQ
	output  logic	      wr1_missed_load_en,	// write enable for missed load (when the data arrives from Memory to cache)

	output  logic [`INDEX_BITS-1:0]   rd1_idx,  				
	output  logic [`TAG_BITS-1:0]   rd1_tag,
	output  CACHE_COMMAND  		 proc2Dcache_command_1 	// to be able to distinguish BUS_NONE and BUS_LOAD for updating pseudo_LRU_bits					
);

	// Debugging
	REQ_BUFF [1:0] [`REQ_BUFF_SIZE-1:0] Request_buff; 	// when you get a miss; allocate a request buffer

	// Additional Signals for FIFO
	logic [1:0] [`REQ_BUFF_BITS-1:0] head_index;  
	logic [1:0] [`REQ_BUFF_BITS-1:0] tail_index;  
	logic [1:0] [`REQ_BUFF_BITS:0]   count;

	// When you get a load miss, put the missed load in Request buffer (missed load queue) 
	REQ_BUFF [1:0] [`REQ_BUFF_SIZE-1:0] n_Request_buff; 

	// variables for FIFO 
	logic [1:0] [`REQ_BUFF_BITS-1:0] n_head_index, n_tail_index;
	logic [1:0] [`REQ_BUFF_BITS:0]   n_count;
	logic [1:0]                      inc_count, dec_count;
	logic                            mispredicted_request;

	assign {rd1_tag, rd1_idx} = lsq_request_1.addr[31:3];

	// To LSQ  (1)
	assign current_response.data      = Dcache_data_1;
	assign current_response.index     = lsq_request_1.index;
	assign current_response.thread_ID = lsq_request_1.thread_ID;
	assign mispredicted_request       = (lsq_request_1.thread_ID && nuke[1]) || (!lsq_request_1.thread_ID && nuke[0]);
	assign current_response.valid     = lsq_request_1.command==BUS_LOAD && !mispredicted_request && Dcache_valid_1; 
	
	assign Mem_request_failed 	      = Dmem2proc_response == 4'h0;

	// To Memory 
	assign proc2Dmem_addr = {lsq_request_1.addr[63:3],3'b0};
	assign proc2Dmem_data = lsq_request_1.data;
	
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	always_comb begin
		// no need to check for mispredicted stores since lsq_request_1.command==BUS_STORE iff stq is at the head of the ROB
		if(lsq_request_1.command==COMMAND_STORE) begin
			proc2Dmem_command = BUS_STORE;			// write-through cache. So always write
		end
		else if(lsq_request_1.command==COMMAND_LOAD && !Dcache_valid_1 && !mispredicted_request) begin
			proc2Dmem_command = BUS_LOAD;
		end
		else begin
			proc2Dmem_command = BUS_NONE;
		end

        proc2Dcache_command_1 = lsq_request_1.command;

		n_Request_buff = Request_buff;
		n_count	       = count;
		n_head_index   = head_index;
		n_tail_index   = tail_index;
		inc_count      = 0;
		dec_count      = 0;

		for(int i=0; i<2; i++) begin
			// Puts data in the Request Buffer, in case of a Load Miss
			if(proc2Dmem_command==BUS_LOAD && !Mem_request_failed && lsq_request_1.thread_ID==i) begin
				inc_count[i]                              = 1;
				n_tail_index[i]                           = tail_index[i] + 1;
				n_Request_buff[i][tail_index[i]].LB_index = lsq_request_1.index;
				n_Request_buff[i][tail_index[i]].addr     = proc2Dmem_addr;	
				n_Request_buff[i][tail_index[i]].tag      = Dmem2proc_response;	 
			end
		end

		// Reponse to LB
		LB_response.data      = Dmem2proc_data;
		LB_response.index     = 0;
		LB_response.thread_ID = 0;
		LB_response.valid     = 0;
		
		// Store data into cache. Find the address of arriving tag from the Request Buffer
		{wr1_missed_load_tag, wr1_missed_load_idx} = 0;
		wr1_missed_load_en = 0;

		for(int i=0; i<2; i++) begin
			// (Handle the Missed Load) when the data comes back from Mem 
			if(Dmem2proc_tag!=4'h0 && Dmem2proc_tag==Request_buff[i][head_index[i]].tag && !nuke[i]) begin
				{wr1_missed_load_tag, wr1_missed_load_idx} = Request_buff[i][head_index[i]].addr[31:3];

				dec_count[i]    = 1;
				n_head_index[i] = head_index[i] + 1;
				
				LB_response.index     = Request_buff[i][head_index[i]].LB_index;
				LB_response.thread_ID = i;
				LB_response.valid     = 1;		// send necessary info back to LB so that it knows op was serviced
				wr1_missed_load_en    = 1;  // STORE_FROM_MEM

				// Empty out the Request_buff (for debugging)
				n_Request_buff[i][head_index[i]].LB_index = 0;
				n_Request_buff[i][head_index[i]].addr     = 0;	
				n_Request_buff[i][head_index[i]].tag      = 0;
			end	
		end

		// handling store request
		{wr1_req_tag, wr1_req_idx} = lsq_request_1.addr[31:3];	
		wr1_req_data	    	   = lsq_request_1.data;	// data from cache write request
		wr1_req_en                 = proc2Dmem_command==BUS_STORE && !Mem_request_failed; 

		// update the count
		for(int i=0; i<2; i++) begin
			if(inc_count[i] && dec_count[i])
				n_count[i] = count[i];
			else if(inc_count[i])
				n_count[i] = count[i] + 1;
			else if(dec_count[i])
				n_count[i] = count[i] - 1;
			else
				n_count[i] = count[i];
		end
	end

	
  	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0; i<2; i++) begin
				for(int j=0; j<`REQ_BUFF_SIZE; j++) begin
					Request_buff[i][j].LB_index <= #1 0;
					Request_buff[i][j].addr     <= #1 0;
					Request_buff[i][j].tag      <= #1 0;  // Dmem2proc_response
				end          
				count[i]      <= #1 0;
				head_index[i] <= #1 0;
				tail_index[i] <= #1 0;
			end
		end else begin

			for(int i=0; i<2; i++) begin
				if(nuke[i]) begin
					for(int j=0; j<`REQ_BUFF_SIZE; j++) begin
						Request_buff[i][j].LB_index <= #1 0;
						Request_buff[i][j].addr     <= #1 0;
						Request_buff[i][j].tag      <= #1 0;  // Dmem2proc_response
					end          
					count[i]      <= #1 0;
					head_index[i] <= #1 0;
					tail_index[i] <= #1 0;
			
				end else begin
					Request_buff[i] <= #1 n_Request_buff[i];		
					count[i]        <= #1 n_count[i];
					head_index[i]   <= #1 n_head_index[i];
					tail_index[i]   <= #1 n_tail_index[i];
				end
			end

		end
	end
endmodule