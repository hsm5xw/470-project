`timescale 1ns/100ps

module prf (
	input clock,
	input reset,
	input mispredict_thread_0,
	input mispredict_thread_1,
	input [3:0] [`PR_BITS-1:0] free_PRN_in, // from RRAT. PRN_dest of recently committed insts
	input [1:0] [`PR_SIZE-1:0] RRAT_free_list, // from RRAT.
	input RAT_PRF [1:0] inst_in,
	input CDB CDB_0,
	input CDB CDB_1,
	input               stall_0,
	input               stall_1,

	output PRF_DATA [`PR_SIZE-1:0] n_PRF_arr,
	output logic [`PR_SIZE-1:0] n_PRF_free_list, 
	output [1:0] [`PR_BITS-1:0] free_PRN_out,
	output PRF_DISPATCH [1:0] inst_out
);
	logic flush_inst_0, flush_inst_1, allocate_inst_0, allocate_inst_1, empty;
	logic [`PR_SIZE-1:0] gnt, PRF_free_list;
	logic [1:0][`PR_SIZE-1:0] gnt_bus;
	PRF_DATA [`PR_SIZE-1:0] PRF_arr;

	// don't handle the case when all PRNs are taken
	psel_gen #(.REQS(2), .WIDTH(`PR_SIZE)) psel_gen_0 (
		.req(n_PRF_free_list),
		.gnt(gnt),
		.gnt_bus(gnt_bus), 
		.empty(empty)
	);

	pe #(.OUT_WIDTH(`PR_BITS), .IN_WIDTH(`PR_SIZE)) pe_0 [1:0] (
		.gnt(gnt_bus),
		.enc(free_PRN_out)
	);

	always_comb begin
		flush_inst_0    = inst_in[0].thread_id ? mispredict_thread_1 : mispredict_thread_0;
		flush_inst_1    = inst_in[1].thread_id ? mispredict_thread_1 : mispredict_thread_0;
	
		allocate_inst_0 = !flush_inst_0 && inst_in[0].write && !stall_0;
		allocate_inst_1 = !flush_inst_1 && inst_in[1].write && !stall_1;

		n_PRF_arr = PRF_arr;
		n_PRF_free_list = PRF_free_list;
		for(int i=0; i < `PR_SIZE-1; i++) begin
			if((mispredict_thread_0 && RRAT_free_list[0][i] && !PRF_arr[i].thread_id) ||
			   (mispredict_thread_1 && RRAT_free_list[1][i] && PRF_arr[i].thread_id) ||
			   (free_PRN_in[0]==i) || (free_PRN_in[1]==i) || (free_PRN_in[2]==i) || (free_PRN_in[3]==i))
			begin
				n_PRF_free_list[i] = 1;
				n_PRF_arr[i].valid = 0;
			end
			else begin
				if(CDB_0.valid && CDB_0.PRN==i) begin
					n_PRF_arr[i].value = CDB_0.FU_result;
					n_PRF_arr[i].valid = 1;
				end
				if(CDB_1.valid && CDB_1.PRN==i) begin
					n_PRF_arr[i].value = CDB_1.FU_result;
					n_PRF_arr[i].valid = 1;
				end
			end
			if(inst_in[0].PRN_dest==i && allocate_inst_0) begin
				n_PRF_free_list[i]     = 0;
				n_PRF_arr[i].thread_id = inst_in[0].thread_id;
				n_PRF_arr[i].valid     = inst_in[0].uncond_branch;
				n_PRF_arr[i].value     = inst_in[0].next_pc;
			end
			if(inst_in[1].PRN_dest==i && allocate_inst_1) begin
				n_PRF_free_list[i]     = 0;
				n_PRF_arr[i].thread_id = inst_in[1].thread_id;
				n_PRF_arr[i].valid     = inst_in[1].uncond_branch;
				n_PRF_arr[i].value     = inst_in[1].next_pc;
			end
		end

		for(int i=0; i < 2; i++) begin
			inst_out[i].ready_opa = n_PRF_arr[inst_in[i].PRN_opa].valid;
			inst_out[i].ready_opb = n_PRF_arr[inst_in[i].PRN_opb].valid;
			inst_out[i].value_opa = inst_out[i].ready_opa ? n_PRF_arr[inst_in[i].PRN_opa].value : 
			                        inst_in[i].PRN_opa;
			inst_out[i].value_opb = inst_out[i].ready_opb ? n_PRF_arr[inst_in[i].PRN_opb].value :  
			                        inst_in[i].PRN_opb;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0; i < `PR_SIZE-1; i++) begin
				PRF_free_list[i]     <= #1 1;
				PRF_arr[i].thread_id <= #1 0;
				PRF_arr[i].value     <= #1 0;
				PRF_arr[i].valid     <= #1 0;
			end
			PRF_free_list[`PR_SIZE-1]     <= #1 0;
			PRF_arr[`PR_SIZE-1].thread_id <= #1 0;
			PRF_arr[`PR_SIZE-1].value     <= #1 0;
			PRF_arr[`PR_SIZE-1].valid     <= #1 1;
		end else begin
			for(int i=0; i < `PR_SIZE-1; i++) begin
				PRF_arr[i].thread_id <= #1 n_PRF_arr[i].thread_id;
				PRF_arr[i].value     <= #1 n_PRF_arr[i].value;
				PRF_arr[i].valid     <= #1 n_PRF_arr[i].valid;
				PRF_free_list[i]     <= #1 n_PRF_free_list[i];
			end
		end
	end
endmodule
