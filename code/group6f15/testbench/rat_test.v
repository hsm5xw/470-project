`timescale 1ns/100ps

module testbench();
	logic clock;
	logic reset;
	logic mispredict_thread_0;
	logic mispredict_thread_1;
	logic [1:0] [`PR_BITS-1:0] free_PRN; 
	ID_RAT [1:0] inst_in;
	RAT_ARR [1:0] RRAT_arr;

	RAT_PRF [1:0] inst_out;

	rat RAT_0 (
		.clock(clock),
		.reset(reset),
		.mispredict_thread_0(mispredict_thread_0),
		.mispredict_thread_1(mispredict_thread_1),
		.free_PRN(free_PRN),
		.inst_in(inst_in),
		.RRAT_arr(RRAT_arr),
		.inst_out(inst_out)
	);

	// temp registers for testing
	logic [`PR_BITS-1:0] temp_PRN;

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

	// task print_RAT;
	// 	input thread_id;
	// 	begin
	// 		for(int i=0; i < `AR_SIZE; i++) begin
	// 			$display("RAT[%2.0d]: %2.0d", i, RAT_arr[thread_id][i]);
	// 		end
	// 	end
	// endtask

	task reset_inputs;
		begin
			reset = 1;
			mispredict_thread_0 = 0;
			mispredict_thread_1 = 0;
			free_PRN[0] = 9;
			free_PRN[1] = 10;

			inst_in[0].thread_id = 0;
			inst_in[0].ARN_opa = 3;
			inst_in[0].ARN_opb = 4;
			inst_in[0].ARN_dest = `ZERO_REG;

			inst_in[1].thread_id = 0;
			inst_in[1].ARN_opa = 5;
			inst_in[1].ARN_opb = 6;
			inst_in[1].ARN_dest = `ZERO_REG;
			@(negedge clock);
			reset = 0;
			@(negedge clock);
		end
	endtask

	task write_to_reg;
		input [`AR_BITS-1:0] start_ARN;
		input [`PR_BITS-1:0] start_PRN;
		input [`AR_SIZE:0] num_inst;
		begin
			@(negedge clock);
			free_PRN[0] = start_PRN;
			inst_in[0].ARN_dest = start_ARN;
			for(int i=1; i < num_inst; i++) begin
				@(negedge clock);
				if(i!=1) begin
					temp_PRN = (inst_in[0].ARN_opa!=`ZERO_REG) ? free_PRN[0]-1 : `PR_SIZE-1;
					assert_and_message(inst_out[0].PRN_opa==temp_PRN && inst_out[1].PRN_opb==temp_PRN, "PRN opa and opb should be updated");
				end
				inst_in[0].ARN_opa = inst_in[0].ARN_dest;
				inst_in[1].ARN_opb = inst_in[0].ARN_dest;
				inst_in[0].ARN_dest++;
				free_PRN[0]++;
			end
			@(negedge clock);
			inst_in[1].ARN_dest = `ZERO_REG;
			inst_in[0].ARN_dest = `ZERO_REG;
		end
	endtask

	task check_mispredict_signal;
		begin
		end
	endtask

	initial 
	begin
		clock = 0;
		$monitor("time:%2.0d rst:%b misp0:%b misp1:%b freePRN0:%2.0d freePRN1:%2.0d ", $time, reset, mispredict_thread_0, mispredict_thread_1, free_PRN[0], free_PRN[1],
		         "thread0:%b opa:%2.0d opb:%2.0d dest:%2.0d ", inst_in[0].thread_id, inst_in[0].ARN_opa, inst_in[0].ARN_opb, inst_in[0].ARN_dest,
		         "thread1:%b opa:%2.0d opb:%2.0d dest:%2.0d\n", inst_in[1].thread_id, inst_in[1].ARN_opa, inst_in[1].ARN_opb, inst_in[1].ARN_dest,
		         "thread0:%b opa:%2.0d opb:%2.0d write:%b dest:%2.0d ", inst_out[0].thread_id, inst_out[0].PRN_opa, inst_out[0].PRN_opb, inst_out[0].write, inst_out[0].PRN_dest,
		         "thread1:%b opa:%2.0d opb:%2.0d write:%b dest:%2.0d\n", inst_out[1].thread_id, inst_out[1].PRN_opa, inst_out[1].PRN_opb, inst_out[1].write, inst_out[1].PRN_dest
		);
		reset_inputs();
		assert_and_message(!inst_out[0].thread_id && inst_out[0].PRN_opa==`PR_SIZE-1 && inst_out[0].PRN_opb==`PR_SIZE-1 && !inst_out[0].write 
		                   && inst_out[0].PRN_dest==`PR_SIZE-1, "test reset");
		assert_and_message(!inst_out[1].thread_id && inst_out[1].PRN_opa==`PR_SIZE-1 && inst_out[1].PRN_opb==`PR_SIZE-1 && !inst_out[1].write 
		                   && inst_out[1].PRN_dest==`PR_SIZE-1, "test reset");
		
		@(negedge clock);
		inst_in[1].ARN_dest = 4;
		inst_in[0].ARN_dest = 4;
		#1
		
		$display("write to same ARN");
		assert_and_message(inst_out[1].write && inst_out[0].write && inst_out[0].PRN_dest==free_PRN[0] && inst_out[1].PRN_dest==free_PRN[1], "");
		@(negedge clock);
		inst_in[0].ARN_opa = inst_in[1].ARN_dest;
		inst_in[0].ARN_opb = inst_in[1].ARN_dest;
		inst_in[1].ARN_opa = inst_in[1].ARN_dest;
		inst_in[1].ARN_opb = inst_in[1].ARN_dest;
		inst_in[1].ARN_dest = `ZERO_REG;
		inst_in[0].ARN_dest = `ZERO_REG;
		#1
		
		$display("PRN opa and opb should be updated to free_PRN[1]");
		assert_and_message(inst_out[1].PRN_opa==free_PRN[1] && inst_out[1].PRN_opb==free_PRN[1] && inst_out[0].PRN_opa==free_PRN[1] && inst_out[0].PRN_opb==free_PRN[1], "");
		reset_inputs();

		inst_in[0].thread_id = 1;
		inst_in[1].ARN_dest  = 4;
		inst_in[0].ARN_dest  = 4;
		#1

		$display("write to same ARN, diff threads");
		assert_and_message(inst_out[1].write && inst_out[0].write && inst_out[0].PRN_dest==free_PRN[0] && inst_out[1].PRN_dest==free_PRN[1], "");
		@(negedge clock);
		inst_in[0].ARN_opa = inst_in[1].ARN_dest;
		inst_in[0].ARN_opb = inst_in[1].ARN_dest;
		inst_in[1].ARN_opa = inst_in[1].ARN_dest;
		inst_in[1].ARN_opb = inst_in[1].ARN_dest;
		inst_in[1].ARN_dest = `ZERO_REG;
		inst_in[0].ARN_dest = `ZERO_REG;
		#1
		
		$display("PRN opa and opb should be updated to free_PRN[1]");
		assert_and_message(inst_out[1].PRN_opa==free_PRN[1] && inst_out[1].PRN_opb==free_PRN[1] && inst_out[0].PRN_opa==free_PRN[0] && inst_out[0].PRN_opb==free_PRN[0], "");
		reset_inputs();

		$display("write to ARN0");
		inst_in[1].ARN_dest = `ZERO_REG;
		inst_in[0].ARN_dest = 4;
		#1
		assert_and_message(!inst_out[1].write && inst_out[0].write, "");
		reset_inputs();

		$display("fill RAT");
		write_to_reg(0, 0, `PR_SIZE-1);

		$display("access other thread's RAT");
		inst_in[0].ARN_opb = 30;
		inst_in[1].ARN_opa = 30;
		inst_in[1].thread_id = 1;
		#1
		assert_and_message(inst_out[0].PRN_opb==inst_in[0].ARN_opb && inst_out[1].PRN_opa==`PR_SIZE-1, "");

		$display("@@@PASSED!");
		$finish;
	end // initial
endmodule
