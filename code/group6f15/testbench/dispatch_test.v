module testbench();
	logic clock;
	logic reset;
	
	logic stall_0, stall_1, ROB_0_full, ROB_0_almost_full;
	logic mispredict_ROB_0, ROB_1_full, ROB_1_almost_full;
	logic mispredict_ROB_1, RS_full, RS_almost_full, LSQ_full, LSQ_almost_full;

	logic [`ROB_BITS-1:0] ROB_0_tail, ROB_1_tail;

	ID_DISPATCH id_disp_0;
	ID_DISPATCH id_disp_1;

	DISPATCH_ROB disp_ROB_0;
	DISPATCH_ROB disp_ROB_1;

	DISPATCH_RS disp_RS_0;
	DISPATCH_RS disp_RS_1;

	DISPATCH_LSQ disp_LSQ_0;
	DISPATCH_LSQ disp_LSQ_1;
	
	PRF_DISPATCH PRF_out_0; 
	PRF_DISPATCH PRF_out_1;

	dispatch disp (
		.clock(clock), 
		.reset(reset),
		.id_disp_0(id_disp_0),
		.id_disp_1(id_disp_1), 
		.stall_0(stall_0),
		.stall_1(stall_1),
		.mispredict_ROB_0(mispredict_ROB_0), 
		.mispredict_ROB_1(mispredict_ROB_1), 
		.PRF_out_0(PRF_out_0), 
		.PRF_out_1(PRF_out_1), 
		.disp_ROB_0(disp_ROB_0), 
		.disp_ROB_1(disp_ROB_1), 
		.disp_RS_0(disp_RS_0), 
		.disp_RS_1(disp_RS_1), 
		.disp_LSQ_0(disp_LSQ_0), 
		.disp_LSQ_1(disp_LSQ_1),
		.ROB_0_tail(ROB_0_tail),
		.ROB_1_tail(ROB_1_tail),
		.ROB_0_full(ROB_0_full),
		.ROB_0_almost_full(ROB_0_almost_full),
		.ROB_1_full(ROB_1_full),
		.ROB_1_almost_full(ROB_1_almost_full),
		.RS_full(RS_full),
		.RS_almost_full(RS_almost_full),
		.LSQ_full(LSQ_full),
		.LSQ_almost_full(LSQ_almost_full)
	);

	logic [63:0] mem_disp_0;
	logic [63:0] br_disp_0;
	logic [63:0] alu_imm_0;

	logic [63:0] mem_disp_1;
	logic [63:0] br_disp_1;
	logic [63:0] alu_imm_1;



	always begin
		#5;
		clock = ~clock;
	end

	task reset_inputs;
		id_disp_0.ARN_dest = 0;
		id_disp_0.PRN_dest = 15;
		id_disp_0.opa_PRN = 45;
		id_disp_0.opb_PRN = 46;
		id_disp_0.instr = 0;
		id_disp_0.instr_type = OTHER;
		id_disp_0.pc = 32'hAAAA_AAAA;
		id_disp_0.next_pc = 32'hAAAA_AAAE;
		id_disp_0.branch_target_addr = 32'hBBBB_BBBB;
		id_disp_0.opa_select = 0;
		id_disp_0.opb_select = 0;
		id_disp_0.thread_ID = 0;
		id_disp_0.alu_func = 0;
		id_disp_0.rd_mem = 0;
		id_disp_0.wr_mem = 0;
		id_disp_0.ldl_mem = 0;
		id_disp_0.stc_mem = 0;
		id_disp_0.valid = 1;
		id_disp_0.branch_taken = 0;

		id_disp_1.ARN_dest = 0;
		id_disp_1.PRN_dest = 15;
		id_disp_1.opa_PRN = 45;
		id_disp_1.opb_PRN = 46;
		id_disp_1.instr = 0;
		id_disp_1.instr_type = OTHER;
		id_disp_1.pc = 32'hAAAA_AAAA;
		id_disp_1.next_pc = 32'hAAAA_AAAE;
		id_disp_1.branch_target_addr = 32'hBBBB_BBBB;
		id_disp_1.opa_select = 0;
		id_disp_1.opb_select = 0;
		id_disp_1.thread_ID = 0;
		id_disp_1.alu_func = 0;
		id_disp_1.rd_mem = 0;
		id_disp_1.wr_mem = 0;
		id_disp_1.ldl_mem = 0;
		id_disp_1.stc_mem = 0;
		id_disp_1.valid = 1;
		id_disp_1.branch_taken = 0;

		mispredict_ROB_0 = 0;
		mispredict_ROB_1 = 0;

		ROB_0_tail = 0;
		ROB_1_tail = 0;

		PRF_out_0.ready_opa = 0;
		PRF_out_0.value_opa = 8'hBB;
		PRF_out_0.ready_opb = 1;
		PRF_out_0.value_opb = 8'hFF;

		PRF_out_1.ready_opa = 1;
		PRF_out_1.value_opa = 16'hBBBB;
		PRF_out_1.ready_opb = 0;
		PRF_out_1.value_opb = 16'hFFFF;

		mem_disp_0 = { {48{id_disp_0.instr[15]}}, id_disp_0.instr[15:0] };
		br_disp_0  = { {41{id_disp_0.instr[20]}}, id_disp_0.instr[20:0], 2'b00 };
		alu_imm_0  = { 56'b0, id_disp_0.instr[20:13] };
	
		mem_disp_1 = { {48{id_disp_1.instr[15]}}, id_disp_0.instr[15:0] };
		br_disp_1  = { {41{id_disp_1.instr[20]}}, id_disp_0.instr[20:0], 2'b00 };
		alu_imm_1  = { 56'b0, id_disp_1.instr[20:13] };

		ROB_0_full = 0;
		ROB_1_full = 0;
		RS_full = 0;
		LSQ_full = 0;

		ROB_0_almost_full = 0;
		ROB_1_almost_full = 0;
		RS_almost_full = 0;
		LSQ_almost_full = 0;

	endtask

	task reset_DISPATCH;
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

	task check_no_dispatches_0;
		assert_and_message(!disp_ROB_0.dispatch, "ROB_0 was dispatched to still!");
		assert_and_message(!disp_RS_0.dispatch, "RS_0 was dispatched to still!");
		assert_and_message(!disp_LSQ_0.dispatch, "LSQ_0 was dispatched to still!");
	endtask
	task check_no_dispatches_1;
		assert_and_message(!disp_ROB_1.dispatch, "ROB_1 was dispatched to still!");
		assert_and_message(!disp_RS_1.dispatch, "RS_1 was dispatched to still!");
		assert_and_message(!disp_LSQ_1.dispatch, "LSQ_1 was dispatched to still!");
	endtask
	
	task check_things_passed_0;
		$display("ALU_OPA_IS_REGA");
		id_disp_0.opa_select = ALU_OPA_IS_REGA;
		@(negedge clock);
		assert_and_message(!disp_RS_0.op1_ready, "op1 erronously ready!");
		assert_and_message(disp_RS_0.op1_value == 8'hBB, "op1 value incorrect!");

		$display("ALU_OPA_IS_MEM_DISP");
		id_disp_0.opa_select = ALU_OPA_IS_MEM_DISP;
		@(negedge clock);
		assert_and_message(!disp_RS_0.op1_ready, "op1 erronously ready!");

		$display("ALU_OPA_IS_NPC");
		id_disp_0.opa_select = ALU_OPA_IS_NPC;
		@(negedge clock);
		assert_and_message(disp_RS_0.op1_ready, "op1 erronously not ready!");
		assert_and_message(disp_RS_0.op1_value == id_disp_0.next_pc, "op1 value not next_pc!");
		
		$display("ALU_OPA_IS_NOT3");
		id_disp_0.opa_select = ALU_OPA_IS_NOT3;
		@(negedge clock);
		assert_and_message(disp_RS_0.op1_ready, "op1 erronously not ready!");
		assert_and_message(disp_RS_0.op1_value == ~64'h3, "op1 value incorrect!");
		
		
		$display("ALU_OPB_IS_REGB");
		id_disp_0.opb_select = ALU_OPB_IS_REGB;
		@(negedge clock);
		assert_and_message(disp_RS_0.op2_ready, "op2 erronously not ready!");
		assert_and_message(disp_RS_0.op2_value == 8'hFF, "op2 value incorrect!");
		
		$display("ALU_OPB_IS_ALU_IMM");
		id_disp_0.opb_select = ALU_OPB_IS_ALU_IMM;
		@(negedge clock);
		assert_and_message(disp_RS_0.op2_ready, "op2 erronously not ready!");
		assert_and_message(disp_RS_0.op2_value == alu_imm_0, "op2 value incorrect!");
		
		$display("ALU_OPB_IS_BR_DISP");
		id_disp_0.opb_select = ALU_OPB_IS_BR_DISP;
		@(negedge clock);
		assert_and_message(!disp_RS_0.op2_ready, "op1 erronously ready!");
		assert_and_message(disp_RS_0.op2_value == 8'hBB, "op1 value incorrect!");
		
	endtask

	task check_dispatch_to_correct_0;
		$display("Both LSQ ops");
		id_disp_0.rd_mem = 1;
		id_disp_1.wr_mem = 1;
		@(negedge clock);
		assert_and_message(disp_ROB_0.dispatch, "ROB_0 was not dispatched to still!");
		assert_and_message(!disp_RS_0.dispatch, "RS_0 was dispatched to still!");
		assert_and_message(disp_LSQ_0.dispatch, "LSQ_0 was not dispatched to still!");
		assert_and_message(disp_ROB_1.dispatch, "ROB_1 was not dispatched to still!");
		assert_and_message(!disp_RS_1.dispatch, "RS_1 was dispatched to still!");
		assert_and_message(disp_LSQ_1.dispatch, "LSQ_1 was not dispatched to still!");
		
		$display("Both RS ops");
		id_disp_0.rd_mem = 0;
		id_disp_1.wr_mem = 0;
		id_disp_0.instr_type = BRANCH;
		id_disp_0.ARN_dest = `ZERO_REG;
		id_disp_1.ARN_dest = 12;
		@(negedge clock);
		assert_and_message(disp_ROB_1.dispatch, "ROB_0 was not dispatched to still!");
		assert_and_message(disp_RS_1.dispatch, "RS_0 was not dispatched to still!");
		assert_and_message(!disp_LSQ_1.dispatch, "LSQ_0 was not dispatched to still!");
		assert_and_message(disp_ROB_1.dispatch, "ROB_1 was not dispatched to still!");
		assert_and_message(disp_RS_1.dispatch, "RS_1 was not dispatched to still!");
		assert_and_message(!disp_LSQ_1.dispatch, "LSQ_1 was not dispatched to still!");
		
		$display("Both neither ops");
		id_disp_0.instr_type = HALT;
		id_disp_1.instr_type = FORK;
		@(negedge clock);
		assert_and_message(disp_ROB_0.dispatch, "ROB_0 was not dispatched to still!");
		assert_and_message(!disp_RS_0.dispatch, "RS_0 was dispatched to still!");
		assert_and_message(!disp_LSQ_0.dispatch, "LSQ_0 was dispatched to still!");
		assert_and_message(disp_ROB_1.dispatch, "ROB_1 was not dispatched to still!");
		assert_and_message(!disp_RS_1.dispatch, "RS_1 was dispatched to still!");
		assert_and_message(!disp_LSQ_1.dispatch, "LSQ_1 was dispatched to still!");

	endtask

	initial 
	begin
		/*$monitor("time:%2.0d rst:%b instr_type_0:%2.0d instr_type_1:%2.0d ", $time, reset, disp_ROB_0.instr_type, disp_ROB_1.instr_type,
		         "thread0:%b ARN_dest:%2.0d PRN_dest:%2.0d dispatch_pc:%2.0d ", disp_ROB_0.thread_ID, disp_ROB_0.ARN_dest, disp_ROB_0.PRN_dest, disp_ROB_0.dispatch_pc,
		         "thread1:%b ARN_dest:%2.0d PRN_dest:%2.0d dispatch_pc:%2.0d\n", disp_ROB_1.thread_ID, disp_ROB_1.ARN_dest, disp_ROB_1.PRN_dest, disp_ROB_1.dispatch_pc,
		         "thread0:%b dispatch:%b op_type:%2.0d operation:%2.0d op1_ready:%b ", disp_RS_0.thread_ID, disp_RS_0.dispatch, disp_RS_0.op_type, disp_RS_0.operation, disp_RS_0.op1_ready,
		         "op1_value:%2.0d op1_PRF_index:%2.0d op2_ready:%b op2_value:%2.0d op2_PRF_index:%2.0d ", disp_RS_0.op1_value, disp_RS_0.op1_PRF_index, disp_RS_0.op2_ready, disp_RS_0.op2_value, disp_RS_0.op2_PRF_index,
		         "dest_PRF_index:%2.0d next_pc:%2.0d branch_target_addr:%2.0d\n", disp_RS_0.dest_PRF_index, disp_RS_0.next_pc, disp_RS_0.branch_target_addr,
		         "thread0:%b dispatch:%b op_type:%2.0d operation:%2.0d op1_ready:%b ", disp_RS_1.thread_ID, disp_RS_1.dispatch, disp_RS_1.op_type, disp_RS_1.operation, disp_RS_1.op1_ready,
		         "op1_value:%2.0d op1_PRF_index:%2.0d op2_ready:%b op2_value:%2.0d op2_PRF_index:%2.0d ", disp_RS_1.op1_value, disp_RS_1.op1_PRF_index, disp_RS_1.op2_ready, disp_RS_1.op2_value, disp_RS_1.op2_PRF_index,
		         "dest_PRF_index:%2.0d next_pc:%2.0d branch_target_addr:%2.0d\n", disp_RS_1.dest_PRF_index, disp_RS_1.next_pc, disp_RS_1.branch_target_addr,
		         "rd_mem:%b wr_mem:%b ldl_mem:%b stc_mem:%b dispatch:%b", disp_LSQ_0.rd_mem, disp_LSQ_0.wr_mem, disp_LSQ_0.ldl_mem, disp_LSQ_0.stc_mem, disp_LSQ_0.dispatch, 
		         "value_to_store:%2.0d value_to_store_ready:%b base_addr_ready:%b", disp_LSQ_0.value_to_store, disp_LSQ_0.value_to_store_ready, disp_LSQ_0.base_addr_ready, 
		         "base_addr:%2.0d base_addr_PRN:%2.0d offset:%2.0d PRN_dest:%2.0d\n", disp_LSQ_0.base_addr, disp_LSQ_0.base_addr_PRN, disp_LSQ_0.offset, disp_LSQ_0.PRN_dest,
		         "rd_mem:%b wr_mem:%b ldl_mem:%b stc_mem:%b dispatch:%b", disp_LSQ_1.rd_mem, disp_LSQ_1.wr_mem, disp_LSQ_1.ldl_mem, disp_LSQ_1.stc_mem, disp_LSQ_1.dispatch, 
		         "value_to_store:%2.0d value_to_store_ready:%b base_addr_ready:%b", disp_LSQ_1.value_to_store, disp_LSQ_1.value_to_store_ready, disp_LSQ_1.base_addr_ready, 
		         "base_addr:%2.0d base_addr_PRN:%2.0d offset:%2.0d PRN_dest:%2.0d\n", disp_LSQ_1.base_addr, disp_LSQ_1.base_addr_PRN, disp_LSQ_1.offset, disp_LSQ_1.PRN_dest, 
						 "stall_0:%b stall_1:%b\n", stall_0, stall_1,
		);
		  */
		clock = 0;
		reset_DISPATCH();
		@(negedge clock);

		// More thorough testing can be done

		$display("Check if both stalls are working");
		ROB_0_full = 1;
		ROB_1_full = 1;
		@(negedge clock);
		check_no_dispatches_0();
		check_no_dispatches_1();
		assert_and_message(stall_0 && stall_1, "stalls didn't work");
		reset_DISPATCH();

		RS_full = 1;
		id_disp_0.instr_type = BRANCH;
		id_disp_1.instr_type = BRANCH;
		@(negedge clock);
		check_no_dispatches_0();
		check_no_dispatches_1();
		assert_and_message(stall_0 && stall_1, "stalls didn't work");
		reset_DISPATCH();

		LSQ_full = 1;
		id_disp_0.rd_mem = 1;
		id_disp_1.rd_mem = 1;
		@(negedge clock);
		check_no_dispatches_0();
		check_no_dispatches_1();
		assert_and_message(stall_0 && stall_1, "stalls didn't work");
		reset_DISPATCH();

		$display("Check if stall_0 is working");
		id_disp_1.thread_ID = 1;
		ROB_0_full = 1;
		@(negedge clock);
		assert_and_message(!stall_1, "kkkkjjjf");
		check_no_dispatches_0();
		assert_and_message(disp_ROB_1.dispatch, "ROB_1 not dispatched to!");
		reset_DISPATCH();

		$display("Check if stall_1 is working");
		id_disp_1.thread_ID = 1;
		ROB_1_full = 1;
		@(negedge clock);
		check_no_dispatches_1();
		assert_and_message(disp_ROB_0.dispatch, "ROB_0 not dispatched to!");
		reset_DISPATCH();


		$display("Check if mispredicts are working");
		mispredict_ROB_0 = 1;
		mispredict_ROB_1 = 1;
		@(negedge clock);
		check_no_dispatches_0();
		check_no_dispatches_1();
		reset_DISPATCH();

		$display("Check if mispredict_0 is working");
		mispredict_ROB_0 = 1;
		@(negedge clock);
		check_no_dispatches_0();
		reset_DISPATCH();

		$display("Check if mispredict_0 is working multi_threaded");
		mispredict_ROB_0 = 1;
		id_disp_0.thread_ID = 0;
		id_disp_0.thread_ID = 1;
		@(negedge clock);
		check_no_dispatches_0();
		assert_and_message(disp_ROB_1.dispatch, "ROB_0 not dispatched to!");
		reset_DISPATCH();

		$display("Check if mispredict_1 is working");
		mispredict_ROB_1 = 1;
		id_disp_1.thread_ID = 1;
		@(negedge clock);
		check_no_dispatches_1();
		assert_and_message(disp_ROB_0.dispatch, "ROB_0 not dispatched to!");
		reset_DISPATCH();

		$display("Check if RS_0 values are correctly passed");
		check_things_passed_0();
		reset_DISPATCH();

		// Maybe should connect to ID/RAT in order to properly test?
		// I'm literally making sure it passes through the things that I
		// have it pass through. Checking .dispatch stuff would be more
		// useful

		$display("@@@PASSED!");
		$finish;
	end // initial
endmodule