`timescale 1ns/100ps

module rrat (
	input clock,
	input reset,
	input ROB_RRAT [1:0] [1:0] inst_in,
	
	output RAT_ARR [1:0] n_RRAT_arr,
	output logic [3:0] [`PR_BITS-1:0] free_PRN_out,
	output logic [1:0] [`PR_SIZE-1:0] n_RRAT_free_list
);
	logic [1:0] [`PR_SIZE-1:0] RRAT_free_list;
	RAT_ARR [1:0] RRAT_arr; // 2 RATs, one for each thread

	always_comb begin
		for(int i=0, k=0; i < 2; i++) begin
			n_RRAT_arr[i] = RRAT_arr[i];
			n_RRAT_free_list[i] = RRAT_free_list[i];
			for(int j=0; j < 2; j++, k++) begin
				free_PRN_out[k] = `PR_SIZE-1;
				if(inst_in[i][j].committed && inst_in[i][j].PRN_dest!=`PR_SIZE-1) begin
					free_PRN_out[k] = n_RRAT_arr[i][inst_in[i][j].ARN_dest];
					n_RRAT_free_list[i][free_PRN_out[k]] = 1;
					n_RRAT_free_list[i][inst_in[i][j].PRN_dest] = 0;
					n_RRAT_arr[i][inst_in[i][j].ARN_dest] = inst_in[i][j].PRN_dest;
				end
			end
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0; i < `AR_SIZE; i++) begin
				RRAT_arr[0][i] <= #1 `PR_SIZE-1;
				RRAT_arr[1][i] <= #1 `PR_SIZE-1;
			end
			for(int i=0; i < `PR_SIZE; i++) begin
				RRAT_free_list[0][i] <= #1 1;
				RRAT_free_list[1][i] <= #1 1;
			end
		end else begin
			for(int i=0; i < `AR_SIZE; i++) begin
				RRAT_arr[0][i] <= #1 n_RRAT_arr[0][i];
				RRAT_arr[1][i] <= #1 n_RRAT_arr[1][i];
			end
			for(int i=0; i < `PR_SIZE; i++) begin
				RRAT_free_list[0][i] <= #1 n_RRAT_free_list[0][i];
				RRAT_free_list[1][i] <= #1 n_RRAT_free_list[1][i];
			end
		end
	end
endmodule
