`timescale 1ns/100ps

module icache (
	input clock,
	input reset,

	input       smt_mode, 
	input [1:0] predicted_taken, 

	input   [3:0] Imem2proc_response,
	input  [63:0] Imem2proc_data,
	input   [3:0] Imem2proc_tag,

	input [1:0] [63:0] proc2Icache_addr,
	input [1:0] [63:0] cachemem_data,
	input        [1:0] cachemem_valid,

	input              active_thread,

	output logic [1:0] changed_addr, 

	output logic  [1:0] proc2Imem_command,
	output logic [63:0] proc2Imem_addr,

	output logic [1:0] [63:0] Icache_data_out,     // value is memory[proc2Icache_addr]
	output logic        [1:0] Icache_valid_out,    // when this is high

	output logic [1:0] [`NUM_PREFETCH-1:0] [`MEM_TAG_BITS-1:0] tag_arr, 
	output logic [1:0] [`NUM_PREFETCH-1:0]    [`ADDR_BITS-1:0] addr_arr, 

	output logic [1:0] [`PREFETCH_BITS:0] head_index, 
	output logic [1:0] [`PREFETCH_BITS:0] tail_index, 

	output logic [1:0] [63:0] request,
	output logic              curr_thread, 

	output logic [1:0] [4:0] rd_index,
	output logic [1:0] [7:0] rd_tag,
	output logic       [4:0] wr_index,
	output logic       [7:0] wr_tag,
	output logic             wr_en

);
	logic [1:0] [`NUM_PREFETCH-1:0] [`MEM_TAG_BITS-1:0] n_tag_arr;
	logic [1:0] [`NUM_PREFETCH-1:0]    [`ADDR_BITS-1:0] n_addr_arr;
	
	logic [1:0] [`PREFETCH_BITS:0] n_head_index, n_tail_index;

	logic [1:0] [63:0] n_request;
	logic [1:0]  [4:0] last_index;
	logic [1:0]  [7:0] last_tag;

	logic [1:0] stop, prefetch_full, prev_cachemem_valid;
	logic       ready, n_thread;

	logic [`PREFETCH_BITS:0] prefetch_depth;

	assign prefetch_depth = smt_mode ? `SMT_NUM_PREFETCH : `NUM_PREFETCH;

	assign stop[0] = tail_index[0]>=prefetch_depth;
	assign stop[1] = tail_index[1]>=prefetch_depth;

	always_comb begin
		n_thread = smt_mode ? !curr_thread : 0;

		for(int i=0; i<2; i++) begin 
			{rd_tag[i], rd_index[i]} = proc2Icache_addr[i][31:3];
			changed_addr[i]          = (rd_index[i]!=last_index[i]) || (rd_tag[i]!=last_tag[i]);
			Icache_data_out[i]       = cachemem_data[i];
			Icache_valid_out[i]      = cachemem_valid[i];
		end

		wr_en    = 0;
		wr_tag   = 0;
		wr_index = 0;

		n_head_index = head_index;
		n_tail_index = tail_index;
		n_tag_arr    = tag_arr;
		n_addr_arr   = addr_arr;
		n_request    = request;

		for(int i=0; i<2; i++) begin
			prefetch_full[i] = head_index[i]==`NUM_PREFETCH && tail_index[i]==`NUM_PREFETCH;

			if((prev_cachemem_valid[i] || changed_addr[i]) && !cachemem_valid[i]) begin
				n_head_index[i] = 0;
				n_tail_index[i] = 0;
				n_tag_arr[i]    = 0;
				n_addr_arr[i]   = 0;
				n_request[i]    = proc2Icache_addr[i];
			end
		end

		for(int i=0; i<2; i++) begin
			if(Imem2proc_tag && Imem2proc_tag==n_tag_arr[i][n_head_index[i]]) begin 
				wr_en              = 1;
				{wr_tag, wr_index} = addr_arr[i][head_index[i]][31:3]; 

				n_head_index[i]              = head_index[i] + 1;
				n_tag_arr[i][head_index[i]]  = 0;
				n_addr_arr[i][head_index[i]] = 0;
			end	
		end

		proc2Imem_command = !stop[curr_thread] && ready ? BUS_LOAD : BUS_NONE;
		proc2Imem_addr    = {n_request[curr_thread][63:3],3'b0};

		for(int i=0; i<2; i++) begin
			if(Imem2proc_response && curr_thread==i) begin
				n_tag_arr[i][n_tail_index[i]]  = Imem2proc_response;
				n_addr_arr[i][n_tail_index[i]] = n_request[i];

				n_request[i]    = request[i] + 8;
				n_tail_index[i] = tail_index[i] + 1;
			end
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			last_index  <= `SD -1;
			last_tag    <= `SD -1;
			request     <= `SD 0;
			head_index  <= `SD 0;
			tail_index  <= `SD 0;
			tag_arr     <= `SD 0;
			addr_arr    <= `SD 0;
			ready       <= `SD 1;
			curr_thread <= `SD 0;
			prev_cachemem_valid <= `SD 3;

		end else begin
			last_index  <= `SD rd_index;
			last_tag    <= `SD rd_tag;
			request     <= `SD n_request;
			head_index  <= `SD n_head_index;
			tail_index  <= `SD n_tail_index;
			tag_arr     <= `SD n_tag_arr;
			addr_arr    <= `SD n_addr_arr;
			curr_thread <= `SD n_thread;
			prev_cachemem_valid <= `SD cachemem_valid;
		end
	end
endmodule
