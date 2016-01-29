`timescale 1ns/100ps

module CDB_arbiter
	(
	 input clock,
	 input reset,

	 input logic mispredict_0,
	 input logic mispredict_1,

	 input FU_RESULT LSQ_in_0,
	 input FU_RESULT LSQ_in_1,
	 input FU_RESULT ALU_in_0,
	 input FU_RESULT ALU_in_1,
	 input FU_RESULT mult_in,
	 input BRANCH_RESULT branch_in,
	 input logic branch_in_done,

	 //output LSQ_0_sent,
	 //output LSQ_1_sent,
	 output logic ALU_0_sent,
	 output logic ALU_1_sent,
	 output logic mult_sent,
	 output logic branch_sent,

	 output CDB cdb_0,
	 output CDB cdb_1
	);

	logic second_selected;
	logic first_selected;

	always_comb begin
		if(reset) begin
			cdb_0 = 0;
			cdb_1 = 0;

			cdb_0.PRN = `ZERO_REG;
			cdb_1.PRN = `ZERO_REG;

			ALU_0_sent = 0;
		 	ALU_1_sent = 0;
		 	mult_sent  = 0;
		 	branch_sent = 0;
		end
		else begin
			first_selected = 0;
			second_selected = 0;

			//LSQ_0_sent = 0;
		 	//LSQ_1_sent = 0;
		 	ALU_0_sent = 0;
		 	ALU_1_sent = 0;
		 	mult_sent  = 0;
		 	branch_sent = 0;

		 	cdb_0 = 0;
		 	cdb_1 = 0;

			if(LSQ_in_0.FU_done && !(mispredict_0 && (LSQ_in_0.thread_ID == 0)) 
													&& !(mispredict_1 && (LSQ_in_0.thread_ID == 1))) begin
				//LSQ_0_sent = 1;
				first_selected = 1;

				cdb_0.valid = 1;
				cdb_0.PRN   = LSQ_in_0.PRN_index;
				cdb_0.ROB_index = LSQ_in_0.ROB_index;
				cdb_0.thread_ID = LSQ_in_0.thread_ID;
				cdb_0.FU_result = LSQ_in_0.result;
				cdb_0.branch_actually_taken = 0;
			end
			if(LSQ_in_1.FU_done && !(mispredict_0 && (LSQ_in_1.thread_ID == 0)) 
												  && !(mispredict_1 && (LSQ_in_1.thread_ID == 1))) begin
				if(!first_selected) begin
					//LSQ_1_sent = 1;
					first_selected = 1;

					cdb_0.valid = 1;
					cdb_0.PRN   = LSQ_in_1.PRN_index;
					cdb_0.ROB_index = LSQ_in_1.ROB_index;
					cdb_0.thread_ID = LSQ_in_1.thread_ID;
					cdb_0.FU_result = LSQ_in_1.result;
					cdb_0.branch_actually_taken = 0;
				end
				else begin
					//LSQ_1_sent = 1;
					second_selected = 1;

					cdb_1.valid = 1;
					cdb_1.PRN   = LSQ_in_1.PRN_index;
					cdb_1.ROB_index = LSQ_in_1.ROB_index;
					cdb_1.thread_ID = LSQ_in_1.thread_ID;
					cdb_1.FU_result = LSQ_in_1.result;
					cdb_1.branch_actually_taken = 0;
				end 
			end
			if(!second_selected && mult_in.FU_done && !(mispredict_0 && (mult_in.thread_ID == 0)) 
													                   && !(mispredict_1 && (mult_in.thread_ID == 1))) begin
				if(!first_selected) begin
					mult_sent = 1;
					first_selected = 1;

					cdb_0.valid = 1;
					cdb_0.PRN   = mult_in.PRN_index;
					cdb_0.ROB_index = mult_in.ROB_index;
					cdb_0.thread_ID = mult_in.thread_ID;
					cdb_0.FU_result = mult_in.result;
					cdb_0.branch_actually_taken = 0;
				end
				else begin
					mult_sent = 1;
					second_selected = 1;

					cdb_1.valid = 1;
					cdb_1.PRN   = mult_in.PRN_index;
					cdb_1.ROB_index = mult_in.ROB_index;
					cdb_1.thread_ID = mult_in.thread_ID;
					cdb_1.FU_result = mult_in.result;
					cdb_1.branch_actually_taken = 0;
				end 
			end
			if(!second_selected && branch_in_done && !(mispredict_0 && (branch_in.thread_ID == 0)) 
													                  && !(mispredict_1 && (branch_in.thread_ID == 1))) begin
				if(!first_selected) begin
					branch_sent = 1;
					first_selected = 1;
					
					cdb_0.valid = 1;
					cdb_0.PRN   = branch_in.PRN_index;
					cdb_0.thread_ID = branch_in.thread_ID;
					cdb_0.ROB_index = branch_in.ROB_index;
					cdb_0.FU_result = branch_in.result;
					cdb_0.mispredict = branch_in.mispredict;
					cdb_0.branch_actually_taken = branch_in.branch_actually_taken;

					if(branch_in.thread_ID == 0 && mispredict_0) begin
						cdb_0.valid = 0;
					end
				end
				else begin
					branch_sent = 1;
					second_selected = 1;
					
					cdb_1.valid = 1;
					cdb_1.PRN   = branch_in.PRN_index;
					cdb_1.thread_ID = branch_in.thread_ID;
					cdb_1.ROB_index = branch_in.ROB_index;
					cdb_1.FU_result = branch_in.result;
					cdb_1.mispredict = branch_in.mispredict;
					cdb_1.branch_actually_taken = branch_in.branch_actually_taken;
					
					if(branch_in.thread_ID == 0 && mispredict_0) begin
						cdb_1.valid = 0;
					end
				end 
			end
			if(!second_selected && ALU_in_0.FU_done && !(mispredict_0 && (ALU_in_0.thread_ID == 0)) 
													                    && !(mispredict_1 && (ALU_in_0.thread_ID == 1))) begin
				if(!first_selected) begin
					ALU_0_sent = 1;
					first_selected = 1;

					cdb_0.valid = 1;
					cdb_0.PRN   = ALU_in_0.PRN_index;
					cdb_0.ROB_index = ALU_in_0.ROB_index;
					cdb_0.thread_ID = ALU_in_0.thread_ID;
					cdb_0.FU_result = ALU_in_0.result;
					cdb_0.branch_actually_taken = 0;
				end
				else begin
					ALU_0_sent = 1;
					second_selected = 1;

					cdb_1.valid = 1;
					cdb_1.PRN   = ALU_in_0.PRN_index;
					cdb_1.ROB_index = ALU_in_0.ROB_index;
					cdb_1.thread_ID = ALU_in_0.thread_ID;
					cdb_1.FU_result = ALU_in_0.result;
					cdb_1.branch_actually_taken = 0;
				end 
			end
			if(!second_selected && ALU_in_1.FU_done && !(mispredict_0 && (ALU_in_1.thread_ID == 0)) 
													                    && !(mispredict_1 && (ALU_in_1.thread_ID == 1)))  begin
				if(!first_selected) begin
					ALU_1_sent = 1;
					first_selected = 1;

					cdb_0.valid = 1;
					cdb_0.PRN   = ALU_in_1.PRN_index;
					cdb_0.ROB_index = ALU_in_1.ROB_index;
					cdb_0.thread_ID = ALU_in_1.thread_ID;
					cdb_0.FU_result = ALU_in_1.result;
					cdb_0.branch_actually_taken = 0;
				end
				else begin
					ALU_1_sent = 1;
					second_selected = 1;

					cdb_1.valid = 1;
					cdb_1.PRN   = ALU_in_1.PRN_index;
					cdb_1.ROB_index = ALU_in_1.ROB_index;
					cdb_1.thread_ID = ALU_in_1.thread_ID;
					cdb_1.FU_result = ALU_in_1.result;
					cdb_1.branch_actually_taken = 0;
				end 
			end
		end // else for if(reset)
	end

endmodule