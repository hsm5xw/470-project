//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,// 
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module ex_stage(
			input         clock,               	// system clock
			input         reset,               	// system reset

			input 				mispredict_0,
			input 				mispredict_1,
			// ***** New Inputs ( struct inputs from RS) *************************************************************************
	 		input ISSUE_RS issue_ALU_0,		// issued instruction to ALU_0 
	 		input ISSUE_RS issue_ALU_1,		// issued instruction to ALU_1
			input ISSUE_RS issue_Mult,		// issued instruction to Mult
	 		input ISSUE_RS issue_Branch,		// issued instruction to Branch_calc

	 		input FU_RESULT   LSQ_in_0,
	 		input FU_RESULT   LSQ_in_1,

			// ***** Inputs from the CDB arbiter **********************************************************************************
			//input logic ALU_0_sent;
			//input logic ALU_1_sent;
			//input logic Mult_sent;
			// input logic branch_sent;
		

     	output logic ALU_0_ready,              	// Determines whether a particular Functional Unit is ready or not
     	output logic ALU_1_ready,
     	output logic Mult_ready,
      output logic Branch_ready,

      output logic ALU_0_sent,
			output logic ALU_1_sent,
			output logic Mult_sent,
			output logic Branch_sent,

     	output CDB cdb_0,
     	output CDB cdb_1

			//output FU_RESULT  ALU_0_CDB,		// from Functional Unit to CDB
			//output FU_RESULT  FU_RESULT_1
               );


	logic [63:0] ALU_0_result;
	logic [63:0] ALU_1_result;
	logic [63:0] Mult_result, n_Mult_result, Mult_done_result;

	logic [2:0] Mult_count, n_Mult_count;

	logic Mult_result_ready, n_Mult_result_ready, Mult_nuke;

	logic ALU_0_in_use, ALU_1_in_use;
	logic Mult_in_use, Branch_in_use;

	logic n_ALU_0_in_use, n_ALU_1_in_use;
	logic n_Mult_in_use, n_Branch_in_use;

	FU_RESULT ALU_0_CDB;
	FU_RESULT ALU_1_CDB;
	FU_RESULT Mult_CDB;

	BRANCH_RESULT Branch_result;
	logic Branch_done;

	logic Mult_thread_ID, n_Mult_thread_ID;
	logic [`ROB_BITS-1:0] Mult_ROB_index, n_Mult_ROB_index;
	logic [`PR_BITS-1:0] Mult_PRF_index, n_Mult_PRF_index;

	logic ALU_0_done;
	logic ALU_1_done;

	// ***** Ready register for ALU_1
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			ALU_0_in_use 	<= #1 1'b0;
		end
		else 
			ALU_0_in_use  <= #1 n_ALU_0_in_use;
	end

	// ***** Ready register for ALU_1
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			ALU_1_in_use 	<= #1 1'b0;
		end
		else 
			ALU_1_in_use  <= #1 n_ALU_1_in_use;
	end

	// ***** Ready register for Branch
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			Branch_in_use 	<= #1 1'b0;
		end
		else 
			Branch_in_use   <= #1 n_Branch_in_use;
	end

	// ***** Ready register for Mult
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			Mult_in_use 	<= #1 1'b0;
		end
		else 
			Mult_in_use   <= #1 n_Mult_in_use;
	end

	assign ALU_0_done = ALU_0_in_use || issue_ALU_0.valid;
	assign ALU_1_done = ALU_1_in_use || issue_ALU_1.valid;
	assign Branch_done = Branch_in_use || issue_Branch.valid;

	always_comb begin
		n_Mult_in_use = Mult_in_use;
		n_ALU_0_in_use = ALU_0_in_use;
		n_ALU_1_in_use = ALU_1_in_use;
		n_Branch_in_use = Branch_in_use;
		
		if (issue_ALU_0.valid) begin
			n_ALU_0_in_use = 1;
		end
		if (ALU_0_sent)
			n_ALU_0_in_use = 0;

		if (issue_ALU_1.valid) begin
			n_ALU_1_in_use = 1;
		end
		if (ALU_1_sent)
			n_ALU_1_in_use = 0;

		if (issue_Mult.valid) begin
			n_Mult_in_use = 1;
		end
		if (Mult_sent)
			n_Mult_in_use = 0;

		if (issue_Branch.valid) begin
			n_Branch_in_use = 1;
		end
		if (Branch_sent)
			n_Branch_in_use = 0;

		if((!issue_ALU_0.thread_ID && mispredict_0) || (issue_ALU_0.thread_ID && mispredict_1))
			n_ALU_0_in_use = 0;
		if((!issue_ALU_1.thread_ID && mispredict_0) || (issue_ALU_1.thread_ID && mispredict_1))
			n_ALU_1_in_use = 0;
		if((!Mult_thread_ID && mispredict_0) || (Mult_thread_ID && mispredict_1))
			n_Mult_in_use = 0;
		if((!issue_Branch.thread_ID && mispredict_0) || (issue_Branch.thread_ID && mispredict_1))
			n_Branch_in_use = 0;

		Mult_ready   = !n_Mult_in_use;
		ALU_0_ready  = !n_ALU_0_in_use;
		ALU_1_ready  = !n_ALU_1_in_use;
		Branch_ready = !n_Branch_in_use;
	end

	//
	// instantiate ALU_0
	//
	alu ALU_0 (	// Inputs
			 .opa(    issue_ALU_0.op1_value ),
			 .opb(    issue_ALU_0.op2_value ),
			 .func(   issue_ALU_0.operation ),

			 // Output
			 .result(  ALU_0_result )
		  );

	//
	// instantiate ALU_1
	//
	alu ALU_1 (	 // Inputs
			 .opa(    issue_ALU_1.op1_value ),
			 .opb(    issue_ALU_1.op2_value ),
			 .func(   issue_ALU_1.operation ),

			 // Output
			 .result( ALU_1_result )
		  );


	//
	// instantiate Multiplier
	//
	mult Mult (	 // Inputs
			 .clock(  clock ),
			 .reset(  reset ),
			 .nuke(   Mult_nuke), 
			 .mcand(  issue_Mult.op1_value ),
			 .mplier( issue_Mult.op2_value ),
			 .start(  issue_Mult.valid ),		// Maybe want this to be high for only
			 					//   the cycle that a multiply is issued
			 // Output
			 .product( Mult_done_result ),
			 .done(    Mult_done )
		  );

	// next state logic
	always_comb begin
		Mult_nuke = 0;

		n_Mult_thread_ID    = Mult_thread_ID;
		n_Mult_count        = Mult_count;
		n_Mult_result_ready = Mult_result_ready;
		n_Mult_ROB_index    = Mult_ROB_index;
		n_Mult_PRF_index    = Mult_PRF_index;
		n_Mult_result       = Mult_result;
		
		if(Mult_count < 7)
			n_Mult_count = Mult_count + 1;

		if((Mult_count < 7) || Mult_sent) begin
			n_Mult_result_ready = 0;
			n_Mult_ROB_index    = `ROB_SIZE-1;
			n_Mult_PRF_index    = `ZERO_REG_PRN;
		end
		else if(Mult_done) begin
			n_Mult_result_ready = 1;
			n_Mult_result       = Mult_done_result;
		end

		if(issue_Mult.valid) begin
			n_Mult_thread_ID = issue_Mult.thread_ID;
			n_Mult_ROB_index = issue_Mult.ROB_index;
			n_Mult_PRF_index = issue_Mult.dest_PRF_index;
		end

		if((mispredict_0 && (Mult_thread_ID == 0)) ||
			 (mispredict_1 && (Mult_thread_ID == 1))) begin
			n_Mult_thread_ID    = 1'b0;
			n_Mult_count        = 3'h7;
			n_Mult_result_ready = 1'b0;
			n_Mult_ROB_index    = 0;
			n_Mult_PRF_index    = `ZERO_REG_PRN;
			n_Mult_result       = 0;
			Mult_nuke           = 1;
		end
	end

	// ***** Ready register for Mult
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			Mult_thread_ID    <= #1 1'b0;
			Mult_count        <= #1 3'h7;
			Mult_result_ready <= #1 1'b0;
			Mult_ROB_index    <= #1 0;
			Mult_PRF_index    <= #1 `ZERO_REG_PRN;
			Mult_result       <= #1 0;
		end
		else begin
			Mult_thread_ID    <= #1 n_Mult_thread_ID;
			Mult_count        <= #1 n_Mult_count;
			Mult_result_ready <= #1 n_Mult_result_ready;
			Mult_ROB_index    <= #1 n_Mult_ROB_index;
			Mult_PRF_index    <= #1 n_Mult_PRF_index;
			Mult_result       <= #1 n_Mult_result;
		end
	end

	//
	// instantiate Branch Unit
	//
	br_unit Branch (	 // Inputs
			 .clock(  clock ),
			 .reset(  reset ),
			 .br_in(  issue_Branch ),	

			 // Output
			 .br_out( Branch_result)
		  );

	// ******************************************************************************************

	// Pass values through to CDB_arbiter
	always_comb begin
		ALU_0_CDB.FU_done = ALU_0_done;
		ALU_0_CDB.result  = ALU_0_result;
		ALU_0_CDB.thread_ID = issue_ALU_0.thread_ID;
		ALU_0_CDB.PRN_index = issue_ALU_0.dest_PRF_index;
		ALU_0_CDB.ROB_index = issue_ALU_0.ROB_index;


		ALU_1_CDB.FU_done = ALU_1_done;
		ALU_1_CDB.result  = ALU_1_result;
		ALU_1_CDB.thread_ID = issue_ALU_1.thread_ID;
		ALU_1_CDB.PRN_index = issue_ALU_1.dest_PRF_index;
		ALU_1_CDB.ROB_index = issue_ALU_1.ROB_index;

		Mult_CDB.FU_done   = Mult_result_ready;
	  Mult_CDB.result    = Mult_result;
		Mult_CDB.thread_ID = Mult_thread_ID;
		Mult_CDB.PRN_index = Mult_PRF_index;
		Mult_CDB.ROB_index = Mult_ROB_index;
	end

	//
	// instantiate CDB arbiter
	//

	CDB_arbiter cdb_arb (	 // Inputs
			 .clock(  clock ),
			 .reset(  reset ),
			 .mispredict_0( mispredict_0 ),
			 .mispredict_1( mispredict_1 ),
			 .LSQ_in_0(  LSQ_in_0 ),	
			 .LSQ_in_1(  LSQ_in_1 ),	
			 .ALU_in_0(  ALU_0_CDB ),	
			 .ALU_in_1(  ALU_1_CDB ),	
			 .mult_in(   Mult_CDB  ),	
			 .branch_in( Branch_result ),
			 .branch_in_done(Branch_done),	

			 // Output
			 .ALU_0_sent ( ALU_0_sent ),
			 .ALU_1_sent ( ALU_1_sent ),
			 .mult_sent  ( Mult_sent  ),
			 .branch_sent( Branch_sent),

			 .cdb_0 (cdb_0),
			 .cdb_1 (cdb_1)
		  );
endmodule // module ex_stage