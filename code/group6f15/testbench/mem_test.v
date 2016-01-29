extern void print_start_cycle();
extern void print_end_cycle();
extern void increment_cycle();
extern void print_header(string str);
extern void print_dcache_line(string s, int n);
extern void print_dcache_empty_line();
extern void print_dcache_entry(int i, int valid, int tag, int data);
extern void print_buffer_request_entry(int i, int addr, int response);
extern void print_lb0_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN);
extern void print_sq0_entry(int i, int ready, int value, int base_addr_PRN);
extern void print_lb1_entry(int i, int available, int base_addr_ready, int ready_to_go, int ready_cdb, int base_addr_PRN);
extern void print_sq1_entry(int i, int ready, int value, int base_addr_PRN);

module testbench();

	logic clock;
	logic reset;

	logic nuke0;
	logic nuke1;

	logic   [3:0] Dmem2proc_response;
	logic  [63:0] Dmem2proc_data;
	logic   [3:0] Dmem2proc_tag;

	LSQ_DCACHE  lsq_request_1;

	logic  [63:0] Dcache_data_1; 		// data received from Dcache 
	logic         Dcache_valid_1;		// is the data valid ?  


	BUS_COMMAND  proc2Dmem_command;
	logic [63:0] proc2Dmem_addr;
	logic [63:0] proc2Dmem_data;		


	logic  [63:0] Dcache_data_out_1;   	// value is memory[proc2Dcache_addr]
	logic         Dcache_valid_out_1;  	// when this is high
	logic         Mem_request_failed;

	logic [4:0]   wr1_req_idx;		// write request from SQ
	logic [7:0]   wr1_req_tag; 		
	logic [63:0]  wr1_req_data;		

	logic [4:0]   wr1_missed_load_idx;		  			
	logic [7:0]   wr1_missed_load_tag;

	logic	      wr1_req_en;		// write enable for request from SQ
	logic	      wr1_missed_load_en;	// write enable for missed load (when the data arrives from Memory to cache)

	logic [4:0]   rd1_idx;  		// read  index
	logic [7:0]   rd1_tag;  		// read  tag

	DCACHE_LSQ    LB_response;		// response to LB	


	REQUEST_BUFFER [`REQ_BUFF_SIZE-1:0]   Request_buff; 	// when you get a miss, allocate a request buffer

	logic [`REQ_BUFF_BITS-1:0] head_index;  
	logic [`REQ_BUFF_BITS-1:0] tail_index;  
	logic [`REQ_BUFF_BITS:0]   count;       
	logic 			   full;      		  
		  
	logic [31:0] [63:0] cachemem_data;
	logic [31:0]  [7:0] cachemem_tags; 
	logic [31:0]        cachemem_valids;

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	CDB cdb_0;
	CDB cdb_1;

	logic [`ROB_BITS-1:0] ROB_0_head_index;
	logic [`ROB_BITS-1:0] ROB_1_head_index;

	DISPATCH_LSQ [1:0] disp_LSQ;

	DCACHE_LSQ cache_LSQ_0;

	// debugging sq signals
	SQ_DATA [1:0] [`SQ_SIZE-1:0] sq_entries; 
	logic   [1:0] [`SQ_SIZE-1:0] sq_eff_add_ready_list; 
	logic   [1:0] [`SQ_BITS-1:0] sq_eff_add_ready_index;
	logic   [1:0] [`SQ_BITS:0]   sq_count;

	// debugging lb signals
	LB_DATA [1:0] [`LB_SIZE-1:0] lb_entries; 
	logic   [1:0] [`LB_SIZE-1:0] lb_free_list; 
	logic   [1:0] [`LB_SIZE-1:0] lb_base_addr_ready_list;
	logic   [1:0] [`LB_SIZE-1:0] lb_ready_to_go_list; 
	logic   [1:0] [`LB_SIZE-1:0] lb_ready_cdb_list; 
	logic   [1:0] [`LB_BITS-1:0] lb_base_addr_ready_index; 
	logic   [1:0] [`LB_BITS-1:0] lb_ready_to_go_index; 
	logic   [1:0] [`LB_BITS-1:0] lb_ready_cdb_index;

	FU_RESULT [1:0] LSQ_output;

	logic LSQ_full;
	logic LSQ_almost_full;


	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	dcache dcache_0 (

		.clock( clock),
		.reset( reset),
		.nuke0( nuke0),
		.nuke1( nuke1),

		.Dmem2proc_response(Dmem2proc_response),
		.Dmem2proc_data( Dmem2proc_data),
		.Dmem2proc_tag(  Dmem2proc_tag),

		.lsq_request_1( lsq_request_1),
				
		.Dcache_data_1(  Dcache_data_1), 				 
		.Dcache_valid_1( Dcache_valid_1),	

		.proc2Dmem_command( proc2Dmem_command),
		.proc2Dmem_addr( proc2Dmem_addr),
		.proc2Dmem_data( proc2Dmem_data),

		.Dcache_data_out_1(  Dcache_data_out_1),   	
		.Dcache_valid_out_1( Dcache_valid_out_1),  	
		.Mem_request_failed( Mem_request_failed),

		.wr1_req_idx( wr1_req_idx),		  			
		.wr1_req_tag( wr1_req_tag), 
		.wr1_req_data( wr1_req_data),
			
		.wr1_missed_load_idx( wr1_missed_load_idx),		  			
		.wr1_missed_load_tag( wr1_missed_load_tag), 

		.wr1_req_en( wr1_req_en),		
		.wr1_missed_load_en( wr1_missed_load_en),	

		.rd1_idx( rd1_idx),  				
		.rd1_tag( rd1_tag),  						

		.LB_response( LB_response),			

		.Request_buff( Request_buff), 	

		.head_index( head_index),  
		.tail_index( tail_index),  
		.count( count),       		
		.full( full)        		
	);

	dcachemem dcachemem_0 (

		.clock( clock),
		.reset( reset),

		.wr1_req_en( wr1_req_en),
		.wr1_missed_load_en( wr1_missed_load_en),

		.wr1_req_idx(  wr1_req_idx),	   		// write from SQ request
		.wr1_req_tag(  wr1_req_tag),  	   	
		.wr1_req_data( wr1_req_data),	   		// data  from SQ request

		.wr1_missed_load_idx( wr1_missed_load_idx),	// write from previously missed load
		.wr1_missed_load_tag( wr1_missed_load_tag), 

		.rd1_idx( rd1_idx),
		.rd1_tag( rd1_tag),

		.wr1_data_from_Mem( Dmem2proc_data),		// data coming directly from Memory

		.rd1_data(  Dcache_data_1),
		.rd1_valid( Dcache_valid_1),	

		.data(cachemem_data), 					// Debugging OUutputs ***********************
		.tags(cachemem_tags), 
		.valids(cachemem_valids)
	);

	mem mem_0 (

		.clk( clock),              		 	// Memory clock
		.proc2mem_addr( proc2Dmem_addr),    	 	// address for current command
		.proc2mem_data( proc2Dmem_data),    	 	// address for current command
		.proc2mem_command( proc2Dmem_command), 	 	// `BUS_NONE `BUS_LOAD or `BUS_STORE

		.mem2proc_response( Dmem2proc_response), 	// 0 = can't accept, other=tag of transaction
		.mem2proc_data( Dmem2proc_data),     	 	// data resulting from a load
		.mem2proc_tag( Dmem2proc_tag)       	 	// 0 = no value, other=tag of transaction
	);

	assign cache_LSQ_0.valid = Dcache_valid_out_1;
	assign cache_LSQ_0.data  = Dcache_data_out_1;


	lsq lsq_0 (
		.clock(clock), 
		.reset(reset), 

		.nuke_thread_0(nuke0),
		.nuke_thread_1(nuke1),

		.cdb_0(cdb_0),
		.cdb_1(cdb_1),

		.ROB_0_head_index(ROB_0_head_index),
		.ROB_1_head_index(ROB_1_head_index),

		.disp_LSQ(disp_LSQ),

		.cache_LSQ_0(cache_LSQ_0),
		.resolved_read(LB_response),
		.request_failed(Mem_request_failed), 

		// debugging sq signals
		.sq_entries(sq_entries), 
		.sq_eff_add_ready_list(sq_eff_add_ready_list), 
		.sq_eff_add_ready_index(sq_eff_add_ready_index),
		.sq_count(sq_count),

		// debugging lb signals
		.lb_entries(lb_entries), 
		.lb_free_list(lb_free_list), 
		.lb_base_addr_ready_list(lb_base_addr_ready_list),
		.lb_ready_to_go_list(lb_ready_to_go_list), 
		.lb_ready_cdb_list(lb_ready_cdb_list), 
		.lb_base_addr_ready_index(lb_base_addr_ready_index), 
		.lb_ready_to_go_index(lb_ready_to_go_index), 
		.lb_ready_cdb_index(lb_ready_cdb_index),

		.LSQ_cache_0(lsq_request_1),
		.LSQ_output(LSQ_output),

		.full(LSQ_full),
		.almost_full(LSQ_almost_full)
	);

	task reset_inst_in;
		begin
			disp_LSQ[0].rd_mem = 0;
			disp_LSQ[0].wr_mem = 0;
			disp_LSQ[0].ldl_mem = 0;
			disp_LSQ[0].stc_mem = 0;
			disp_LSQ[0].thread_ID = 0;
			disp_LSQ[0].dispatch = 0;
			disp_LSQ[0].value_to_store = 0;
			disp_LSQ[0].value_to_store_ready = 0;
			disp_LSQ[0].value_to_store_PRN = 0;
			disp_LSQ[0].base_addr_ready = 0;
			disp_LSQ[0].base_addr = 0;
			disp_LSQ[0].base_addr_PRN = 0;
			disp_LSQ[0].offset = 0;
			disp_LSQ[0].PRN_dest = 0;
			disp_LSQ[0].ROB_index = 0;

			disp_LSQ[1].rd_mem = 0;
			disp_LSQ[1].wr_mem = 0;
			disp_LSQ[1].ldl_mem = 0;
			disp_LSQ[1].stc_mem = 0;
			disp_LSQ[1].thread_ID = 0;
			disp_LSQ[1].dispatch = 0;
			disp_LSQ[1].value_to_store = 0;
			disp_LSQ[1].value_to_store_ready = 0;
			disp_LSQ[1].value_to_store_PRN = 0;
			disp_LSQ[1].base_addr_ready = 0;
			disp_LSQ[1].base_addr = 0;
			disp_LSQ[1].base_addr_PRN = 0;
			disp_LSQ[1].offset = 0;
			disp_LSQ[1].PRN_dest = 0;
			disp_LSQ[1].ROB_index = 0;
		end
	endtask

	task reset_inputs;
		reset = 1;
		nuke0 = 0;
		nuke1 = 0;

		cdb_0.valid = 0;
		cdb_0.thread_ID = 0;
		cdb_0.FU_result = 0;
		cdb_0.PRN = 0;
		cdb_0.ROB_index = 0;
		cdb_0.mispredict = 0;
		cdb_0.branch_actually_taken = 0;

		cdb_1.valid = 0;
		cdb_1.thread_ID = 0;
		cdb_1.FU_result = 0;
		cdb_1.PRN = 0;
		cdb_1.ROB_index = 0;
		cdb_1.mispredict = 0;
		cdb_1.branch_actually_taken = 0;

		ROB_0_head_index = 0;
		ROB_1_head_index = 0;

		reset_inst_in();
		@(negedge clock);
		reset = 0;
	endtask

	task dispatch_inst0;
		input thread, read;
		begin
			disp_LSQ[0].rd_mem = read;
			disp_LSQ[0].wr_mem = !read;
			disp_LSQ[0].thread_ID = thread;
			disp_LSQ[0].dispatch = 1;
		end
	endtask

	task dispatch_inst1;
		input thread, read;
		begin
			disp_LSQ[1].rd_mem = read;
			disp_LSQ[1].wr_mem = !read;
			disp_LSQ[1].thread_ID = thread;
			disp_LSQ[1].dispatch = 1;
		end
	endtask

	task assert_and_message;
		input         condition;
		input [255:0] message;
		begin
			if(!condition) begin
				$display("%s \n@@@Failed", message);
				$finish;
			end
		end
	endtask

	task print_lb_arr;
		input [10:0] n;
		begin
			for(int i=0; i<n; i++) begin
				print_lb0_entry(i, lb_free_list[0][i], lb_base_addr_ready_list[0][i], lb_ready_to_go_list[0][i], 
				               lb_ready_cdb_list[0][i], lb_entries[0][i].base_addr_PRN);
				print_lb1_entry(i, lb_free_list[1][i], lb_base_addr_ready_list[1][i], lb_ready_to_go_list[1][i], 
				               lb_ready_cdb_list[1][i], lb_entries[1][i].base_addr_PRN);
			end
		end
	endtask

	task print_sq_arr;
		input [10:0] n;
		begin
			for(int i=0; i<n; i++) begin
				print_sq0_entry(i, sq_eff_add_ready_list[0][i], sq_entries[0][i].value_to_store, sq_entries[0][i].base_addr_PRN);
				print_sq1_entry(i, sq_eff_add_ready_list[1][i], sq_entries[1][i].value_to_store, sq_entries[1][i].base_addr_PRN);
			end
		end
	endtask
	
	task print_dcache_arr;
		input [4:0] n;
		begin
			print_dcache_empty_line();
			print_dcache_line("Dcache Mem", 0);
			for(int i=0; i<n; i++)
				print_dcache_entry(i, cachemem_valids[i], cachemem_tags[i], cachemem_data[i]);

			print_dcache_empty_line();
			print_dcache_line("Buffer Request", 0);
			for(int i=0; i<n; i++)
				print_buffer_request_entry(i, Request_buff[i].addr, Request_buff[i].tag);			

			print_dcache_empty_line();
			print_dcache_line("count", count);
			print_dcache_line("head", head_index);
			print_dcache_line("tail", tail_index);

			print_dcache_empty_line();
			print_dcache_line("Dmem2proc_response", Dmem2proc_response);
			print_dcache_line("Dmem2proc_data", Dmem2proc_data);
			print_dcache_line("Dmem2proc_tag", Dmem2proc_tag);
			
			print_dcache_empty_line();
			print_dcache_line("proc2Dmem_command", proc2Dmem_command);
			print_dcache_line("proc2Dmem_addr", proc2Dmem_addr);
			print_dcache_line("proc2Dmem_data", proc2Dmem_data);

			print_dcache_empty_line();
			print_dcache_line("Dcache_data_1", Dcache_data_1);
			print_dcache_line("Dcache_valid_1", Dcache_valid_1);
			print_dcache_line("Dcache_data_out_1", Dcache_data_out_1);
			print_dcache_line("Dcache_valid_out_1", Dcache_valid_out_1);
		end
	endtask

	always begin
		#5;
		clock = ~clock;
	end
	
	initial 
	begin
	
		clock = 0;
		print_header("////////////LET THE FUN BEGIN//////////////////");
		reset_inputs();

		@(negedge clock);
		dispatch_inst0(0, 1);
		dispatch_inst1(0, 1);
		@(negedge clock);
		dispatch_inst0(0, 1);
		dispatch_inst1(0, 1);
		@(negedge clock);
		reset_inst_in();

		repeat(3) @(negedge clock);

		$display("\n@@@PASSED!");
		$finish;
	end


	
	always @(negedge clock) begin
		#2;
		if(reset)
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			$realtime);
		else begin	
			`SD;
			print_start_cycle();
			print_dcache_arr(10);
			print_sq_arr(`SQ_SIZE);
			print_lb_arr(`LB_SIZE);
			print_end_cycle();
			increment_cycle();
		end
	end
endmodule
