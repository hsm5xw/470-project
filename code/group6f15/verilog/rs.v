module rs(
	input logic clock,
	input logic reset,
	 
	input DISPATCH_RS  dispatch_inst0,	// dispatched instruction 0 from dispatch module
	input DISPATCH_RS  dispatch_inst1,	// dispatched instruction 1 from dispatch module	 
 	
 	input CDB CDB_0,
	input CDB CDB_1,

	input logic branch_mispredict_0,
	input logic branch_mispredict_1,

    input logic ALU0_ready,     		// Determines whether a particular Functional Unit is ready or not
    input logic ALU1_ready,
    input logic Mult_ready,
    input logic Branch_ready,
         
	output ISSUE_RS issue_inst0,		// issue to ALU0 
	output ISSUE_RS issue_inst1,		// issue to ALU1
	output ISSUE_RS issue_inst2,		// issue to Mult
	output ISSUE_RS issue_inst3,		// issue to Branch_calc
 
	output logic full,					// sent to the dispatch module (stall)
	output logic almost_full 			// sent to the dispatch module

	);

	logic [`RS_BITS:0] count;

	// logic [`RS_SIZE-1:0] dispatch_free_list_debug;
	// logic [`RS_SIZE-1:0] awaken_ALU_list_debug;
	// logic [`RS_SIZE-1:0] awaken_Mult_list_debug;
	// logic [`RS_SIZE-1:0] awaken_Branch_list_debug;

	RS_DATA [`RS_SIZE-1:0] RS_array_debug;
	
	RS_DATA [`RS_SIZE-1:0] RS_array, n_RS_array;					// holds RS data for each entry
	logic [`RS_SIZE-1:0] dispatch_free_list, n_dispatch_free_list;	// a free list to select which instruction to dispatch to RS
	logic [`RS_SIZE-1:0] awaken_ALU_list, n_awaken_ALU_list;
	logic [`RS_SIZE-1:0] awaken_Mult_list, n_awaken_Mult_list;
	logic [`RS_SIZE-1:0] awaken_Branch_list, n_awaken_Branch_list;

	logic [`RS_BITS:0] n_count; // total count of instructions in RS

	logic [1:0] count_disp_t0, count_disp_t1; // Keeps track of which instructions are dispatched from Thread 0 and Thread 1
	logic [3:0] count_iss_t0, count_iss_t1; // Keeps track of which instructions from a specific thread have been issued

	// Convert the count_disp and count_iss to correct numbers and store below
	logic [`RS_BITS:0] count_inc_t0, count_inc_t1, count_dec_t0, count_dec_t1;
	logic [`RS_BITS:0] count_inst_t0, count_inst_t1, n_count_inst_t0, n_count_inst_t1;

	logic n_full, n_almost_full;
	

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// instantiate the priority selector
 
	parameter WIDTH = `RS_SIZE;
	parameter DISPATCH_REQ = 2;
  	parameter ALU_REQ = 2;
  	parameter OTHER_REQ = 1;

  	logic  [WIDTH-1:0]              dispatch_gnt;
  	logic  [DISPATCH_REQ*WIDTH-1:0] dispatch_gnt_bus;
  	logic                           dispatch_empty;

  	logic  [WIDTH-1:0]              ALU_gnt;
  	logic  [ALU_REQ*WIDTH-1:0]      ALU_gnt_bus;
  	logic                           ALU_empty;

  	logic  [WIDTH-1:0]              Mult_gnt;
  	logic  [OTHER_REQ*WIDTH-1:0]    Mult_gnt_bus;
  	logic                           Mult_empty;
  	
  	logic  [WIDTH-1:0]              Branch_gnt;
  	logic  [OTHER_REQ*WIDTH-1:0]    Branch_gnt_bus;
  	logic                           Branch_empty;

	// Priority selector for Dispatching to RS
	psel_gen #(.REQS(DISPATCH_REQ), .WIDTH(WIDTH)) dispatch_priority_sel
	(
	 	.req( dispatch_free_list ),
	 	.gnt( dispatch_gnt),
	 	.gnt_bus( dispatch_gnt_bus),
	 	.empty( dispatch_empty)
	);

	// Priority selector for ALU
	psel_gen #(.REQS(ALU_REQ), .WIDTH(WIDTH)) ALU_priority_sel
	(
	 	.req( awaken_ALU_list ),
		.gnt( ALU_gnt ),
	 	.gnt_bus( ALU_gnt_bus ),
		.empty(   ALU_empty )
	);

	// Priority selector for Multiplier
	psel_gen #(.REQS(OTHER_REQ), .WIDTH(WIDTH)) Mult_priority_sel
	(
	 	.req( awaken_Mult_list ),
	 	.gnt( Mult_gnt ),
		.gnt_bus( Mult_gnt_bus ),
	 	.empty(   Mult_empty )
	);
	
	// Priority selector for Branch Address Calculator
	psel_gen #(.REQS(OTHER_REQ), .WIDTH(WIDTH)) Branch_priority_sel
	(
	 	.req( awaken_Branch_list ),
	 	.gnt( Branch_gnt ),
		.gnt_bus( Branch_gnt_bus ),
	 	.empty(   Branch_empty )
	);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// Encoder inputs

	logic [WIDTH-1:0] ALU_gnt_0;
	logic [WIDTH-1:0] ALU_gnt_1;

	// Encoder outputs

	logic [WIDTH-1:0] dispatch_gnt_0_encoded;
	logic [WIDTH-1:0] dispatch_gnt_1_encoded;

	logic [WIDTH-1:0] ALU_gnt_0_encoded;
	logic [WIDTH-1:0] ALU_gnt_1_encoded;

	logic [WIDTH-1:0] Mult_gnt_encoded;
	logic [WIDTH-1:0] Branch_gnt_encoded;

	logic dispatch_gnt_0_valid;
	logic dispatch_gnt_1_valid;

	logic ALU_gnt_0_valid;
	logic ALU_gnt_1_valid;

	logic Mult_gnt_valid;
	logic Branch_gnt_valid;

	always_comb begin

	// assign ALU_gnt
		if( !ALU0_ready && ALU1_ready ) begin
			ALU_gnt_0 = ALU_gnt_bus[(2)*WIDTH-1 -: WIDTH];
			ALU_gnt_1 = ALU_gnt_bus[(1)*WIDTH-1 -: WIDTH];
		end
		else begin
			ALU_gnt_0 = ALU_gnt_bus[(1)*WIDTH-1 -: WIDTH];
			ALU_gnt_1 = ALU_gnt_bus[(2)*WIDTH-1 -: WIDTH];
		end
	end

	// Instantiate the encoders	
	encoder dispatch_gnt_0_encoder
	(
		.encoder_input(  dispatch_gnt_bus[(1)*WIDTH-1 -: WIDTH]),
		.encoder_output( dispatch_gnt_0_encoded),
		.valid( 	 dispatch_gnt_0_valid)
	);

	encoder dispatch_gnt_1_encoder
	(
		.encoder_input(  dispatch_gnt_bus[(2)*WIDTH-1 -: WIDTH]),
		.encoder_output( dispatch_gnt_1_encoded),
		.valid( 	 dispatch_gnt_1_valid)
	);

	encoder ALU_gnt_0_encoder
	(
		.encoder_input(  ALU_gnt_0 ),	// ***************
		.encoder_output( ALU_gnt_0_encoded),
		.valid( 	 ALU_gnt_0_valid)
	);
	
        encoder ALU_gnt_1_encoder
	(
		.encoder_input(  ALU_gnt_1 ),	// ****************
		.encoder_output( ALU_gnt_1_encoded),
		.valid( 	 ALU_gnt_1_valid)
	);
	
	encoder Mult_gnt_encoder
	(
		.encoder_input(  Mult_gnt_bus[WIDTH-1 -: WIDTH]),
		.encoder_output( Mult_gnt_encoded),
		.valid( 	 Mult_gnt_valid)	
	);

	encoder Branch_gnt_encoder
	(
		.encoder_input(  Branch_gnt_bus[WIDTH-1 -: WIDTH]),
		.encoder_output( Branch_gnt_encoded),
		.valid( 	 Branch_gnt_valid)	
	);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin

		// initialize the RS array upon reset
		if(reset) begin

			for( int j=0; j<`RS_SIZE; j++) begin

				RS_array[j].thread_ID		<= #1 0;
				RS_array[j].op_type 		<= #1 0;
				RS_array[j].operation 		<= #1 0;

				RS_array[j].busy 			<= #1 0;
				RS_array[j].instr_type		<= #1 OTHER;

				RS_array[j].op1_ready 		<= #1 0;
				RS_array[j].op1_value 		<= #1 64'b0;
				RS_array[j].op1_PRF_index 	<= #1 0;

				RS_array[j].op2_ready 		<= #1 0;
				RS_array[j].op2_value 		<= #1 64'b0;
				RS_array[j].op2_PRF_index 	<= #1 0;

				RS_array[j].dest_PRF_index 	<= #1 0;

				RS_array[j].ROB_index 		<= #1 0;
				RS_array[j].next_pc 		<= #1 64'b0;
				RS_array[j].branch_target_addr 	<= #1 64'b0;

				RS_array[j].branch_predicted_taken <= #1 0;
				RS_array[j].branch_cond_op 	   <= #1 0;
				RS_array[j].branch_disp		   <= #1 16'b0;


				// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
				dispatch_free_list[j]	<= #1 1;	

				// set all the awaken list bits to 0 
				awaken_ALU_list[j]		<= #1 0;
				awaken_Mult_list[j]		<= #1 0;
				awaken_Branch_list[j] 	<= #1 0;
			end // end of for-loop
			
				full  			<= #1 0;
				almost_full 	<= #1 0;
				count 			<= #1 0;
				count_inst_t0 	<= #1 0;
				count_inst_t1 	<= #1 0;			
		end else begin
			// Branch Mispredict! ****************************************************************************** below

			// initialize the RS array upon branch mispredict
			if( branch_mispredict_0 && !branch_mispredict_1 ) begin

				count_inst_t0 <= #1 0;
				count_inst_t1 <= #1 n_count_inst_t1;
				count 		  <= #1 n_count_inst_t1;

				for(int j=0; j<`RS_SIZE; j++) begin
					if(n_RS_array[j].thread_ID == 1'b0) begin

						RS_array[j].thread_ID 		<= #1 0;
						RS_array[j].op_type 		<= #1 0;
						RS_array[j].operation 		<= #1 0;

						RS_array[j].busy 			<= #1 0;
						RS_array[j].instr_type		<= #1 OTHER;

						RS_array[j].op1_ready 		<= #1 0;
						RS_array[j].op1_value 		<= #1 64'hB000_CAFE_CAFE_B000;
						RS_array[j].op1_PRF_index 	<= #1 0;

						RS_array[j].op2_ready 		<= #1 0;
						RS_array[j].op2_value 		<= #1 64'hB000_CAFE_CAFE_B000;
						RS_array[j].op2_PRF_index 	<= #1 0;

						RS_array[j].dest_PRF_index 	<= #1 0;

						RS_array[j].ROB_index 		<= #1 0;
						RS_array[j].next_pc 		<= #1 `ADDR_BITS'b0;
						RS_array[j].branch_target_addr	<= #1 `ADDR_BITS'b0;

						RS_array[j].branch_predicted_taken	<= #1 0;
						RS_array[j].branch_cond_op 	   <= #1 0;
						RS_array[j].branch_disp		   <= #1 16'b0;

						// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
						dispatch_free_list[j]	<= #1 1;	

						// set the awaken list bits in thread 0 to 0
						awaken_ALU_list[j]		<= #1 0;
						awaken_Mult_list[j]		<= #1 0;
						awaken_Branch_list[j]	<= #1 0;
						
					end else begin
						RS_array[j] <= #1 n_RS_array[j];

						// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
						dispatch_free_list[j]	<= #1 n_dispatch_free_list[j];	

						// set the awaken list bits in thread 0 to 0
						awaken_ALU_list[j]		<= #1 n_awaken_ALU_list[j];
						awaken_Mult_list[j]		<= #1 n_awaken_Mult_list[j];
						awaken_Branch_list[j]	<= #1 n_awaken_Branch_list[j];						
					end					
				end // for
			end else if( branch_mispredict_1 && !branch_mispredict_0 ) begin

				count_inst_t0 <= #1 n_count_inst_t0;
				count_inst_t1 <= #1 0;
				count   	  <= #1 n_count_inst_t0;

				for(int j=0; j<`RS_SIZE; j++) begin
					if(n_RS_array[j].thread_ID == 1'b1) begin

						RS_array[j].thread_ID 		<= #1 0;
						RS_array[j].op_type 		<= #1 0;
						RS_array[j].operation 		<= #1 0;

						RS_array[j].busy 			<= #1 0;
						RS_array[j].instr_type		<= #1 OTHER;

						RS_array[j].op1_ready 		<= #1 0;
						RS_array[j].op1_value 		<= #1 64'hB111_CAFE_CAFE_B111;
						RS_array[j].op1_PRF_index 	<= #1 0;

						RS_array[j].op2_ready 		<= #1 0;
						RS_array[j].op2_value 		<= #1 64'hB111_CAFE_CAFE_B111;
						RS_array[j].op2_PRF_index 	<= #1 0;

						RS_array[j].dest_PRF_index 	<= #1 0;

						RS_array[j].ROB_index 		<= #1 0;
						RS_array[j].next_pc 		<= #1 `ADDR_BITS'b0;
						RS_array[j].branch_target_addr	<= #1 `ADDR_BITS'b0;

						RS_array[j].branch_predicted_taken	<= #1 0;
						RS_array[j].branch_cond_op 	   <= #1 0;
						RS_array[j].branch_disp		   <= #1 16'b0;

						// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
						dispatch_free_list[j]	<= #1 1;	

						// set the awaken list bits in thread 0 to 0
						awaken_ALU_list[j]		<= #1 0;
						awaken_Mult_list[j]		<= #1 0;
						awaken_Branch_list[j]	<= #1 0;						
					end else begin
						RS_array[j] <= #1 n_RS_array[j];

						// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
						dispatch_free_list[j]	<= #1 n_dispatch_free_list[j];	

						// set the awaken list bits in thread 0 to 0
						awaken_ALU_list[j]		<= #1 n_awaken_ALU_list[j];
						awaken_Mult_list[j]		<= #1 n_awaken_Mult_list[j];
						awaken_Branch_list[j]	<= #1 n_awaken_Branch_list[j];
					end
				end
			end else if( branch_mispredict_0 && branch_mispredict_1) begin

				count_inst_t0 <= #1 0;
				count_inst_t1 <= #1 0;
				count 		  <= #1 0;

				for(int j=0; j<`RS_SIZE; j++) begin			

					RS_array[j].thread_ID 		<= #1 0;
					RS_array[j].op_type 		<= #1 0;
					RS_array[j].operation 		<= #1 0;

					RS_array[j].busy 			<= #1 0;
					RS_array[j].instr_type		<= #1 OTHER;

					RS_array[j].op1_ready 		<= #1 0;
					RS_array[j].op1_value 		<= #1 64'hB010_CAFE_CAFE_B101;
					RS_array[j].op1_PRF_index 	<= #1 0;

					RS_array[j].op2_ready 		<= #1 0;
					RS_array[j].op2_value 		<= #1 64'hB010_CAFE_CAFE_B101;
					RS_array[j].op2_PRF_index 	<= #1 0;

					RS_array[j].dest_PRF_index 	<= #1 0;

					RS_array[j].ROB_index 		<= #1 0;
					RS_array[j].next_pc 		<= #1 `ADDR_BITS'b0;
					RS_array[j].branch_target_addr	<= #1 `ADDR_BITS'b0;

					RS_array[j].branch_predicted_taken	<= #1 0;
					RS_array[j].branch_cond_op 	   <= #1 0;
					RS_array[j].branch_disp		   <= #1 16'b0;

					// set all the dispatch free-list bits to 1 (tells whether the slots in the RS are empty or not)
					dispatch_free_list[j]	<= #1 1;	

					// set the awaken list bits in thread 0 to 0
					awaken_ALU_list[j]		<= #1 0;
					awaken_Mult_list[j]		<= #1 0;
					awaken_Branch_list[j]	<= #1 0;
				end
			end // Branch Mispredict! ****************************************************************************** above
			else begin 	// What happens when there is no mispredict
				// update the RS array
				RS_array	 		<= #1 n_RS_array;

				// update the dispatch free-list bits here
				dispatch_free_list 	<= #1 n_dispatch_free_list;

				// update the awaken free-list bits here
				awaken_ALU_list	 	<= #1 n_awaken_ALU_list;
				awaken_Mult_list 	<= #1 n_awaken_Mult_list;
				awaken_Branch_list 	<= #1 n_awaken_Branch_list;

				// update status variables				
				full		 	<= #1 n_full;
				almost_full 	<= #1 n_almost_full;
				count 			<= #1 n_count;
				count_inst_t0 	<= #1 n_count_inst_t0;
				count_inst_t1 	<= #1 n_count_inst_t1;
			end
		end // else after reset
	end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// **** Replace the logic from always_ff block ***********************************************
	always_comb begin
		
		n_RS_array 				= RS_array;		
		n_dispatch_free_list    = dispatch_free_list;
		n_awaken_ALU_list       = awaken_ALU_list;
		n_awaken_Mult_list      = awaken_Mult_list;
		n_awaken_Branch_list    = awaken_Branch_list;		
		n_count_inst_t0 		= count_inst_t0;
		n_count_inst_t1 		= count_inst_t1;

		count_disp_t0 = 2'b0;
		count_disp_t1 = 2'b0;
		count_iss_t0 = 4'b0;
		count_iss_t1 = 4'b0;

		//n_count = count;		

		// ***** Issue to Functional Units *********************************************************************

		// handle ALU_gnt_0_encoded	
		if( ALU0_ready && ALU_gnt_0_valid ) begin

			issue_inst0.valid 			= 1'b1;
			issue_inst0.thread_ID		= RS_array[ALU_gnt_0_encoded].thread_ID;
			issue_inst0.instr_type		= RS_array[ALU_gnt_0_encoded].instr_type;
			issue_inst0.operation 		= RS_array[ALU_gnt_0_encoded].operation;

			issue_inst0.op1_value 		= RS_array[ALU_gnt_0_encoded].op1_value;
			issue_inst0.op2_value 		= RS_array[ALU_gnt_0_encoded].op2_value;
			issue_inst0.dest_PRF_index	= RS_array[ALU_gnt_0_encoded].dest_PRF_index;
			issue_inst0.ROB_index     = RS_array[ ALU_gnt_0_encoded].ROB_index;	

			issue_inst0.branch_predicted_taken 	= RS_array[ALU_gnt_0_encoded].branch_predicted_taken;
			issue_inst0.branch_target_addr 	= RS_array[ ALU_gnt_0_encoded].branch_target_addr;
			issue_inst0.branch_cond_op 			= RS_array[ALU_gnt_0_encoded].branch_cond_op;
			issue_inst0.branch_disp	 			= RS_array[ALU_gnt_0_encoded].branch_disp;
			issue_inst0.next_pc         = RS_array[ ALU_gnt_0_encoded].next_pc;

			n_RS_array[ ALU_gnt_0_encoded].busy 	= 1'b0;
			n_RS_array[ ALU_gnt_0_encoded].op_type	= INVALID;
			//n_RS_array[ ALU_gnt_0_encoded].op1_ready = 1'b0;	// *****
			//n_RS_array[ ALU_gnt_0_encoded].op2_ready = 1'b0;	// *****			

			n_dispatch_free_list[ ALU_gnt_0_encoded] = 1'b1;		// update the dispatch_free_list

			if(RS_array[ALU_gnt_0_encoded].thread_ID == 1'b0)
				count_iss_t0[0] = 1'b1;
			else begin
				count_iss_t1[0] = 1'b1;
			end
		end else begin

			issue_inst0.valid 			= 1'b0;
			issue_inst0.thread_ID		= 0;
			issue_inst0.instr_type		= OTHER;
			issue_inst0.operation 		= 0;

			issue_inst0.op1_value 		= `REG_BITS'hDEAD_DEAD_DEAD_DEAD;
			issue_inst0.op2_value 		= `REG_BITS'hDEAD_DEAD_DEAD_DEAD;
			issue_inst0.dest_PRF_index 	= {`PR_BITS{1'b0}};
			issue_inst0.ROB_index     = 0;

			issue_inst0.branch_predicted_taken 	= 0;
			issue_inst0.branch_target_addr 	= 64'hDEAD_BAAD_BAAD_AAAA;
			issue_inst0.branch_cond_op 		= 0;
			issue_inst0.branch_disp	 		= 0;	
			issue_inst0.next_pc         = 0;
		end		
		// handle ALU_gnt_1_encoded
		if( ALU1_ready && ALU_gnt_1_valid ) begin
			issue_inst1.valid 		= 1'b1;
			issue_inst1.thread_ID	= RS_array[ ALU_gnt_1_encoded].thread_ID;
			issue_inst1.instr_type	= RS_array[ ALU_gnt_1_encoded].instr_type;
			issue_inst1.operation 	= RS_array[ ALU_gnt_1_encoded].operation;

			issue_inst1.op1_value 		= RS_array[ ALU_gnt_1_encoded].op1_value;
			issue_inst1.op2_value 		= RS_array[ ALU_gnt_1_encoded].op2_value;
			issue_inst1.dest_PRF_index 	= RS_array[ ALU_gnt_1_encoded].dest_PRF_index;
			issue_inst1.ROB_index     = RS_array[ ALU_gnt_1_encoded].ROB_index;	

			issue_inst1.branch_predicted_taken 	= RS_array[ ALU_gnt_1_encoded].branch_predicted_taken;
			issue_inst1.branch_target_addr 	= RS_array[ ALU_gnt_1_encoded].branch_target_addr;
			issue_inst1.branch_cond_op 			= RS_array[ ALU_gnt_1_encoded].branch_cond_op;
			issue_inst1.branch_disp	 			= RS_array[ ALU_gnt_1_encoded].branch_disp;	
			issue_inst1.next_pc         = RS_array[ ALU_gnt_1_encoded].next_pc;

			n_RS_array[ ALU_gnt_1_encoded].busy 	 = 1'b0;
			n_RS_array[ ALU_gnt_1_encoded].op_type	= INVALID;
			//n_RS_array[ ALU_gnt_1_encoded].op1_ready = 1'b0;	// *****
			//n_RS_array[ ALU_gnt_1_encoded].op2_ready = 1'b0;	// *****

			n_dispatch_free_list[ ALU_gnt_1_encoded] = 1'b1;		// update the dispatch_free_list

			if(RS_array[ALU_gnt_1_encoded].thread_ID == 1'b0)
				count_iss_t0[1] = 1'b1;
			else begin
				count_iss_t1[1] = 1'b1;
			end

		end else begin

			issue_inst1.valid 			= 1'b0;
			issue_inst1.thread_ID		= 0;
			issue_inst1.instr_type		= OTHER;
			issue_inst1.operation 		= 0;

			issue_inst1.op1_value 		= `REG_BITS'hDEAD_DEAD_DEAD_DEAD;
			issue_inst1.op2_value 		= `REG_BITS'hDEAD_DEAD_DEAD_DEAD;
			issue_inst1.dest_PRF_index	= {`PR_BITS{1'b0}};			
			issue_inst1.ROB_index     = 0;

			issue_inst1.branch_predicted_taken 	= 0;
			issue_inst1.branch_target_addr 	= 64'hDEAD_BAAD_BAAD_BBBB;
			issue_inst1.branch_cond_op 		= 0;
			issue_inst1.branch_disp	 		= 0;	
			issue_inst1.next_pc         = 0;
		end
		
		// handle Mult_gnt_encoded
		if( Mult_ready && Mult_gnt_valid ) begin

			issue_inst2.valid 			= 1'b1;
			issue_inst2.thread_ID		= RS_array[ Mult_gnt_encoded].thread_ID;
			issue_inst2.instr_type		= RS_array[ Mult_gnt_encoded].instr_type;
			issue_inst2.operation 		= RS_array[ Mult_gnt_encoded].operation;

			issue_inst2.op1_value 		= RS_array[ Mult_gnt_encoded].op1_value;
			issue_inst2.op2_value 		= RS_array[ Mult_gnt_encoded].op2_value;
			issue_inst2.dest_PRF_index 	= RS_array[ Mult_gnt_encoded].dest_PRF_index;			
			issue_inst2.ROB_index     = RS_array[ Mult_gnt_encoded].ROB_index;	

			issue_inst2.branch_predicted_taken 	= RS_array[ Mult_gnt_encoded].branch_predicted_taken;
			issue_inst2.branch_target_addr 	= RS_array[ Mult_gnt_encoded].branch_target_addr;
			issue_inst2.branch_cond_op 		= RS_array[ Mult_gnt_encoded].branch_cond_op;
			issue_inst2.branch_disp	 		= RS_array[ Mult_gnt_encoded].branch_disp;
			issue_inst2.next_pc         = RS_array[ Mult_gnt_encoded].next_pc;

			n_RS_array[ Mult_gnt_encoded].busy 		= 1'b0;
			n_RS_array[ Mult_gnt_encoded].op_type 	= INVALID;
			//n_RS_array[ Mult_gnt_encoded].op1_ready = 1'b0;	// *****
			//n_RS_array[ Mult_gnt_encoded].op2_ready = 1'b0;	// *****

			n_dispatch_free_list[ Mult_gnt_encoded] = 1'b1;		// update the dispatch_free_list

			if(RS_array[Mult_gnt_encoded].thread_ID == 1'b0)
				count_iss_t0[2] = 1'b1;
			else begin
				count_iss_t1[2] = 1'b1;
			end

		end else begin

			issue_inst2.valid 			= 1'b0;
			issue_inst2.thread_ID		= 0;
			issue_inst2.instr_type		= OTHER;
			issue_inst2.operation 		= 0;

			issue_inst2.op1_value 		= `REG_BITS'hDEAD_0000_0000_DEAD;
			issue_inst2.op2_value 		= `REG_BITS'hDEAD_0000_0000_DEAD;
			issue_inst2.dest_PRF_index 	= {`PR_BITS{1'b0}};			
			issue_inst2.ROB_index     = 0;

			issue_inst2.branch_predicted_taken 	= 0;
			issue_inst2.branch_target_addr 	= 64'hDEAD_BAAD_BAAD_CCCC;
			issue_inst2.branch_cond_op 		= 0;
			issue_inst2.branch_disp	 		= 0;	
			issue_inst2.next_pc         = 0;
		end

		// handle Branch_gnt_1_encoded
		if(  Branch_ready && Branch_gnt_valid ) begin

			issue_inst3.valid 			= 1'b1;
			issue_inst3.thread_ID		= RS_array[ Branch_gnt_encoded].thread_ID;
			issue_inst3.instr_type		= RS_array[ Branch_gnt_encoded].instr_type;
			issue_inst3.operation 		= RS_array[ Branch_gnt_encoded].operation;

			issue_inst3.op1_value 		= RS_array[ Branch_gnt_encoded].op1_value;
			issue_inst3.op2_value 		= RS_array[ Branch_gnt_encoded].op2_value;
			issue_inst3.dest_PRF_index 	= RS_array[ Branch_gnt_encoded].dest_PRF_index;		
			issue_inst3.ROB_index     = RS_array[ Branch_gnt_encoded].ROB_index;	

			issue_inst3.branch_predicted_taken 	= RS_array[ Branch_gnt_encoded].branch_predicted_taken;
			issue_inst3.branch_target_addr 	= RS_array[ Branch_gnt_encoded].branch_target_addr;
			issue_inst3.branch_cond_op 		= RS_array[ Branch_gnt_encoded].branch_cond_op;
			issue_inst3.branch_disp	 		= RS_array[ Branch_gnt_encoded].branch_disp;
			issue_inst3.next_pc         = RS_array[ Branch_gnt_encoded].next_pc;

			n_RS_array[ Branch_gnt_encoded].busy 	    = 1'b0;
			n_RS_array[ Branch_gnt_encoded].op_type 	= INVALID;
			//n_RS_array[ Branch_gnt_encoded].op1_ready   = 1'b0;
			//n_RS_array[ Branch_gnt_encoded].op2_ready   = 1'b0;

			n_dispatch_free_list[ Branch_gnt_encoded]   = 1'b1;	// update the dispatch_free_list

			if(RS_array[Branch_gnt_encoded].thread_ID == 1'b0)
				count_iss_t0[3] = 1'b1;
			else begin
				count_iss_t1[3] = 1'b1;
			end

		end else begin

			issue_inst3.valid 			    = 1'b0;
			issue_inst3.thread_ID			= 0;
			issue_inst3.instr_type			= OTHER;
			issue_inst3.operation 			= 0;

			issue_inst3.op1_value 			= `REG_BITS'hDEAD_0000_0000_DEAD;
			issue_inst3.op2_value 			= `REG_BITS'hDEAD_0000_0000_DEAD;
			issue_inst3.dest_PRF_index 		= {`PR_BITS{1'b0}};
			issue_inst3.ROB_index     = 0;

			issue_inst3.branch_predicted_taken 	= 0;
			issue_inst3.branch_target_addr 	= 64'hDEAD_BAAD_BAAD_DDDD;
			issue_inst3.branch_cond_op 		= 0;
			issue_inst3.branch_disp	 		= 0;
			issue_inst3.next_pc         = 0;
		end
		// ***** Dispatch instructions to RS array **********************************************************************

		if( dispatch_inst0.dispatch && dispatch_gnt_0_valid) begin

			// Update the dispatch free list once the instructions are valid and dispatched to the RS

			n_dispatch_free_list[ dispatch_gnt_0_encoded ] 		= 0;	// dispatch free_list
			n_RS_array[ dispatch_gnt_0_encoded ].thread_ID 		= dispatch_inst0.thread_ID;
			n_RS_array[ dispatch_gnt_0_encoded ].op_type 		= dispatch_inst0.op_type;
			n_RS_array[ dispatch_gnt_0_encoded ].operation 		= dispatch_inst0.operation;			

			n_RS_array[ dispatch_gnt_0_encoded ].busy			= 1;
			n_RS_array[ dispatch_gnt_0_encoded ].instr_type	 	= dispatch_inst0.instr_type;

			n_RS_array[ dispatch_gnt_0_encoded ].op1_ready 		= dispatch_inst0.op1_ready;
			n_RS_array[ dispatch_gnt_0_encoded ].op1_value 		= dispatch_inst0.op1_value;
			n_RS_array[ dispatch_gnt_0_encoded ].op1_PRF_index	= dispatch_inst0.op1_PRF_index;

			n_RS_array[ dispatch_gnt_0_encoded ].op2_ready 		= dispatch_inst0.op2_ready;
			n_RS_array[ dispatch_gnt_0_encoded ].op2_value 		= dispatch_inst0.op2_value;
			n_RS_array[ dispatch_gnt_0_encoded ].op2_PRF_index 	= dispatch_inst0.op2_PRF_index;

			n_RS_array[ dispatch_gnt_0_encoded ].dest_PRF_index = dispatch_inst0.dest_PRF_index;	

			n_RS_array[ dispatch_gnt_0_encoded ].ROB_index 		= dispatch_inst0.ROB_index;
			n_RS_array[ dispatch_gnt_0_encoded ].next_pc 		= dispatch_inst0.next_pc;
			n_RS_array[ dispatch_gnt_0_encoded ].branch_target_addr = dispatch_inst0.branch_target_addr;

			n_RS_array[ dispatch_gnt_0_encoded ].branch_predicted_taken  = dispatch_inst0.branch_predicted_taken;
			n_RS_array[ dispatch_gnt_0_encoded ].branch_cond_op 	     = dispatch_inst0.branch_cond_op;
			n_RS_array[ dispatch_gnt_0_encoded ].branch_target_addr      = dispatch_inst0.branch_target_addr;
			n_RS_array[ dispatch_gnt_0_encoded ].branch_disp             = dispatch_inst0.branch_disp;
			
			if(dispatch_inst0.thread_ID == 1'b0) begin
				count_disp_t0[0] = 1'b1;
			end else begin
				count_disp_t1[0] = 1'b1;
			end				
		end					

		if( dispatch_inst1.dispatch && dispatch_gnt_1_valid) begin

			// Update the dispatch free list once the instructions are valid and dispatched to the RS

			n_dispatch_free_list[ dispatch_gnt_1_encoded ]		= 0;   // dispatch free_list
			n_RS_array[ dispatch_gnt_1_encoded ].thread_ID		= dispatch_inst1.thread_ID;
			n_RS_array[ dispatch_gnt_1_encoded ].op_type     	= dispatch_inst1.op_type;
			n_RS_array[ dispatch_gnt_1_encoded ].operation 		= dispatch_inst1.operation;

			n_RS_array[ dispatch_gnt_1_encoded ].busy	 		= 1;
			n_RS_array[ dispatch_gnt_1_encoded ].instr_type	 	= dispatch_inst1.instr_type;

			n_RS_array[ dispatch_gnt_1_encoded ].op1_ready 		= dispatch_inst1.op1_ready;
			n_RS_array[ dispatch_gnt_1_encoded ].op1_value 		= dispatch_inst1.op1_value;
			n_RS_array[ dispatch_gnt_1_encoded ].op1_PRF_index	= dispatch_inst1.op1_PRF_index;

			n_RS_array[ dispatch_gnt_1_encoded ].op2_ready 		= dispatch_inst1.op2_ready;
			n_RS_array[ dispatch_gnt_1_encoded ].op2_value 		= dispatch_inst1.op2_value;
			n_RS_array[ dispatch_gnt_1_encoded ].op2_PRF_index 	= dispatch_inst1.op2_PRF_index;

			n_RS_array[ dispatch_gnt_1_encoded ].dest_PRF_index = dispatch_inst1.dest_PRF_index;

			n_RS_array[ dispatch_gnt_1_encoded ].ROB_index 		= dispatch_inst1.ROB_index;
			n_RS_array[ dispatch_gnt_1_encoded ].next_pc 		= dispatch_inst1.next_pc;
			n_RS_array[ dispatch_gnt_1_encoded ].branch_target_addr		= dispatch_inst1.branch_target_addr;

			n_RS_array[ dispatch_gnt_1_encoded ].branch_predicted_taken = dispatch_inst1.branch_predicted_taken;
			n_RS_array[ dispatch_gnt_1_encoded ].branch_cond_op			= dispatch_inst1.branch_cond_op;
			n_RS_array[ dispatch_gnt_1_encoded ].branch_target_addr		= dispatch_inst1.branch_target_addr;
			n_RS_array[ dispatch_gnt_1_encoded ].branch_disp          = dispatch_inst1.branch_disp;

			if(dispatch_inst1.thread_ID == 1'b0) begin
				count_disp_t0[1] = 1'b1;
			end else begin
				count_disp_t1[1] = 1'b1;
			end			
		end

		// Update RS entries with CDB 0 if possible
		if( CDB_0.valid ) begin
			for(int i=0; i< `RS_SIZE; i++) begin
				// match CDB 0's tag with 1st operand for each instruction in RS
				if( n_RS_array[i].busy && (CDB_0.PRN == n_RS_array[i].op1_PRF_index) && !n_RS_array[i].op1_ready ) begin
					n_RS_array[i].op1_ready = 1;
					n_RS_array[i].op1_value = CDB_0.FU_result;
				end 

				// match CDB 0's tag with 2nd operand for each instruction in RS
				if( n_RS_array[i].busy && (CDB_0.PRN == n_RS_array[i].op2_PRF_index) && !n_RS_array[i].op2_ready) begin
					n_RS_array[i].op2_ready = 1;
					n_RS_array[i].op2_value = CDB_0.FU_result;
				end
			end // end of for-loop
		end

		// Update RS entries with CDB 1 if possible
		if( CDB_1.valid) begin		
			for(int i=0; i< `RS_SIZE; i++) begin
				// match CDB 1's tag with 1st operand for each instruction in RS
				if( n_RS_array[i].busy && (CDB_1.PRN == n_RS_array[i].op1_PRF_index) && !n_RS_array[i].op1_ready) begin
					n_RS_array[i].op1_ready = 1;
					n_RS_array[i].op1_value = CDB_1.FU_result;
				end 
				// match CDB 1's tag with 2nd operand for each instruction in RS
				if( n_RS_array[i].busy && (CDB_1.PRN == n_RS_array[i].op2_PRF_index) && !n_RS_array[i].op2_ready) begin
					n_RS_array[i].op2_ready = 1;
					n_RS_array[i].op2_value = CDB_1.FU_result;
				end
			end	// end of for-loop		
		end
		// Find the total change in the number of busy RS entries
		case(count_disp_t0)
			2'b00:	count_inc_t0 = 0;
			2'b01:	count_inc_t0 = 1;
			2'b10:	count_inc_t0 = 1;
			2'b11:	count_inc_t0 = 2;
		endcase

		case(count_disp_t1)
			2'b00:	count_inc_t1 = 0;
			2'b01:	count_inc_t1 = 1;
			2'b10:	count_inc_t1 = 1;
			2'b11:	count_inc_t1 = 2;
		endcase

		case(count_iss_t0)
			4'b0000: count_dec_t0 = 0;
			4'b1000: count_dec_t0 = 1;
			4'b0100: count_dec_t0 = 1;
			4'b0010: count_dec_t0 = 1;
			4'b0001: count_dec_t0 = 1;
			4'b1100: count_dec_t0 = 2;
			4'b1010: count_dec_t0 = 2;
			4'b1001: count_dec_t0 = 2;
			4'b0110: count_dec_t0 = 2;
			4'b0101: count_dec_t0 = 2;
			4'b0011: count_dec_t0 = 2;
			4'b1110: count_dec_t0 = 3;
			4'b1101: count_dec_t0 = 3;
			4'b1011: count_dec_t0 = 3;
			4'b0111: count_dec_t0 = 3;
			4'b1111: count_dec_t0 = 4;
			default: count_dec_t0 = 0;
		endcase

		case(count_iss_t1)
			4'b0000: count_dec_t1 = 0;
			4'b1000: count_dec_t1 = 1;
			4'b0100: count_dec_t1 = 1;
			4'b0010: count_dec_t1 = 1;
			4'b0001: count_dec_t1 = 1;
			4'b1100: count_dec_t1 = 2;
			4'b1010: count_dec_t1 = 2;
			4'b1001: count_dec_t1 = 2;
			4'b0110: count_dec_t1 = 2;
			4'b0101: count_dec_t1 = 2;
			4'b0011: count_dec_t1 = 2;
			4'b1110: count_dec_t1 = 3;
			4'b1101: count_dec_t1 = 3;
			4'b1011: count_dec_t1 = 3;
			4'b0111: count_dec_t1 = 3;
			4'b1111: count_dec_t1 = 4;
			default: count_dec_t1 = 0;
		endcase

		// keep track of the awaken list
	
		for( int j=0; j<`RS_SIZE; j++) begin
		// Operation type enum: INVALID 0, ALU 1, MULT 2, BRANCH_OP 3
		// Calculate ALU instructions to be awakened

		// NOTE: All the n_awaken_lists are updated with awaken_list at the beginning. No need to do it again here.
		// NOTE: The 'if' conditions must have n_RS_array, not RS_array, if you want instructions that were just dispatched to
		//		 wake up in the same cycle. There's no need to have them wait and wake up in the next cycle if it can be done earlier.
		// NOTE: The 'if' body must have n_RS_array, not RS_array, because the dispatched instructions are stored in n_RS_array. They
		//		 are only assigned to RS_array on the next posedge of clock.
			if( n_RS_array[j].op_type == ALU ) begin 
				n_awaken_ALU_list[j]    = n_RS_array[j].op1_ready && n_RS_array[j].op2_ready;
				n_awaken_Mult_list[j]   = 0;
        n_awaken_Branch_list[j] = 0;
				/*n_awaken_Mult_list[j]   = awaken_Mult_list[j];
				n_awaken_Branch_list[j] = awaken_Branch_list[j];*/
			end

			// Calculate Mult instructions to be awakened
			else if ( n_RS_array[j].op_type == MULT ) begin
				n_awaken_ALU_list[j]    = 0;
        n_awaken_Mult_list[j]   = n_RS_array[j].op1_ready && n_RS_array[j].op2_ready;
        n_awaken_Branch_list[j] = 0;
			end

			// Calculate Branch instructions to be awakened
			else if ( n_RS_array[j].op_type == BRANCH_OP ) begin
				
        n_awaken_ALU_list[j]    = 0;
        n_awaken_Mult_list[j]   = 0;
        n_awaken_Branch_list[j] = n_RS_array[j].op1_ready && n_RS_array[j].op2_ready;
				
			end

			else begin
				n_awaken_ALU_list[j]    = 0;
				n_awaken_Mult_list[j]   = 0;
				n_awaken_Branch_list[j] = 0;			
			end
		end

		n_count_inst_t0 = count_inst_t0 + count_inc_t0 - count_dec_t0;
		n_count_inst_t1 = count_inst_t1 + count_inc_t1 - count_dec_t1;
		n_count 		= n_count_inst_t0 + n_count_inst_t1;

		n_full 			= (n_count_inst_t0 + n_count_inst_t1) >= `RS_SIZE-2;
		n_almost_full 	= (n_count_inst_t0 + n_count_inst_t1) == (`RS_SIZE - 3);
		
	end


////////////////////////// debugging ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	// // debugging outputs	
	// assign RS_array_debug 			= RS_array;
	// assign dispatch_free_list_debug = dispatch_free_list;
	// assign awaken_ALU_list_debug    = awaken_ALU_list;
	// assign awaken_Mult_list_debug   = awaken_Mult_list;
	// assign awaken_Branch_list_debug = awaken_Branch_list;
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// convert a one-hot encoded input to binary index output
module encoder (
	input  logic [`RS_SIZE-1:0] encoder_input,
	output logic [`RS_SIZE-1:0] encoder_output,
	output logic valid
	); 

    logic [`RS_BITS-1:0] encoder_output_tmp;

	always_comb
	begin
		encoder_output_tmp = 0;		

		for( int i=0; i < `RS_SIZE; i++) begin

			if( encoder_input[i] == 1'b1 ) begin
				encoder_output_tmp = i;				
			end
   		end

		encoder_output = encoder_output_tmp;		

	end
	assign valid = (encoder_input == 0) ? 1'b0 : 1'b1;

endmodule