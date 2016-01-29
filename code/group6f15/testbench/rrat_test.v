`timescale 1ns/100ps

module testbench();
	logic clock;
	logic reset;
	ROB_RRAT [1:0] [1:0] inst_in;
	RAT_ARR [1:0] n_RRAT_arr;
	logic [3:0] [`PR_BITS-1:0] free_PRN_out;
	logic [1:0] [`PR_SIZE-1:0] n_RRAT_free_list;

	rrat RRAT_0 (
		.clock(clock),
		.reset(reset),
		.inst_in(inst_in),
		.n_RRAT_arr(n_RRAT_arr),
		.free_PRN_out(free_PRN_out),
		.n_RRAT_free_list(n_RRAT_free_list)
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
				print_state(`PR_SIZE, `AR_SIZE);
				$display("%s \n@@@Failed", message);
				$finish;
			end
		end
	endtask

	task assert_free_PRN;
		input [`PR_BITS-1:0] PRN0, PRN1, PRN2, PRN3;
		begin
			assert_and_message(free_PRN_out[0]==PRN0 && free_PRN_out[1]==PRN1, "from assert_free_PRN");
			assert_and_message(free_PRN_out[2]==PRN2 && free_PRN_out[3]==PRN3, "from assert_free_PRN`");
		end
	endtask

	task print_RRAT;
		input [`AR_BITS:0] num_entries;
		begin
			for(int i=0; i < num_entries; i++) begin
				$display("%2.0d: %2.0d %2.0d", 
				i, n_RRAT_arr[0][i], n_RRAT_arr[1][i]);
			end
		end
	endtask

	task print_free_list;
		input [`PR_BITS:0] num_entries;
		begin
			for(int i=0; i < num_entries; i++) begin
				$display("%2.0d: %2.0d %2.0d", 
				i, n_RRAT_free_list[0][i], n_RRAT_free_list[1][i]);
			end
		end
	endtask

	task print_state;
		input [`PR_BITS:0] num_PR;
		input [`AR_BITS:0] num_AR;
		begin
			print_free_list(num_PR);
			print_RRAT(num_AR);
			$display("free_PRN0:%2.0d free_PRN1:%2.0d free_PRN2:%2.0d free_PRN3:%2.0d", 
			free_PRN_out[0], free_PRN_out[1], free_PRN_out[2], free_PRN_out[3]);
		end
	endtask

	task set_committed_bit;
		input a, b, c, d;
		begin
			inst_in[0][0].committed = a;
			inst_in[0][1].committed = b;
			inst_in[1][0].committed = c;
			inst_in[1][1].committed = d;
			#1
			if(a && inst_in[0][0].PRN_dest!=`PR_SIZE-1) begin
				assert_and_message(!n_RRAT_free_list[0][inst_in[0][0].PRN_dest], "");
				assert_and_message(n_RRAT_arr[0][inst_in[0][0].ARN_dest] == inst_in[0][0].PRN_dest, "");
			end
			if(b && inst_in[0][1].PRN_dest!=`PR_SIZE-1) begin
				assert_and_message(!n_RRAT_free_list[0][inst_in[0][1].PRN_dest], "");
				assert_and_message(n_RRAT_arr[0][inst_in[0][1].ARN_dest] == inst_in[0][1].PRN_dest, "");
			end
			if(c && inst_in[1][0].PRN_dest!=`PR_SIZE-1) begin
				assert_and_message(!n_RRAT_free_list[1][inst_in[1][0].PRN_dest], "");
				assert_and_message(n_RRAT_arr[1][inst_in[1][0].ARN_dest] == inst_in[1][0].PRN_dest, "");
			end
			if(d && inst_in[1][1].PRN_dest!=`PR_SIZE-1) begin
				assert_and_message(!n_RRAT_free_list[1][inst_in[1][1].PRN_dest], "");
				assert_and_message(n_RRAT_arr[1][inst_in[1][1].ARN_dest] == inst_in[1][1].PRN_dest, "");
			end
		end
	endtask

	task set_ARN_dest;
		input [`AR_BITS-1:0] a, b, c, d;
		begin
			inst_in[0][0].ARN_dest  = a;
			inst_in[0][1].ARN_dest  = b;
			inst_in[1][0].ARN_dest  = c;
			inst_in[1][1].ARN_dest  = d;
		end
	endtask

	task set_PRN_dest;
		input [`PR_BITS-1:0] a, b, c, d;
		begin
			inst_in[0][0].PRN_dest  = a;
			inst_in[0][1].PRN_dest  = b;
			inst_in[1][0].PRN_dest  = c;
			inst_in[1][1].PRN_dest  = d;
		end
	endtask

	task reset_inputs;
		begin
			@(negedge clock);
			reset = 1;
			inst_in[0][0].committed = 0;
			inst_in[0][0].ARN_dest  = 0;
			inst_in[0][0].PRN_dest  = 10;
			inst_in[0][1].committed = 0;
			inst_in[0][1].ARN_dest  = 1;
			inst_in[0][1].PRN_dest  = 11;
			inst_in[1][0].committed = 0;
			inst_in[1][0].ARN_dest  = 2;
			inst_in[1][0].PRN_dest  = 12;
			inst_in[1][1].committed = 0;
			inst_in[1][1].ARN_dest  = 3;
			inst_in[1][1].PRN_dest  = 13;
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
		@(negedge clock);
		assert_and_message(n_RRAT_free_list[0][0] && n_RRAT_free_list[1][`PR_SIZE-1], "");
		assert_and_message(n_RRAT_arr[0][0]==`PR_SIZE-1 && n_RRAT_arr[1][`AR_SIZE-1]==`PR_SIZE-1, "");
		assert_and_message(free_PRN_out[0]==`PR_SIZE-1 && free_PRN_out[1]==`PR_SIZE-1, "");
		assert_and_message(free_PRN_out[2]==`PR_SIZE-1 && free_PRN_out[3]==`PR_SIZE-1, "");
		
		$display("commit 4, different ARN_dest");
		set_committed_bit(1, 1, 1, 1);
		assert(n_RRAT_free_list[0][`PR_SIZE-1] && n_RRAT_free_list[1][`PR_SIZE-1]);
		assert_free_PRN(`PR_SIZE-1, `PR_SIZE-1, `PR_SIZE-1, `PR_SIZE-1);
		@(negedge clock);

		$display("commit 2, overwrite ARN_dest");
		set_PRN_dest(14, 15, 16, 17);
		set_committed_bit(1, 0, 0, 1);
		assert(n_RRAT_free_list[0][10] && n_RRAT_free_list[1][13]);
		assert(!n_RRAT_free_list[0][11] && !n_RRAT_free_list[1][12]);
		assert_free_PRN(10, `PR_SIZE-1, `PR_SIZE-1, 13);
		@(negedge clock);
		
		$display("commit 0");
		set_committed_bit(0, 0, 0, 0);
		assert_free_PRN(`PR_SIZE-1, `PR_SIZE-1, `PR_SIZE-1, `PR_SIZE-1);
		@(negedge clock);

		$display("commit, overwrite ZERO_REG");
		set_ARN_dest(6, 0, 8, 9);
		set_PRN_dest(`PR_SIZE-1, 2, 3, 4);
		set_committed_bit(1, 1, 0, 0);
		assert_free_PRN(`PR_SIZE-1, 14, `PR_SIZE-1, `PR_SIZE-1);
		// print_state(`PR_SIZE, `AR_SIZE);
		@(negedge clock);

		$display("@@@PASSED!");
		$finish;
	end
endmodule
