`timescale 1ns/100ps

module testbench();
	logic clock;
	logic reset;
	logic mispredict_thread_0;
	logic mispredict_thread_1;
	logic [3:0] [`PR_BITS-1:0] free_PRN_in;
	logic [1:0] [`PR_SIZE-1:0] RRAT_free_list;
	RAT_PRF [1:0] inst_in;
	CDB CDB_0;
	CDB CDB_1;
	logic [1:0] [`PR_BITS-1:0] free_PRN_out;
	PRF_DISPATCH [1:0] inst_out;

	prf PRF_0 (
		.clock(clock),
		.reset(reset),
		.mispredict_thread_0(mispredict_thread_0),
		.mispredict_thread_1(mispredict_thread_1),
		.free_PRN_in(free_PRN_in),
		.RRAT_free_list(RRAT_free_list),
		.inst_in(inst_in),
		.CDB_0(CDB_0),
		.CDB_1(CDB_1),
		.free_PRN_out(free_PRN_out),
		.inst_out(inst_out)
	);

	always begin
		#5;
		clock = ~clock;
	end

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

	// task print_PRF;
	// 	input [`PR_BITS:0] num_entries;
	// 	begin
	// 		for(int i=0; i < num_entries; i++) begin
	// 			$display("%2.0d: thread_id:%b val:%2.0d valid:%b", 
	// 			i, PRF_arr[i].thread_id, PRF_arr[i].value, PRF_arr[i].valid);
	// 		end
	// 	end
	// endtask

	task reset_inputs;
		begin
			@(negedge clock);
			reset = 1;
			RRAT_free_list[0] = 0;
			RRAT_free_list[1] = 0;
			mispredict_thread_0 = 0;
			mispredict_thread_1 = 0;
			
			CDB_0.PRN = 0;
			CDB_0.valid = 0;
			CDB_0.FU_result = 55;

			CDB_1.PRN = 0;
			CDB_1.valid = 0;
			CDB_1.FU_result = 66;

			free_PRN_in[0] = `PR_SIZE-1;
			free_PRN_in[1] = `PR_SIZE-1;
			free_PRN_in[2] = `PR_SIZE-1;
			free_PRN_in[3] = `PR_SIZE-1;
			
			inst_in[0].thread_id = 0;
			inst_in[0].PRN_opa = `PR_SIZE-1;
			inst_in[0].PRN_opb = `PR_SIZE-1;
			inst_in[0].write = 0;
			inst_in[0].PRN_dest = 0;

			inst_in[1].thread_id = 1;
			inst_in[1].PRN_opa = `PR_SIZE-1;
			inst_in[1].PRN_opb = `PR_SIZE-1;
			inst_in[1].write = 0;
			inst_in[1].PRN_dest = 0;
			@(negedge clock);
			reset = 0;
			@(negedge clock);
		end
	endtask

	initial 
	begin
		clock = 0;
		$display("test reset");
		reset_inputs();
		assert_and_message(inst_out[0].ready_opa && !inst_out[0].value_opa && inst_out[0].ready_opb && !inst_out[0].value_opb, "");
		assert_and_message(inst_out[1].ready_opa && !inst_out[1].value_opa && inst_out[1].ready_opb && !inst_out[1].value_opb, "");
		assert_and_message(free_PRN_out[0]==46 && free_PRN_out[1]==0, "");
		
		$display("test write to register");
		inst_in[0].write = 1;
		inst_in[0].PRN_dest = 0;
		inst_in[1].write = 1;
		inst_in[1].PRN_dest = 1;
		#1
		$display("%2.0d %2.0d", free_PRN_out[0], free_PRN_out[1]);
		assert_and_message(free_PRN_out[0]==46 && free_PRN_out[1]==2, "");
		@(negedge clock);

		$display("test finished executing instructions and writing to register in the same cycle");
		CDB_0.PRN = 1;
		CDB_0.valid = 1;
		CDB_1.PRN = 0;
		CDB_1.valid = 1;
		inst_in[0].PRN_dest = 46;
		inst_in[1].PRN_dest = 2;
		#1
		$display("%2.0d %2.0d", free_PRN_out[0], free_PRN_out[1]);
		assert_and_message(free_PRN_out[0]==45 && free_PRN_out[1]==3, "");
		@(negedge clock);
		CDB_0.valid = 0;
		CDB_1.valid = 0;
		inst_in[0].write = 0;
		inst_in[1].write = 0;

		$display("test get value of ready and non-ready PRN");
		inst_in[1].PRN_opa = 0;
		inst_in[1].PRN_opb = 2;
		inst_in[0].PRN_opa = 1;
		inst_in[0].PRN_opb = 46;
		#1
		assert_and_message(inst_out[0].ready_opa && inst_out[0].value_opa==55 && !inst_out[0].ready_opb && inst_out[0].value_opb==46, "");
		assert_and_message(inst_out[1].ready_opa && inst_out[1].value_opa==66 && !inst_out[1].ready_opb && inst_out[1].value_opb==2, "");
		@(negedge clock);

		$display("CDB broadcast and read at the same PRN");
		inst_in[0].write = 1;
		inst_in[1].write = 0;
		inst_in[0].PRN_dest = 45;
		CDB_0.PRN = 46;
		CDB_0.valid = 1;
		CDB_1.PRN = 2;
		CDB_1.valid = 1;
		#1
		$display("%2.0d %2.0d", free_PRN_out[0], free_PRN_out[1]);
		assert_and_message(free_PRN_out[0]==44 && free_PRN_out[1]==3, "");
		assert_and_message(inst_out[0].ready_opa && inst_out[0].value_opa==55 && inst_out[0].ready_opb && inst_out[0].value_opb==55, "");
		assert_and_message(inst_out[1].ready_opa && inst_out[1].value_opa==66 && inst_out[1].ready_opb && inst_out[1].value_opb==66, "");

		$display("write to PRN 0");
		reset_inputs();
		inst_in[0].write = 1;
		inst_in[0].PRN_dest = 46;
		inst_in[1].write = 1;
		inst_in[1].PRN_dest = 0;
		#1
		assert_and_message(free_PRN_out[0]==45 && free_PRN_out[1]==1, "");


		$display("@@@PASSED!");
		$finish;
	end // initial
endmodule
