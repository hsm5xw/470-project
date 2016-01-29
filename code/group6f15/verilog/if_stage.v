`timescale 1ns/100ps

module if_stage(
	input clock,
	input reset,

	input        [1:0] Icache0_valid,
	input [1:0] [63:0] Icache0_data, 
	
	input        [1:0] stall,
	input              fork_committed,
	input       [63:0] fork_addr,

	input ROB_IF [1:0] rob0_inst,
	input ROB_IF [1:0] rob1_inst,
	input              rob0_halt, 
	input              rob1_halt, 																	
	
	output logic       smt_mode,
	output logic       active_thread,

	output logic [1:0] predicted_taken, 

	output logic [1:0] [63:0] proc2Icache0_addr,
	output IF_ID        [1:0] inst_out
);

	logic [63:0] if_NPC_out_0;
	logic [63:0] if_NPC_out_1;
	logic [63:0] if_PC_reg_0;
	logic [63:0] if_PC_reg_1;
	logic [31:0] if_IR_out_0;
	logic [31:0] if_IR_out_1;

	logic [1:0] PC_enable, thread_id;

	logic [1:0] [63:0] npc, pc, pc_plus8, pc_plus4, predicted_addr;

	logic       rob0_mispredict, rob1_mispredict, mispredict;
	logic [1:0] inst0_mispredict, inst1_mispredict;
	logic       n_smt_mode, n_active_thread;;

	PRED_IF  [1:0] branch_logic; //Struct: branch_pc, branch_pred, is_branch
	ROB_PRED [1:0] rob_datain;

	// logic for current cycle
	always_comb begin
		inst_out[0].thread_id = thread_id[0];
		inst_out[0].valid_inst = PC_enable[0];
		inst_out[0].branch_taken = predicted_taken[0];
		inst_out[0].instr = if_IR_out_0;
		inst_out[0].pc = if_PC_reg_0;
		inst_out[0].next_pc = if_NPC_out_0;
		inst_out[0].branch_target_addr = predicted_addr[0];

		inst_out[1].thread_id = thread_id[1];
		inst_out[1].valid_inst = PC_enable[1];
		inst_out[1].branch_taken = predicted_taken[1];
		inst_out[1].instr = if_IR_out_1;
		inst_out[1].pc = if_PC_reg_1;
		inst_out[1].next_pc = if_NPC_out_1;
		inst_out[1].branch_target_addr = predicted_addr[1];

		rob0_mispredict = rob0_inst[0].mispredict || rob0_inst[1].mispredict;
		rob1_mispredict = rob1_inst[0].mispredict || rob1_inst[1].mispredict;

		rob_datain[0].committed_is_branch_0 = rob0_inst[0].is_branch;
		rob_datain[0].branch_taken_0 = rob0_inst[0].branch_actually_taken;
		rob_datain[0].branch_pc_ROB_0 = rob0_inst[0].pc;
		rob_datain[0].branch_target_0 = rob0_inst[0].target_addr;

		rob_datain[0].committed_is_branch_1 = rob0_inst[1].is_branch;
		rob_datain[0].branch_taken_1 = rob0_inst[1].branch_actually_taken;
		rob_datain[0].branch_pc_ROB_1 = rob0_inst[1].pc;
		rob_datain[0].branch_target_1 = rob0_inst[1].target_addr;

		rob_datain[1].committed_is_branch_0 = rob1_inst[0].is_branch;
		rob_datain[1].branch_taken_0 = rob1_inst[0].branch_actually_taken;
		rob_datain[1].branch_pc_ROB_0 = rob1_inst[0].pc;
		rob_datain[1].branch_target_0 = rob1_inst[0].target_addr;

		rob_datain[1].committed_is_branch_1 = rob1_inst[1].is_branch;
		rob_datain[1].branch_taken_1 = rob1_inst[1].branch_actually_taken;
		rob_datain[1].branch_pc_ROB_1 = rob1_inst[1].pc;
		rob_datain[1].branch_target_1 = rob1_inst[1].target_addr;

		// All the ALUs for the IF stage
		pc_plus4[0] = pc[0] + 4;
		pc_plus4[1] = pc[1] + 4;
		pc_plus8[0] = pc[0] + 8;
		pc_plus8[1] = pc[1] + 8;
	end

	// logic for current cycle
	always_comb begin
		n_active_thread = rob0_halt ? 1 : active_thread;
		n_smt_mode      = smt_mode;
		mispredict      = active_thread ? rob1_mispredict : rob0_mispredict;
		
		if(fork_committed)
			n_smt_mode = 1;
		else if(rob0_halt || rob1_halt)
			n_smt_mode = 0;

		if(smt_mode && n_smt_mode) begin
			if_PC_reg_0 = pc[0];
			if_PC_reg_1 = pc[1];

			PC_enable[0] = !rob0_mispredict && Icache0_valid[0] && !stall[0];
			PC_enable[1] = !rob1_mispredict && Icache0_valid[1] && !stall[1];

			if_NPC_out_0 = pc_plus4[0];
			if_NPC_out_1 = pc_plus4[1]; 

			thread_id[0] = 0;
			thread_id[1] = 1; 
		
		end else begin
			if_PC_reg_0 = pc[n_active_thread];
			if_PC_reg_1 = pc_plus4[n_active_thread];

			PC_enable[0] = !mispredict && Icache0_valid[0] && !stall[0];
			PC_enable[1] = !predicted_taken[0] && PC_enable[0] && Icache0_valid[1] && !stall[1];

			if_NPC_out_0 = pc_plus4[n_active_thread];
			if_NPC_out_1 = pc_plus8[n_active_thread]; 

			thread_id[0] = n_active_thread;
			thread_id[1] = n_active_thread;
		end
		

		proc2Icache0_addr[0] = {if_PC_reg_0[63:3], 3'b0};
		proc2Icache0_addr[1] = {if_PC_reg_1[63:3], 3'b0};

		if_IR_out_0 = if_PC_reg_0[2] ? Icache0_data[0][63:32] : Icache0_data[0][31:0];
		if_IR_out_1 = if_PC_reg_1[2] ? Icache0_data[1][63:32] : Icache0_data[1][31:0];

		if_IR_out_0 = PC_enable[0] ? if_IR_out_0 : `NOOP_INST;
		if_IR_out_1 = PC_enable[1] ? if_IR_out_1 : `NOOP_INST;
	end

	predictor pred_0 (
		.clock(clock),
		.reset(reset),
		.if_pc({pc_plus4[0], pc[0]}),
		.rob_data_in(rob_datain[0]),
		.pred_data_out(branch_logic[0])
	);

	predictor pred_1 (
		.clock(clock),
		.reset(reset),
		.if_pc({pc_plus4[1], pc[1]}),
		.rob_data_in(rob_datain[1]),
		.pred_data_out(branch_logic[1])
	);

	// logic for current cycle
	always_comb begin
		inst0_mispredict[0] = rob0_inst[0].mispredict;
		inst1_mispredict[0] = rob0_inst[1].mispredict;
		inst0_mispredict[1] = rob1_inst[0].mispredict;
		inst1_mispredict[1] = rob1_inst[1].mispredict;

		predicted_taken[0] = branch_logic[n_active_thread].branch_pred_0 && branch_logic[n_active_thread].branch_in_BTB_0;
		predicted_taken[1] = branch_logic[n_active_thread].branch_pred_1 && branch_logic[n_active_thread].branch_in_BTB_1;

		predicted_addr[0] = branch_logic[n_active_thread].pred_target_add_0;
		predicted_addr[1] = branch_logic[n_active_thread].pred_target_add_1;

		if(smt_mode && n_smt_mode) begin
			predicted_taken[0]  = branch_logic[0].branch_pred_0 && branch_logic[0].branch_in_BTB_0;
			predicted_taken[1]  = branch_logic[1].branch_pred_0 && branch_logic[1].branch_in_BTB_0;

			predicted_addr[0] = branch_logic[0].pred_target_add_0;
			predicted_addr[1] = branch_logic[1].pred_target_add_0;
		end 
	end

	// logic for next cycle
	always_comb begin
		npc[0] = pc[0];
		npc[1] = pc[1];

		if(!smt_mode || (smt_mode && !n_smt_mode)) begin

			if(inst0_mispredict[n_active_thread])
				npc[n_active_thread] = rob_datain[n_active_thread].branch_target_0;

			else if(inst1_mispredict[n_active_thread])
				npc[n_active_thread] = rob_datain[n_active_thread].branch_target_1;

			else if(predicted_taken[0] && PC_enable[0])
				npc[n_active_thread] = branch_logic[n_active_thread].pred_target_add_0;

			else if(predicted_taken[1] && PC_enable[1])
				npc[n_active_thread] = branch_logic[n_active_thread].pred_target_add_1;

			else if(PC_enable[0] && PC_enable[1])
				npc[n_active_thread] = pc_plus8[n_active_thread];

			else if(PC_enable[0] && !PC_enable[1])
				npc[n_active_thread] = pc_plus4[n_active_thread];

			npc[1] = fork_committed ? fork_addr : npc[1];
		
		end else begin

			for(int i=0; i < 2; i++) begin
				if(inst0_mispredict[i])
					npc[i] = rob_datain[i].branch_target_0;

				else if(inst1_mispredict[i])
					npc[i] = rob_datain[i].branch_target_1;

				else if(predicted_taken[i] && PC_enable[i])
					npc[i] = branch_logic[i].pred_target_add_0;

				else if(PC_enable[i])
					npc[i] = pc_plus4[i];
			end
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock)
	begin
		if(reset) begin
			active_thread <= #1 0;
			smt_mode      <= #1 0;
			pc[0]         <= #1 64'b0;
			pc[1]         <= #1 64'b0;
		
		end else begin
			active_thread <= #1 n_active_thread;
			smt_mode      <= #1 n_smt_mode;
			pc[0]         <= #1 npc[0];
			pc[1]         <= #1 npc[1];
		end
	end
endmodule