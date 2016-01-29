`timescale 1ns/100ps

module testbench();
	logic                         clock;               // system clock
	logic                         reset;               // system reset
	logic                         mispredict_thread_0; // high if a mispredicted branch from thread 0 is committed
	logic                         mispredict_thread_1; // high if a mispredicted branch from thread 1 is committed
	IF_ID [1:0]                   inst_in;
	//THESE ARE USED BY THE RAT
	logic [1:0] [`PR_BITS-1:0]    free_PRN;            // PRN to rename inst, from the PRF module
	RAT_ARR [1:0]                 RRAT_arr;            // used to recover RAT in case of branch mispredict

	ID_DISPATCH [1:0]             inst_dispatch;       // goes to the dispatch module
	RAT_PRF [1:0]                 inst_PRF;            // goes to the PRF module

	id_stage id_0 (
		.clock              (clock),
		.reset              (reset),
		.mispredict_thread_0(mispredict_thread_0),
		.mispredict_thread_1(mispredict_thread_1),
		.inst_in            (inst_in),
		.free_PRN           (free_PRN),
		.RRAT_arr           (RRAT_arr),
		.inst_dispatch      (inst_dispatch),
		.inst_PRF           (inst_PRF)
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

	initial 
	begin		
		$display("@@@PASSED!");
		$finish;		
	end

endmodule

