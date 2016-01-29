`timescale 1ns/100ps

module testbench();
	logic clock;
	logic reset;
	CDB CDB_0;
	CDB CDB_1;
	DISPATCH_ROB disp_ROB_0;
	DISPATCH_ROB disp_ROB_1;

	ROB_RRAT head;
	ROB_RRAT head_plus1;
	ROB_IF head_branch;
	ROB_IF head_plus1_branch;
	logic [`ROB_BITS-1:0] tail_index;
	logic [`ROB_BITS:0] count;
	logic full;
	logic almost_full; // one away from full
	logic halt;
	logic nuke;
	logic is_fork;
	logic [`ADDR_BITS-1:0] fork_addr;


	rob #(.THREAD_ID(0)) ROB_0 (
		.clock(clock), 
		.reset(reset), 
		.CDB_0(CDB_0),
		.CDB_1(CDB_1),
		.disp_ROB_0(disp_ROB_0),
		.disp_ROB_1(disp_ROB_1),
		.head(head),
		.head_plus1(head_plus1),
		.head_branch(head_branch),
		.head_plus1_branch(head_plus1_branch),
		.tail_index(tail_index),
		.count(count),		
		.full(full),
		.almost_full(almost_full),
		.halt(halt),
		.nuke(nuke), 
		.is_fork(is_fork),
		.fork_addr(fork_addr)
	);

	always begin
		#5;
		clock = ~clock;
	end

	task reset_inputs;
		CDB_0.FU_result = 64'hAAAA_AAAA_AAAA_AAAA;
		CDB_0.PRN = 0;
		CDB_0.ROB_index = 0;
		CDB_0.branch_actually_taken = 0;
		CDB_0.valid = 0;
		CDB_0.mispredict = 0;
		CDB_0.thread_ID = 0;    

		CDB_1.FU_result = 64'hBBBB_BBBB_BBBB_BBBB;
		CDB_1.PRN = 1;
		CDB_1.ROB_index = 1;
		CDB_1.branch_actually_taken = 0;
		CDB_1.valid = 0;
		CDB_1.mispredict = 0;
		CDB_1.thread_ID = 0;

		disp_ROB_0.thread_ID = 0;
		disp_ROB_0.ARN_dest = 0;
		disp_ROB_0.PRN_dest = 0;
		disp_ROB_0.dispatch = 0;
		disp_ROB_0.instr_type = OTHER;
		disp_ROB_0.dispatch_pc = 0;

		disp_ROB_1.thread_ID = 0;
		disp_ROB_1.ARN_dest = 0;
		disp_ROB_1.PRN_dest = 0;
		disp_ROB_1.dispatch = 0;
		disp_ROB_1.instr_type = OTHER;
		disp_ROB_1.dispatch_pc = 0;
	endtask

	task reset_ROB;
		reset = 1;
		reset_inputs();
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

	task dispatch_loop;
		input dispatch_in;
		input [`AR_BITS-1:0] ARN_start;
		input [`AR_BITS-1:0] PRN_start;
		input [`ROB_BITS:0] num_inst;
		begin
			for(int i=0; i<num_inst; i=i+1+dispatch_in) begin
				@(negedge clock);
				disp_ROB_0.dispatch = 1;
				disp_ROB_1.dispatch = dispatch_in;
				disp_ROB_0.ARN_dest = ARN_start+i;
				disp_ROB_0.PRN_dest = PRN_start+i;
				disp_ROB_1.ARN_dest = ARN_start+i+1;
				disp_ROB_1.PRN_dest = PRN_start+i+1;
			end
			@(negedge clock);
			disp_ROB_0.dispatch = 0;
			disp_ROB_1.dispatch = 0;
		end
	endtask

	task dispatch_each_port;
		input a, b;
		begin
			reset_ROB();
			@(negedge clock);
			disp_ROB_0.dispatch = a;
			disp_ROB_1.dispatch = b;
		end
	endtask

	task finish_execution_loop;
		input CDB_0_valid;
		input CDB_1_valid;
		input [`ROB_BITS-1:0] ROB_start;
		input [`ROB_BITS:0] num_inst;
		begin
			for(int i=0; i<num_inst; i=i+CDB_0_valid+CDB_1_valid) begin
				@(negedge clock);
				CDB_0.valid = CDB_0_valid;
				CDB_1.valid = CDB_1_valid;
				CDB_0.ROB_index = ROB_start+i;
				CDB_1.ROB_index = CDB_0_valid ? CDB_0.ROB_index+1 : CDB_0.ROB_index;
			end
			@(negedge clock);
			CDB_0.valid = 0;
			CDB_1.valid = 0;
		end
	endtask

	// if dispatch_in is high, num_inst must be even
	task dispatch_and_finish_execution_loop;
		input dispatch_in;
		input [`AR_BITS-1:0] ARN_start;
		input [`AR_BITS-1:0] PRN_start;
		input [`ROB_BITS:0] start_CDB;
		input CDB_0_valid;
		input CDB_1_valid;
		input [`ROB_BITS-1:0] ROB_start;
		input [`ROB_BITS*2:0] num_inst;
		begin
			for(int i=0, j=0; i<num_inst; i=i+1+dispatch_in) begin
				@(negedge clock);
				disp_ROB_0.dispatch = 1;
				disp_ROB_1.dispatch = dispatch_in;
				disp_ROB_0.ARN_dest = ARN_start+i;
				disp_ROB_0.PRN_dest = PRN_start+i;
				disp_ROB_1.ARN_dest = ARN_start+i+1;
				disp_ROB_1.PRN_dest = PRN_start+i+1;
				if(i >= start_CDB) begin
					CDB_0.valid = CDB_0_valid;
					CDB_1.valid = CDB_1_valid;
					CDB_0.ROB_index = ROB_start+j;
					CDB_1.ROB_index = CDB_0_valid ? CDB_0.ROB_index+1 : CDB_0.ROB_index;
					j = j+CDB_0_valid+CDB_1_valid;
				end
			end
			@(negedge clock);
			CDB_0.valid = 0;
			CDB_1.valid = 0;
			disp_ROB_0.dispatch = 0;
			disp_ROB_1.dispatch = 0;
		end
	endtask

	task check_correct_thread;
		begin
			@(negedge clock);
			reset_ROB();
			@(negedge clock);
			disp_ROB_0.dispatch = 1;
			disp_ROB_1.dispatch = 1;
			disp_ROB_0.ARN_dest = 3;
			disp_ROB_0.PRN_dest = 4;
			disp_ROB_1.ARN_dest = 5;
			disp_ROB_1.PRN_dest = 6;
			@(negedge clock);
			assert_and_message(tail_index==2 && count==2, "");
			disp_ROB_0.dispatch = 0;
			disp_ROB_1.dispatch = 0;
			CDB_0.valid = 1;
			CDB_1.valid = 1;
			CDB_0.ROB_index = 1;
			CDB_1.ROB_index = 0;
			CDB_0.thread_ID = 1;
			CDB_1.thread_ID = 1;
			@(negedge clock);
			assert_and_message(tail_index==2 && count==2 && !head.committed && !head_plus1.committed, "");
		end
	endtask


	task check_correct_value;
		begin
			@(negedge clock);
			reset_ROB();
			@(negedge clock);
			disp_ROB_0.dispatch = 1;
			disp_ROB_1.dispatch = 1;
			disp_ROB_0.ARN_dest = 3;
			disp_ROB_0.PRN_dest = 4;
			disp_ROB_1.ARN_dest = 5;
			disp_ROB_1.PRN_dest = 6;
			@(negedge clock);
			assert_and_message(tail_index==2 && count==2, "");
			disp_ROB_0.dispatch = 0;
			disp_ROB_1.dispatch = 0;
			CDB_0.valid = 1;
			CDB_1.valid = 1;
			CDB_0.ROB_index = 1;
			CDB_1.ROB_index = 0;
			@(negedge clock);
			assert_and_message(tail_index==2 && count==0 && head.committed && head_plus1.committed && head.ARN_dest==3 && 
			                   head_plus1.ARN_dest==5 && head.PRN_dest==4 && head_plus1.PRN_dest==6, "");
			@(negedge clock);
			assert_and_message(tail_index==2 && count==0 && !head.committed && !head_plus1.committed, "a");
		end
	endtask

	task branch_dispatch_and_finish_execution;
		input branch_0_in;
		input branch_1_in;
		input mispredict_0_in;
		input mispredict_1_in;
		begin
			@(negedge clock);
			disp_ROB_0.PRN_dest = 3;
			disp_ROB_1.PRN_dest = 4;
			disp_ROB_0.dispatch = 1;
			disp_ROB_1.dispatch = 1;
			disp_ROB_0.dispatch_pc = 5;
			disp_ROB_1.dispatch_pc = 6;
			disp_ROB_0.instr_type = branch_0_in ? BRANCH : OTHER;
			disp_ROB_1.instr_type = branch_1_in ? BRANCH : OTHER;
			@(negedge clock);
			disp_ROB_0.dispatch = 0;
			disp_ROB_1.dispatch = 0;
			CDB_0.valid = 1;
			CDB_1.valid = 1;
			CDB_0.ROB_index = 1;
			CDB_1.ROB_index = 0;
			CDB_0.FU_result = 7;
			CDB_1.FU_result = 8;
			CDB_0.mispredict = mispredict_1_in;
			CDB_1.mispredict = mispredict_0_in;
			@(negedge clock);

		end
	endtask

	initial 
	begin
		clock = 0;
		reset_ROB();
		// $monitor("Time:%4.0f reset:%b disp0:%b ARN0:%2.0d PRN0:%2.0d ", $time, reset, disp_ROB_0.dispatch, disp_ROB_0.ARN_dest, disp_ROB_0.PRN_dest, 
		//          "disp1:%b ARN1:%2.0d PRN1:%2.0d ", disp_ROB_1.dispatch, disp_ROB_1.ARN_dest, disp_ROB_1.PRN_dest,
		//          "CDB0:%b ROB0:%2.0d CDB1:%b ROB1:%2.0d ", CDB_0.valid, CDB_0.ROB_index, CDB_1.valid, CDB_1.ROB_index, 
		//          "comm0:%b ARN0:%2.0d PRN0:%2.0d ", head.committed, head.ARN_dest, head.PRN_dest,
		//          "comm1:%b ARN1:%2.0d PRN1:%2.0d ", head_plus1.committed, head_plus1.ARN_dest, head_plus1.PRN_dest,
		//          "tail:%2.0d count:%2.0d full:%b almost:%b \n", tail_index, count, full, almost_full);

		$display("dispatch one at a time until almost full");
		dispatch_loop(0, 1, 30, `ROB_SIZE-1);
		assert_and_message(!full && almost_full && tail_index==`ROB_SIZE-1 && count==`ROB_SIZE-1, "ROB one from full");
		dispatch_loop(0, 32, 1, 1);
		assert_and_message(full && !almost_full && tail_index==0 && count==`ROB_SIZE, "ROB full");
		reset_ROB();

		$display("dispatch two at a time until two away from full");
		dispatch_loop(1, 1, 30, `ROB_SIZE-2);
		assert_and_message(!full && !almost_full && tail_index==`ROB_SIZE-2 && count==`ROB_SIZE-2, "ROB two from full");
		dispatch_loop(1, 32, 1, 2);
		assert_and_message(full && !almost_full && tail_index==0 && count==`ROB_SIZE, "ROB full");

		$display("finish execution from CDB_0 and CDB_1");
		finish_execution_loop(1, 1, 0, 2);
		assert_and_message(!full && !almost_full && !tail_index && head.committed && head_plus1.committed && count==`ROB_SIZE-2, "");

		$display("finish execution from CDB_0 only");
		finish_execution_loop(1, 0, 2, 2);
		assert_and_message(!full && !almost_full && !tail_index && head.committed && !head_plus1.committed && count==`ROB_SIZE-4, "");

		$display("finish execution from CDB_1 only");
		finish_execution_loop(0, 1, 4, 2);
		assert_and_message(!full && !almost_full && !tail_index && head.committed && !head_plus1.committed && count==`ROB_SIZE-6, "");

		$display("finish execution all inst except head");
		finish_execution_loop(0, 1, 7, 9);
		assert_and_message(!full && !almost_full && !tail_index && !head.committed && !head_plus1.committed && count==`ROB_SIZE-6, "count should stay the same");

		$display("finish execution of head");
		finish_execution_loop(1, 0, 6, 1);
		assert_and_message(!full && !almost_full && !tail_index && head.committed && head_plus1.committed && count==`ROB_SIZE-8, "count should stay the same");
		repeat((`ROB_SIZE-8)/2) @(negedge clock);
		assert_and_message(!full && !almost_full && !tail_index && head.committed && head_plus1.committed && count==0, "ROB should be empty");
		@(negedge clock);
		assert_and_message(!full && !almost_full && !tail_index && !head.committed && !head_plus1.committed && count==0, "ROB should be empty");
		reset_ROB();

		$display("Dispatches until ROB full, then commits 2, then 1, then 2....");
		dispatch_loop(1, 1, 30, `ROB_SIZE);
		assert_and_message(full && !almost_full && tail_index==0 && count==`ROB_SIZE, "ROB full");
		for (int i=0; i<`ROB_SIZE-3; i=i+3) begin
			finish_execution_loop(1, 1, i, 2);
			assert_and_message(!full && !almost_full && !tail_index && head.committed && head_plus1.committed && count==`ROB_SIZE-i-2, "");
			finish_execution_loop(1, 0, i+2, 1);
			assert_and_message(!full && !almost_full && !tail_index && head.committed && !head_plus1.committed && count==`ROB_SIZE-i-3, "");
		end
		reset_ROB();

		$display("Dispatch 2 and commits 2, tail wrap around");
		dispatch_and_finish_execution_loop(1, 0, 30, 2, 1, 1, 0, `ROB_SIZE + 4);
		assert_and_message(!full && !almost_full && tail_index==4 && head.committed && head_plus1.committed && count==2, "");
		reset_ROB();


		$display("Fills ROB, then dispatch 2 and commits 2, tail wrap around");
		dispatch_loop(1, 1, 30, `ROB_SIZE);
		dispatch_and_finish_execution_loop(1, 0, 30, 0, 1, 1, 0, `ROB_SIZE + 6);
		assert_and_message(full && !almost_full && tail_index==6 && head.committed && head_plus1.committed && count==`ROB_SIZE, "");
		reset_ROB();


		// Test if the ROB says to halt when a halt instruction commits
		$display("Sees if ROB halt works");
		disp_ROB_0.instr_type = HALT;
		dispatch_loop(0, 1, 30, 1);
		finish_execution_loop(1, 0, 0, 1);
		assert_and_message(!halt && !head.committed, "Dispatch 0 halt did not work");
		reset_ROB();

		disp_ROB_1.instr_type = HALT;
		dispatch_loop(1, 1, 30, 2);
		finish_execution_loop(1, 0, 0, 2);
		assert_and_message(!halt && !head.committed && !head_plus1.committed, "Dispatch 1 halt did not work");

		disp_ROB_0.instr_type = OTHER;
		disp_ROB_1.instr_type = OTHER;
		reset_ROB();

		// Also if the halt instruction is at the head, the next instruction shouldn't commit
		$display("If the halt instruction is at head, the next instruction shouldn't commit");
		disp_ROB_0.instr_type = HALT;
		dispatch_loop(1, 1, 30, 2);
		//finish_execution_loop(1, 1, 0, 2);
		@(negedge clock);
		assert_and_message(halt && head.committed && !head_plus1.committed, "Commited halt instruction didn't tell processor to halt");

		disp_ROB_0.instr_type = OTHER;
		reset_ROB();


		// Test if the ROB tries to commit 2 instructions when only 1 is in the ROB (almost_empty)
		$display("Make the ROB have only 1 element. Commit 2 instructions");
		dispatch_loop(0, 1, 30, 1);
		finish_execution_loop(1, 1, 0, 2);
		assert_and_message(!full && !almost_full && (tail_index==1) && head.committed && !head_plus1.committed && count==0, "ROB should be empty");
		reset_ROB();


		// Test if the ROB tries to commit 1 instruction and dispatch 1 instruction when only 1 is in the ROB (almost_empty)
		$display("Make the ROB have only 1 element. Commit 1 instruction and dispatch 1 instruction");
		dispatch_loop(0, 1, 30, 1);
		dispatch_and_finish_execution_loop(0, 0, 30, 0, 1, 0, 0, 1);
		assert_and_message(!full && !almost_full && (tail_index==2) && head.committed && !head_plus1.committed && count==1, "ROB should be have size 1");	
		reset_ROB();

		// Test if the ROB tries to commit 1 instruction and dispatch 2 instruction when only 1 is in the ROB (almost_empty)
		$display("Make the ROB have only 1 element. Commit 1 instruction and dispatch 2 instructions");
		dispatch_loop(0, 1, 30, 1);
		dispatch_and_finish_execution_loop(1, 0, 30, 0, 1, 0, 0, 2);
		assert_and_message(!full && !almost_full && (tail_index==3) && head.committed && !head_plus1.committed && count==2, "ROB should be have size 2");	
		reset_ROB();

		// Branch mispredict
		branch_dispatch_and_finish_execution(0, 0, 0, 0);
		assert_and_message(head.committed && head_plus1.committed && !head_branch.is_branch && !head_plus1_branch.is_branch && !head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.pc == 5 && head_plus1_branch.pc == 6, "Branch and PC test 1");

		reset_ROB();
		branch_dispatch_and_finish_execution(0, 1, 0, 1);
		assert_and_message(head.committed && head_plus1.committed && !head_branch.is_branch && head_plus1_branch.is_branch && !head_branch.mispredict && 
		                   head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 2");

		reset_ROB();
		branch_dispatch_and_finish_execution(0, 1, 0, 0);
		assert_and_message(head.committed && head_plus1.committed && !head_branch.is_branch && head_plus1_branch.is_branch && !head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 3");		

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 0, 0, 0);
		assert_and_message(head.committed && head_plus1.committed && head_branch.is_branch && !head_plus1_branch.is_branch && !head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 4");		

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 0, 1, 0);
		assert_and_message(head.committed && !head_plus1.committed && head_branch.is_branch && !head_plus1_branch.is_branch && head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 5");		

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 1, 0, 0);
		assert_and_message(head.committed && head_plus1.committed && head_branch.is_branch && head_plus1_branch.is_branch && !head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 6");	

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 1, 0, 1);
		assert_and_message(head.committed && head_plus1.committed && head_branch.is_branch && head_plus1_branch.is_branch && !head_branch.mispredict &&
		                   head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 7");		

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 1, 1, 0);
		assert_and_message(head.committed && !head_plus1.committed && head_branch.is_branch && !head_plus1_branch.is_branch && head_branch.mispredict &&
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 8");		

		reset_ROB();
		branch_dispatch_and_finish_execution(1, 1, 1, 1);
		assert_and_message(head.committed && !head_plus1.committed && head_branch.is_branch && !head_plus1_branch.is_branch && head_branch.mispredict && 
		                   !head_plus1_branch.mispredict && head_branch.target_addr == 8 && head_plus1_branch.target_addr == 7, "Branch and PC test 9");		

		$display("test read ports");
		dispatch_each_port(1, 1);
		@(negedge clock);
		assert_and_message(count==2, "");

		dispatch_each_port(1, 0);
		@(negedge clock);
		assert_and_message(count==1, "");

		dispatch_each_port(0, 1);
		@(negedge clock);
		assert_and_message(count==1, "");

		dispatch_each_port(0, 0);
		@(negedge clock);
		assert_and_message(count==0, "");

		dispatch_each_port(1, 1);
		disp_ROB_0.thread_ID = 0;
		disp_ROB_1.thread_ID = 1;
		@(negedge clock);
		assert_and_message(count==1, "");

		check_correct_value();
		check_correct_thread();
		$display("@@@PASSED!");
		$finish;
	end // initial
endmodule