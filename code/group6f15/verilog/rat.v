// module to rename ARN to PRN
// inst_in[0] will be renamed to inst_out[0], same thing for inst_in[1]
// inst_in[0] is earlier in program order than inst_in[1]
// RAT changes during instruction dispatch or branch mispredict
`timescale 1ns/100ps

module rat (
	input                      clock,
	input                      reset,
	input                      mispredict_thread_0, // high if a mispredicted branch from thread 0 is committed
	input                      mispredict_thread_1, // high if a mispredicted branch from thread 1 is committed
	input [1:0] [`PR_BITS-1:0] free_PRN,            // PRN to rename inst_in, from the PRF module
	input ID_RAT [1:0]         inst_in,             // incoming instructions from the ID module
	input RAT_ARR [1:0]        RRAT_arr,            // used to recover RAT in case of branch mispredict
	input                      stall_0,
	input                      stall_1,

	output RAT_ARR [1:0]       RAT_arr,
	output RAT_PRF [1:0]       inst_out             // renamed inst_in, goes to the PRF module
);

	logic hazard_opa, hazard_opb, hazard_dest_ARN, flush_inst_0, flush_inst_1, same_thread;
	RAT_ARR [1:0] n_RAT_arr; // 2 RATs, one for each thread

	always_comb begin
		// flush instruction if there is a mispredicted branch with the same thread id.
		// same_thread is high if both instructions have the same thread id.
		flush_inst_0         = inst_in[0].thread_id ? mispredict_thread_1 : mispredict_thread_0;
		flush_inst_1         = inst_in[1].thread_id ? mispredict_thread_1 : mispredict_thread_0;
		same_thread          = inst_in[0].thread_id==inst_in[1].thread_id;

		// instructions can only write to a reg if the destination ARN is not 0 and if that instruction
		// is not flushed because of branch mispredict. If write is high for an inst_out, the free bit
		// for the dest_PRN of that inst will be set to 0 in the PRF module
		inst_out[0].write     = inst_in[0].valid && !stall_0 && (inst_in[0].ARN_dest!=`ZERO_REG) && !flush_inst_0;
		inst_out[1].write     = inst_in[1].valid && !stall_1 && (inst_in[1].ARN_dest!=`ZERO_REG) && !flush_inst_1;

		// need this to handle banches that writes the next pc to a dest reg
		inst_out[0].next_pc       = inst_in[0].next_pc;
		inst_out[0].uncond_branch = inst_in[0].uncond_branch;
		inst_out[1].next_pc       = inst_in[1].next_pc;
		inst_out[1].uncond_branch = inst_in[1].uncond_branch;

		// hazard_dest_ARN is high if both instructions are writing to the same ARN. If it is high, 
		// the second instuction's PRN_dest will be stored in the RAT instead of the first one.
		// hazard_opa is high if inst_0 writes to the ARN_opa of inst_1, used to determine PRN forwarding.
		hazard_dest_ARN      = inst_out[1].write && same_thread && inst_in[0].ARN_dest==inst_in[1].ARN_dest;
		hazard_opa           = inst_out[0].write && same_thread && inst_in[0].ARN_dest==inst_in[1].ARN_opa;
		hazard_opb           = inst_out[0].write && same_thread && inst_in[0].ARN_dest==inst_in[1].ARN_opb;

		// sets inst_out[0]
		inst_out[0].PRN_opa   = RAT_arr[inst_in[0].thread_id][inst_in[0].ARN_opa];
		inst_out[0].PRN_opb   = RAT_arr[inst_in[0].thread_id][inst_in[0].ARN_opb];
		inst_out[0].thread_id = inst_in[0].thread_id;
		inst_out[0].PRN_dest  = inst_out[0].write ? free_PRN[0] : `PR_SIZE-1;

		// sets inst_out[1]
		// forwards the PRN_dest of inst_0 if hazard_opa or hazard_opb is high 
		inst_out[1].PRN_opa   = hazard_opa ? free_PRN[0] : RAT_arr[inst_in[1].thread_id][inst_in[1].ARN_opa];
		inst_out[1].PRN_opb   = hazard_opb ? free_PRN[0] : RAT_arr[inst_in[1].thread_id][inst_in[1].ARN_opb];
		inst_out[1].thread_id = inst_in[1].thread_id;
		inst_out[1].PRN_dest  = inst_out[1].write ? free_PRN[1] : `PR_SIZE-1;

		n_RAT_arr = RAT_arr;
		if(inst_out[0].write && !hazard_dest_ARN)
			n_RAT_arr[inst_in[0].thread_id][inst_in[0].ARN_dest] = free_PRN[0];
		if(inst_out[1].write)
			n_RAT_arr[inst_in[1].thread_id][inst_in[1].ARN_dest] = free_PRN[1];
		if(mispredict_thread_0)
			n_RAT_arr[0] = RRAT_arr[0];
		if(mispredict_thread_1)
			n_RAT_arr[1] = RRAT_arr[1];
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i=0; i < `AR_SIZE; i++) begin
				RAT_arr[0][i] <= #1 `PR_SIZE-1;
				RAT_arr[1][i] <= #1 `PR_SIZE-1;
			end
		end else begin
			for(int i=0; i < `AR_SIZE; i++) begin
				RAT_arr[0][i] <= #1 n_RAT_arr[0][i];
				RAT_arr[1][i] <= #1 n_RAT_arr[1][i];
			end
		end
	end
endmodule