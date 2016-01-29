module testbench();
  logic clock;
  logic reset;

  // ***** New Inputs ( struct inputs from RS) *************************************************************************
  ISSUE_RS issue_ALU_0;   // issued instruction to ALU_0 
  ISSUE_RS issue_ALU_1;   // issued instruction to ALU_1
  ISSUE_RS issue_Mult;    // issued instruction to Mult
  ISSUE_RS issue_Branch;    // issued instruction to Branch_calc

  FU_RESULT   LSQ_in_0;
  FU_RESULT   LSQ_in_1;

  // ***** Inputs from the CDB arbiter *********************************************************************************
  logic ALU_0_ready;               // Determines whether a particular Functional Unit is ready or not
  logic ALU_1_ready;
  logic Mult_ready;
  logic Branch_ready;

  logic mispredict_0;
  logic mispredict_1;

  CDB cdb_0;
  CDB cdb_1;
  
  ex_stage execute(
      .clock(clock),                // system clock
      .reset(reset),                // system reset

      .mispredict_0( mispredict_0 ),
      .mispredict_1( mispredict_1 ),
      .issue_ALU_0(issue_ALU_0),   // issued instruction to ALU_0 
      .issue_ALU_1(issue_ALU_1),   // issued instruction to ALU_1
      .issue_Mult(issue_Mult),     // issued instruction to Mult
      .issue_Branch(issue_Branch), // issued instruction to Branch_calc

      .LSQ_in_0(LSQ_in_0),
      .LSQ_in_1(LSQ_in_1),

      .ALU_0_ready(ALU_0_ready),                // Determines whether a particular Functional Unit is ready or not
      .ALU_1_ready(ALU_1_ready),
      .Mult_ready(Mult_ready),
      .Branch_ready(Branch_ready),

      .cdb_0(cdb_0),
      .cdb_1(cdb_1)
    );

  always begin
    #5;
    clock = ~clock;
  end

  task reset_inputs;
    LSQ_in_0 = 0;
    LSQ_in_1 = 0;
    
    issue_ALU_0 = 0;
    issue_ALU_1 = 0;
    issue_Mult = 0;
    issue_Branch = 0;

    mispredict_0 = 0;
    mispredict_1 = 0;
  endtask

  task reset_ex_stage;
    reset = 1;
    reset_inputs();
    @(negedge clock);
    @(negedge clock);
    reset = 0;
  endtask

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

// ***********************************************************************

	// issue ALU_0 instruction once 
	task issue_ALU_0_instr_once;

		begin
			@(negedge clock);

			issue_ALU_0.thread_ID  = 0;
			issue_ALU_0.instr_type = OTHER;		
			issue_ALU_0.operation  = ALU_ADDQ;
			
			issue_ALU_0.op1_value  = 64'h0000_0000_0000_0002;
			issue_ALU_0.op2_value  = 64'h0000_0000_0000_0003;
			issue_ALU_0.dest_PRF_index 	= 0;

			issue_ALU_0.ROB_index      	= 0;
			issue_ALU_0.next_pc	   	= 0;
			issue_ALU_0.branch_target_addr	= 0;

			issue_ALU_0.valid		= 1;
		
			issue_ALU_0.branch_predicted_taken = 0;
			issue_ALU_0.branch_cond_op	   = 0;
			issue_ALU_0.branch_disp		   = 0;
			
			@(negedge clock);
      @(negedge clock);
			issue_ALU_0.valid		= 0;		
		end
	endtask


	// issue ALU_1 instruction once 
	task issue_ALU_1_instr_once;

		begin
			@(negedge clock);

			issue_ALU_1.thread_ID  = 0;
			issue_ALU_1.instr_type = OTHER;		
			issue_ALU_1.operation  = ALU_ADDQ;
			
			issue_ALU_1.op1_value  = 64'h0000_0000_0000_0002;
			issue_ALU_1.op2_value  = 64'h0000_0000_0000_0003;
			issue_ALU_1.dest_PRF_index 	= 0;

			issue_ALU_1.ROB_index      	= 0;
			issue_ALU_1.next_pc	   	= 0;
			issue_ALU_1.branch_target_addr	= 0;

			issue_ALU_1.valid		= 1;
		
			issue_ALU_1.branch_predicted_taken = 0;
			issue_ALU_1.branch_cond_op	   = 0;
			issue_ALU_1.branch_disp		   = 0;
			
			@(negedge clock);
      @(negedge clock);
			issue_ALU_1.valid		= 0;		
		end
	endtask



	// issue Multiplier instruction once 
	task issue_Mult_instr_once;

		begin
			@(negedge clock);

			issue_Mult.thread_ID  		= 0;
			issue_Mult.instr_type 		= OTHER;		
			issue_Mult.operation  		= ALU_MULQ;
			
			issue_Mult.op1_value  		= 64'h0000_0000_0000_0002;
			issue_Mult.op2_value  		= 64'h0000_0000_0000_0003;
			issue_Mult.dest_PRF_index 	= 0;

			issue_Mult.ROB_index      	= 0;
			issue_Mult.next_pc	   	= 0;
			issue_Mult.branch_target_addr	= 0;

			issue_Mult.valid		= 1;
		
			issue_Mult.branch_predicted_taken = 0;
			issue_Mult.branch_cond_op	  = 0;
			issue_Mult.branch_disp		  = 0;
			
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
      @(negedge clock);

			issue_Mult.valid		  = 0;		
		end
	endtask



	// issue Multiplier instruction once 
	task issue_Mult_instr_once2;

		begin
			@(negedge clock);

			issue_Mult.thread_ID  		= 0;
			issue_Mult.instr_type 		= OTHER;		
			issue_Mult.operation  		= ALU_MULQ;
			
			issue_Mult.op1_value  		= 64'h0000_0000_0000_0003;
			issue_Mult.op2_value  		= 64'h0000_0000_0000_0003;
			issue_Mult.dest_PRF_index 	= 0;

			issue_Mult.ROB_index      	= 0;
			issue_Mult.next_pc	   	= 0;
			issue_Mult.branch_target_addr	= 0;

			issue_Mult.valid		= 1;
		
			issue_Mult.branch_predicted_taken = 0;
			issue_Mult.branch_cond_op	  = 0;
			issue_Mult.branch_disp		  = 0;
			
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
			@(negedge clock);
      @(negedge clock);

			issue_Mult.valid		  = 0;		
		end
	endtask


	// issue Branch instruction once 
	task issue_Branch_instr_once;

		begin
			@(negedge clock);

			issue_Branch.thread_ID  	= 0;
			issue_Branch.instr_type 	= OTHER;		
			issue_Branch.operation  	= ALU_ADDQ;
			
			issue_Branch.op1_value  	= 64'h0000_0000_0000_0002;
			issue_Branch.op2_value  	= 64'h0000_0000_0000_0003;
			issue_Branch.thread_ID  	= 0;
			issue_Branch.instr_type 	= OTHER;		
			issue_Branch.operation  	= ALU_ADDQ;
			
			issue_Branch.op1_value  	= 64'h0000_0000_0000_0002;
			issue_Branch.op2_value  	= 64'h0000_0000_0000_0003;
			issue_Branch.dest_PRF_index 	= 0;

			issue_Branch.ROB_index      	= 0;
			issue_Branch.next_pc	   	= 0;
			issue_Branch.branch_target_addr	= 0;

			issue_Branch.valid		= 1;
			issue_Branch.dest_PRF_index 	= 0;

			issue_Branch.ROB_index      	= 0;
			issue_Branch.next_pc	   	= 0;
			issue_Branch.branch_target_addr	= 0;

			issue_Branch.valid		= 1;
		
			issue_Branch.branch_predicted_taken = 0;
			issue_Branch.branch_cond_op	    = 0;
			issue_Branch.branch_disp	    = 0;
			
			@(negedge clock);
      @(negedge clock);
			issue_Branch.valid		= 0;		
		end
	endtask


	// issue LSQ_0  
	task issue_LSQ_0_once;

		input LSQ_0_valid;

		begin
			@(negedge clock);
			LSQ_in_0.result    =   64'h0000_0000_0000_AAAA;
			LSQ_in_0.PRN_index =   0;
			LSQ_in_0.ROB_index =   0;
			LSQ_in_0.thread_ID =   0;
			LSQ_in_0.FU_done      =   LSQ_0_valid;
		
			@(negedge clock);
			LSQ_in_0.FU_done	   =   0;		
		end
	endtask


	// issue LSQ_1  
	task issue_LSQ_1_once;

		input LSQ_1_valid;

		begin
			@(negedge clock);
			LSQ_in_1.result    =   64'h0000_0000_0000_AAAA;
			LSQ_in_1.PRN_index =   0;
			LSQ_in_1.ROB_index =   0;
			LSQ_in_1.thread_ID =   0;
			LSQ_in_1.FU_done      =   LSQ_1_valid;
		
			@(negedge clock);
			LSQ_in_1.FU_done   =   0;		
		end
	endtask




/*
	// issue instrution multiple times
	task issue_instruction_loop;

		input [`RS_BITS:0] num_inst;
		input [2:0] num_issue;

		begin

			for(int i=0; i< num_inst; i= i+1) begin
				@(negedge clock);

				issue_ALU_0.thread_ID  = 0;
				issue_ALU_0.instr_type = OTHER;		
				issue_ALU_0.operation  = ALU_ADDQ;
			
				issue_ALU_0.op1_value  = 64'h0000_0000_0000_0002;
				issue_ALU_0.op2_value  = 64'h0000_0000_0000_0003;
				issue_ALU_0.dest_PRF_index 	= 0;

				issue_ALU_0.ROB_index      	= 0;
				issue_ALU_0.next_pc	   	= 0;
				issue_ALU_0.branch_target_addr	= 0;

				issue_ALU_0.valid		= 1;
		
				issue_ALU_0.branch_predicted_taken = 0;
				issue_ALU_0.branch_cond_op	   = 0;
				issue_ALU_0.branch_disp		   = 0;

			end
			@(negedge clock);

		end
	endtask

*/





// *************************************************************************






  initial 
  	begin
		/*
		$monitor("time:%2.0d rst:%b alu_0:%b alu_1:%b mult:%b br: %b\n", $time, reset, ALU_0_ready, ALU_1_ready, Mult_ready, Branch_ready,
			    "cdb_0.thread_ID:%b cdb_0.FU_result:%2.0d cdb_0.ROB_index:%2.0d cdb_0.PRN_index:%2.0d cdb_0.mispredict:%b", cdb_0.thread_ID, cdb_0.FU_result, cdb_0.ROB_index, cdb_0.PRN, cdb_0.mispredict,
			    "cdb_1.thread_ID:%b cdb_1.FU_result:%2.0d cdb_1.ROB_index:%2.0d cdb_1.PRN_index:%2.0d cdb_1.mispredict:%b", cdb_1.thread_ID, cdb_1.FU_result, cdb_1.ROB_index, cdb_1.PRN, cdb_1.mispredict
		    );
		*/
		clock = 0;
		reset_ex_stage();
		@(negedge clock);

    $display("test delayed broadcast for mult");
    issue_Mult.valid = 1;
    issue_Mult.op1_value = 5;
    issue_Mult.op2_value = 4;

    LSQ_in_0.FU_done = 1;
    LSQ_in_0.result  = 64'hABCD_ABCD_ABCD_ABCD;
    LSQ_in_1.FU_done = 1;
    LSQ_in_1.result  = 64'hBBBB_AAAA_DDDD_CCCC;

    @(negedge clock);
    issue_Mult.valid = 0;

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

    LSQ_in_0.FU_done = 0;
    LSQ_in_1.FU_done = 0;
    @(posedge clock);
    assert_and_message( cdb_0.valid && cdb_0.FU_result == 20, "delayed broadcast for mult failed");

    reset_ex_stage();

		// test issueing ALU_0 instruction one at a time

		$display("test ALU_0 instruction one at a time");
		issue_ALU_0_instr_once();

		assert_and_message( cdb_0.valid && (cdb_0.FU_result == 64'h0000_0000_0000_0005) , "@@@Failed: Testing ALU 0 fails");
		reset_ex_stage();


		// test issueing Multiplier instruction one at a time

		$display("test Mult instruction one at a time");
		issue_Mult_instr_once();

		assert_and_message( cdb_0.valid && (cdb_0.FU_result == 64'h0000_0000_0000_0006) , "@@@Failed: Testing Mult fails2");

		// test issueing Multiplier instruction twice

		$display("test Mult instruction twice");
		issue_Mult_instr_once();
		assert_and_message( cdb_0.valid && (cdb_0.FU_result == 64'h0000_0000_0000_0006) , "@@@Failed: Testing Mult fails3");

		issue_Mult_instr_once2();

		assert_and_message( cdb_0.valid && (cdb_0.FU_result == 64'h0000_0000_0000_0009) , "@@@Failed: Testing Mult fails4");
		reset_ex_stage();

    $display("Test if all of the issues/LSQ dones broadcast correctly, in the correct order");
    issue_ALU_0.valid  = 1;
    issue_ALU_0.op1_value = 3;
    issue_ALU_0.op2_value = 4;
    issue_ALU_0.operation = ALU_ADDQ;


    issue_ALU_1.valid  = 1;
    issue_ALU_1.op1_value = 5;
    issue_ALU_1.op2_value = 4;
    issue_ALU_1.operation = ALU_SUBQ;

    issue_Mult.valid     = 1;
    issue_Mult.op1_value = 5;
    issue_Mult.op2_value = 6;

    issue_Branch.valid   = 1;
    issue_Branch.next_pc = 64'hAAAA_AAAA_AAAA_AAAA;
    issue_Branch.op1_value = 4;
    issue_Branch.op2_value = 4;
    issue_Branch.branch_disp = 4;
    issue_Branch.operation = ALU_ADDQ;
    issue_Branch.instr_type = UNCOND_BRANCH;

    LSQ_in_0.FU_done   = 1;
    LSQ_in_0.result    = 64'hAAAA_BEEF_BEEF_BEEF;
    LSQ_in_1.FU_done   = 1;
    LSQ_in_1.result    = 64'hBBBB_BEEF_BEEF_BEEF;

    @(negedge clock);
    issue_Mult.valid   = 0;

    @(negedge clock);
    @(negedge clock);
    assert_and_message(cdb_0.valid == 1 && cdb_1.valid == 1 && cdb_0.FU_result == 64'hAAAA_BEEF_BEEF_BEEF 
                    && cdb_1.FU_result == 64'hBBBB_BEEF_BEEF_BEEF, "LSQ_1 or LSQ_0 did not broadcast");

    LSQ_in_0.FU_done = 0;
    LSQ_in_1.FU_done = 0;

    @(negedge clock);
    assert_and_message(cdb_0.valid == 1 && cdb_1.valid == 1 && cdb_0.FU_result == 64'hAAAA_AAAA_AAAA_AABA 
                    && cdb_1.FU_result == 64'h7, "Branch or ALU_0 did not broadcast");

    issue_ALU_0.valid = 0;
    issue_Branch.valid = 0;

    @(negedge clock);
    @(negedge clock);
    assert_and_message(cdb_0.valid == 1 && cdb_1.valid == 0 && cdb_0.FU_result == 1, 
                      "ALU_1 did not broadcast");
    @(negedge clock);
    @(negedge clock);
    @(posedge clock);
    assert_and_message(cdb_0.valid == 1 && cdb_1.valid == 1 && cdb_0.FU_result == 30 
                    && cdb_1.FU_result == 1, "MULT or ALU_1 did not broadcast");

    reset_ex_stage();


    $display("mispredict 0 test");
    mispredict_0 = 1;
    issue_ALU_0.valid = 1;
    issue_ALU_0.thread_ID = 0;
    issue_ALU_0.op1_value = 2;
    issue_ALU_0.op2_value = 3;
    issue_ALU_0.operation = ALU_ADDQ;

    issue_ALU_1.valid = 1;
    issue_ALU_1.thread_ID = 1;
    issue_ALU_1.op1_value = 5;
    issue_ALU_1.op2_value = 6;
    issue_ALU_1.operation = ALU_ADDQ;

    @(negedge clock);
    @(negedge clock);

    assert_and_message(cdb_0.valid && cdb_0.FU_result == 11 && !cdb_1.valid, "mispredict 0 didn't work");

	    	$display("@@@PASSED!");
	    	$finish;
  	end // initial
endmodule