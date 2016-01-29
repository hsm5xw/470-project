module testbench();
	logic clock;
	logic reset;
	CDB CDB_0;
	CDB CDB_1;
	
	DISPATCH_RS dispatch_inst0;
	DISPATCH_RS dispatch_inst1;
	
	logic branch_mispredict_0;
	logic branch_mispredict_1;
	
	logic ALU0_ready;
	logic ALU1_ready;
	logic Mult_ready;
	logic Branch_ready;
	
	ISSUE_RS issue_inst0;
	ISSUE_RS issue_inst1;
	ISSUE_RS issue_inst2;
	ISSUE_RS issue_inst3;
	
	logic full;
	logic almost_full;	

	logic [`RS_SIZE-1:0] dispatch_free_list;		

	logic [`RS_SIZE-1:0] awaken_ALU_list;	 // debugging outputs
	logic [`RS_SIZE-1:0] awaken_Mult_list;
	logic [`RS_SIZE-1:0] awaken_Branch_list;

	logic [`RS_BITS : 0] count;
	RS_DATA [`RS_SIZE-1:0] RS_array;	 // debugging outputs

	rs rs_0 (
		.clock( clock), 
		.reset( reset), 
		
		.dispatch_inst0( dispatch_inst0),
		.dispatch_inst1( dispatch_inst1),
		
		.CDB_0( CDB_0),
		.CDB_1( CDB_1),
		
	    	.branch_mispredict_0( branch_mispredict_0),
	    	.branch_mispredict_1( branch_mispredict_1),
		
		.ALU0_ready(   ALU0_ready),
		.ALU1_ready(   ALU1_ready),
		.Mult_ready(   Mult_ready),
		.Branch_ready( Branch_ready),
		
		.issue_inst0( issue_inst0),
		.issue_inst1( issue_inst1),
		.issue_inst2( issue_inst2),
		.issue_inst3( issue_inst3),
		
		.full( full),
		.almost_full( almost_full),

  		.count( count),

		.dispatch_free_list_debug( dispatch_free_list),
		.awaken_ALU_list_debug(    awaken_ALU_list),
		.awaken_Mult_list_debug(   awaken_Mult_list),
		.awaken_Branch_list_debug( awaken_Branch_list),

		.RS_array_debug( RS_array)
	
		);

	always begin
		#5;
		clock = ~clock;
	end

	task reset_inputs;
	
		// inst 0
		dispatch_inst0.dispatch  	= 0;
		dispatch_inst0.op_type		= INVALID;
		dispatch_inst0.operation	= 0;

		dispatch_inst0.op1_ready 	= 0;		
		dispatch_inst0.op1_value 	= 0;
		dispatch_inst0.op1_PRF_index	= 0;

		dispatch_inst0.op2_ready 	= 0;
		dispatch_inst0.op2_value 	= 0;
		dispatch_inst0.op2_PRF_index 	= 0;

		dispatch_inst0.dest_PRF_index	= 0;
		dispatch_inst0.ROB_index	= 0;
		dispatch_inst0.next_pc		= 0;
		dispatch_inst0.branch_target_addr = 0;

		// inst 1
		dispatch_inst1.dispatch  	= 0;
		dispatch_inst1.op_type		= INVALID;
		dispatch_inst1.operation	= 0;

		dispatch_inst1.op1_ready 	= 0;		
		dispatch_inst1.op1_value 	= 0;
		dispatch_inst1.op1_PRF_index	= 0;

		dispatch_inst1.op2_ready 	= 0;
		dispatch_inst1.op2_value 	= 0;
		dispatch_inst1.op2_PRF_index 	= 0;

		dispatch_inst1.dest_PRF_index	= 0;
		dispatch_inst1.ROB_index	= 0;
		dispatch_inst1.next_pc		= 0;
		dispatch_inst1.branch_target_addr = 0;


		// CDB
		CDB_0.FU_result  = 64'hAAAA_AAAA_AAAA_AAAA;
		CDB_0.PRN 	 = 0;
		CDB_0.ROB_index  = 0;
		CDB_0.mispredict = 0;
		CDB_0.valid 	 = 0;
		CDB_0.thread_id  = 0;    

		CDB_1.FU_result  = 64'hBBBB_BBBB_BBBB_BBBB;
		CDB_1.PRN 	 = 1;
		CDB_1.ROB_index  = 1;
		CDB_1.mispredict = 0;
		CDB_1.valid 	 = 0;
		CDB_1.thread_id  = 0;		

		branch_mispredict_0 = 0;
		branch_mispredict_1 = 0;

		ALU0_ready	= 0;
		ALU1_ready	= 0;
		Mult_ready	= 0;
		Branch_ready	= 0;
	endtask

	task reset_RS;
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

	task dispatch_loop;
		input dispatch_1_in;
		input [`RS_BITS:0] num_inst;

		begin

			for(int i=0; i< num_inst; i=i+1+dispatch_1_in ) begin
				@(negedge clock);

				// inst 0
				dispatch_inst0.dispatch = 1;
				dispatch_inst0.op_type  = ALU;
				dispatch_inst0.operation = ALU_ADDQ;
				
				dispatch_inst0.op1_ready = 0;
				dispatch_inst0.op1_value = i;

				dispatch_inst0.op2_ready = 0;
				dispatch_inst0.op2_value = i+1;

				dispatch_inst0.op1_PRF_index  = 1;
				dispatch_inst0.op2_PRF_index  = 2;			
				dispatch_inst0.dest_PRF_index = 3;

				dispatch_inst0.ROB_index = i;
				dispatch_inst0.next_pc   = i;

				// inst 1
				dispatch_inst1.dispatch = dispatch_1_in;
				dispatch_inst1.op_type  = ALU;
				dispatch_inst1.operation = ALU_ADDQ;	
			
				dispatch_inst1.op1_ready = 0;
				dispatch_inst1.op1_value = i;

				dispatch_inst1.op2_ready = 0;
				dispatch_inst1.op2_value = i+1;

				dispatch_inst1.op1_PRF_index  = 4;
				dispatch_inst1.op2_PRF_index  = 5;			
				dispatch_inst1.dest_PRF_index = 6;

				dispatch_inst1.ROB_index = i;
				dispatch_inst1.next_pc   = i;

			end
			@(negedge clock);
			dispatch_inst0 = 0;
			dispatch_inst1 = 0;
		end
	endtask


	// dispatching function just to check if the CDB broadcasts update operands
	// dispatch one instructions at a time 
	task dispatch_one_loop;
		input [`RS_BITS:0] num_inst;

		begin
			for(int i=0; i< num_inst; i= i+ 1 ) begin
				@(negedge clock);

				// inst 0
				dispatch_inst0.dispatch = 1;
				dispatch_inst0.op_type  = ALU;
				dispatch_inst0.operation = ALU_ADDQ;
				
				dispatch_inst0.op1_ready = 0;
				dispatch_inst0.op1_value = i;

				dispatch_inst0.op2_ready = 0;
				dispatch_inst0.op2_value = i+1;

				dispatch_inst0.op1_PRF_index  = 1;
				dispatch_inst0.op2_PRF_index  = 2;			
				dispatch_inst0.dest_PRF_index = 3;

				dispatch_inst0.ROB_index = i;
				dispatch_inst0.next_pc   = i;
			end
			@(negedge clock);
			dispatch_inst0 = 0;
		end
	endtask
	



	// broadcast CDB's once 
	task CDB_broadcast_once;

		input CDB_0_valid;
		input CDB_1_valid;

		begin
			@(negedge clock);
			CDB_0.valid = CDB_0_valid;
			CDB_1.valid = CDB_1_valid;

			CDB_0.FU_result = 100;
			CDB_1.FU_result = 200;
			
			CDB_0.PRN    = 1;
			CDB_1.PRN    = 2;
		
			@(negedge clock);
			CDB_0.valid = 0;
			CDB_1.valid = 0;
		end
	endtask


	// check if dependent instructions in the RS get updated after CDB broadcast if the tags (PRF_index) matchh
	task RS_checkup_after_CDB;

		input CDB_0_valid;
		input CDB_1_valid;

		begin
	
		// matching with CDB_0
		if( CDB_0.valid ) begin
		
			for(int i=0; i< `RS_SIZE; i++) begin

				// match CDB 0's tag with 1st operand for each entry in RS
				if( RS_array[i].busy && (CDB_0.PRN == RS_array[i].op1_PRF_index) ) begin
					
					assert_and_message( (RS_array[i].op1_PRF_index == 1) && (RS_array[i].op1_value == 100)  , "checking after CDB_0 broadcast");
				end 

				// match CDB 0's tag with 2nd operand for each entry in RS
				if( RS_array[i].busy && (CDB_0.PRN == RS_array[i].op2_PRF_index) ) begin
					
					assert_and_message( (RS_array[i].op2_PRF_index == 1) && (RS_array[i].op2_value == 100) , "checking after CDB_0 broadcast");
				end
			end // end of for-loop
		end

		// matching with CDB_1
		if( CDB_1.valid ) begin
		
			for(int i=0; i< `RS_SIZE; i++) begin

				// match CDB 0's tag with 1st operand for each entry in RS
				if( RS_array[i].busy && (CDB_1.PRN == RS_array[i].op1_PRF_index) ) begin
					
					assert_and_message( (RS_array[i].op1_PRF_index == 2) && (RS_array[i].op1_value == 200)  , "checking after CDB_1 broadcast");
				end 

				// match CDB 0's tag with 2nd operand for each entry in RS
				if( RS_array[i].busy && (CDB_1.PRN == RS_array[i].op2_PRF_index) ) begin
					
					assert_and_message( (RS_array[i].op2_PRF_index == 2) && (RS_array[i].op2_value == 200) , "checking after CDB_1 broadcast");
				end
			end // end of for-loop
		end


		end		
	endtask




	initial 
	begin
		clock = 0;
		reset_RS();

		// test dispatching RS one at a time

		$display("dispatch one at a time until almost full");
		dispatch_loop(0, `RS_SIZE-1);
		assert_and_message(!full && almost_full && count==`RS_SIZE-1, "RS one from full");
		dispatch_loop(0, 1);
		assert_and_message(full && !almost_full && count==`RS_SIZE, "RS full");
		reset_RS();

		// test dispatching RS is almost full

		$display("dispatch two at a time until two away from full");
		dispatch_loop(1, `RS_SIZE-2);
		assert_and_message(!full && !almost_full && count==`RS_SIZE-2, "RS two from full");
		dispatch_loop(1, 2);
		assert_and_message(full && !almost_full && count==`RS_SIZE, "RS full");
		reset_RS();

		// 1. test if CDB's broadcast and dependent instructions have their operands updated

		$display("test if CDB's broadcast and dependent instructions have their operands updated");
		dispatch_one_loop(`RS_SIZE/2);		// dispatch one at a time until RS is half full

		CDB_broadcast_once(1,1);
		RS_checkup_after_CDB(1,1);
		reset_RS();


		// 2. test if CDB's broadcast and dependent instructions have their operands updated

		$display("test if CDB's broadcast and dependent instructions have their operands updated");
		dispatch_one_loop(`RS_SIZE);		// dispatch one at a time until RS is full

		CDB_broadcast_once(1,1);
		RS_checkup_after_CDB(1,1);
		@(negedge clock);
		ALU0_ready = 1'b1;
		ALU1_ready = 1'b1;
		
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		ALU0_ready = 1'b0;
		ALU1_ready = 1'b0;

		reset_RS();


		// test issueing instruction if ALU0 is ready but ALU1 is not ready

		$display("Dispatch One \n");
		dispatch_one_loop(1);	// dispatch only 1 instruction
		CDB_broadcast_once(1,1);
		@(negedge clock);
		ALU0_ready = 1'b1;
		ALU1_ready = 1'b0;	
		@(negedge clock);

		ALU0_ready = 1'b0;
		ALU1_ready = 1'b0;

		assert_and_message( issue_inst0.valid && (issue_inst0.op1_value == 100) && (issue_inst0.op2_value == 200)  , "First instruction should be issued valid1");
		assert_and_message( !issue_inst1.valid && !issue_inst2.valid && !issue_inst3.valid, "other instructions should be invalid1");

		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);

		reset_RS();


		// test issueing instruction if ALU0 is not ready but ALU1 is ready

		$display("Dispatch One 2\n");
		dispatch_one_loop(1);	// dispatch only 1 instruction
		CDB_broadcast_once(1,1);
		@(negedge clock);
		ALU0_ready = 1'b0;
		ALU1_ready = 1'b1;	
		@(negedge clock);

		ALU0_ready = 1'b0;
		ALU1_ready = 1'b0;

		assert_and_message( issue_inst1.valid && (issue_inst1.op1_value == 100) && (issue_inst1.op2_value == 200)  , "First instruction should be issued valid2");
		assert_and_message( !issue_inst0.valid && !issue_inst2.valid && !issue_inst3.valid, "other instructions should be invalid2");

		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);
		@(negedge clock);

		reset_RS();


		// test if branch mispredict 1

		$display("Branch Mispredict 1\n");		
		dispatch_one_loop(`RS_SIZE);		// dispatch one at a time until RS is full
		assert_and_message(full && !almost_full && count==`RS_SIZE, "RS full");

		@(negedge clock);
		branch_mispredict_0 = 1'b1;
		@(negedge clock);	
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b0;
		reset_RS();	

		// test if branch mispredict 2


		$display("Branch Mispredict 2\n");		
		dispatch_one_loop(`RS_SIZE);		// dispatch one at a time until RS is full
		assert_and_message(full && !almost_full && count==`RS_SIZE, "RS full");

		@(negedge clock);
		branch_mispredict_1 = 1'b1;
		@(negedge clock);	
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_1 = 1'b0;
		reset_RS();


		// test if branch mispredict 3

		$display("Branch Mispredict 3\n");		
		dispatch_one_loop(`RS_SIZE);		// dispatch one at a time until RS is full
		assert_and_message(full && !almost_full && count==`RS_SIZE, "RS full");

		@(negedge clock);
		branch_mispredict_0 = 1'b1;
		branch_mispredict_1 = 1'b1;
		@(negedge clock);	
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b0;
		branch_mispredict_1 = 1'b0;
		reset_RS();

		// test if branch mispredict 4

		$display("Branch Mispredict 4\n");		
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b1;
		branch_mispredict_1 = 1'b1;
		@(negedge clock);	
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b0;
		branch_mispredict_1 = 1'b0;
		reset_RS();

		// test if branch mispredict 5

		$display("Branch Mispredict 5\n");		
		dispatch_one_loop(1);		// dispatch only 1 instruction
		assert_and_message(!full && !almost_full && count== 1, "RS almost empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b1;
		@(negedge clock);	
		assert_and_message(!full && !almost_full && count== 0, "RS empty");

		@(negedge clock);
		branch_mispredict_0 = 1'b0;
		reset_RS();


		$display("\n@@@PASSED!");
		$finish;
	end // initial
endmodule