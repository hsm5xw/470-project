`timescale 1ns/100ps

module dispatch (
	input clock,
	input reset,

	input ID_DISPATCH id_disp_0,
	input ID_DISPATCH id_disp_1,

	input mispredict_ROB_0,
	input mispredict_ROB_1,

	input ROB_0_full,
	input ROB_0_almost_full,

	input ROB_1_full,
	input ROB_1_almost_full,

	input RS_full,
	input RS_almost_full,

	input LSQ_full,
	input LSQ_almost_full,

	input [`ROB_BITS-1:0] ROB_0_tail,
	input [`ROB_BITS-1:0] ROB_1_tail,

	input PRF_DISPATCH PRF_out_0,
	input PRF_DISPATCH PRF_out_1,

	output logic stall_0,             // if 1 thread, stall 0 implies stall 1
	output logic stall_1,

	output DISPATCH_ROB disp_ROB_0,   // what goes to ROB_0
	output DISPATCH_ROB disp_ROB_1,   // what goes to ROB_0_b or ROB_1, depending
	                                  // ROB_1 should never get 2 instructions

	output DISPATCH_RS  disp_RS_0,    // dispatched instruction 0 from dispatch module
	output DISPATCH_RS  disp_RS_1,    // dispatched instruction 1 from dispatch module	   

	output DISPATCH_LSQ disp_LSQ_0,   // all the necessary things for LSQ
	output DISPATCH_LSQ disp_LSQ_1    // from instructions 0 and 1
);

	// intermediary logic bits for calculating stalls
	logic ROB_stall_0, ROB_stall_1;
	logic LSQ_stall_0, LSQ_stall_1;
	logic RS_stall_0, RS_stall_1;
	logic RS_0_to_dispatch, RS_1_to_dispatch;
	logic multi_threaded, thread_0_active;
	logic disp_to_LSQ_0, disp_to_LSQ_1;

	logic stall_or_mispredict_0, stall_or_mispredict_1, mispredict_thread;
	
	// set up possible immediates:
	//   mem_disp: sign-extended 16-bit immediate for memory format
	//   br_disp: sign-extended 21-bit immediate * 4 for branch displacement
	//   alu_imm: zero-extended 8-bit immediate for ALU ops
	wire [63:0] fork_disp_0 = { 8'b0, id_disp_0.instr[23:0] };
	wire [63:0] mem_disp_0  = { {48{id_disp_0.instr[15]}}, id_disp_0.instr[15:0] };
	wire [63:0] alu_imm_0   = { 56'b0, id_disp_0.instr[20:13] };
	
	wire [63:0] fork_disp_1 = { 8'b0, id_disp_1.instr[23:0] };
	wire [63:0] mem_disp_1  = { {48{id_disp_1.instr[15]}}, id_disp_1.instr[15:0] };
	wire [63:0] alu_imm_1   = { 56'b0, id_disp_1.instr[20:13] };
	
	logic [`ROB_BITS-1:0] ROB_0_tail_plus, ROB_1_tail_plus;

	//
	// ALU id_disp_0.opA mux
	//
	always_comb begin
		// Defaults with easy to identify values
		disp_RS_0.op1_ready     = 0;
		disp_RS_0.op1_value     = 0;
		disp_RS_0.op1_PRF_index = 0;
		
		disp_LSQ_0.offset               = 0;
		disp_LSQ_0.value_to_store       = 0;
		disp_LSQ_0.value_to_store_ready = 0;
		disp_LSQ_0.value_to_store_PRN   = 0;
		case (id_disp_0.opa_select)
			ALU_OPA_IS_REGA: begin
				disp_RS_0.op1_ready     = PRF_out_0.ready_opa;
				disp_RS_0.op1_value     = PRF_out_0.value_opa;
				disp_RS_0.op1_PRF_index = id_disp_0.opa_PRN;
			end	
			ALU_OPA_IS_MEM_DISP: begin
				disp_RS_0.op1_ready     = 1;
				disp_RS_0.op1_value     = mem_disp_0;
				disp_RS_0.op1_PRF_index = id_disp_0.opa_PRN;

				disp_LSQ_0.offset               = mem_disp_0;
				disp_LSQ_0.value_to_store       = PRF_out_0.value_opa;
				disp_LSQ_0.value_to_store_ready = PRF_out_0.ready_opa;
				disp_LSQ_0.value_to_store_PRN   = id_disp_0.opa_PRN;
			end
			ALU_OPA_IS_NPC: begin
				disp_RS_0.op1_ready     = 1;
				disp_RS_0.op1_value     = id_disp_0.next_pc;
				disp_RS_0.op1_PRF_index = id_disp_0.opa_PRN;
			end
			ALU_OPA_IS_NOT3: begin
				disp_RS_0.op1_ready     = 1;
				disp_RS_0.op1_value     = ~64'h3;
				disp_RS_0.op1_PRF_index = id_disp_0.opa_PRN;
			end
		endcase
	end
	
	//
	// ALU id_disp_1.opA mux
	//
	always_comb begin
		// Defaults with easy to identify values
		disp_RS_1.op1_ready     = 0;
		disp_RS_1.op1_value     = 0;
		disp_RS_1.op1_PRF_index = 0;
		
		disp_LSQ_1.offset               = 0;
		disp_LSQ_1.value_to_store       = 0;
		disp_LSQ_1.value_to_store_ready = 0;
		disp_LSQ_1.value_to_store_PRN   = 0;
		case (id_disp_1.opa_select)
			ALU_OPA_IS_REGA: begin
				disp_RS_1.op1_ready     = PRF_out_1.ready_opa;
				disp_RS_1.op1_value     = PRF_out_1.value_opa;
				disp_RS_1.op1_PRF_index = id_disp_1.opa_PRN;
			end	
			ALU_OPA_IS_MEM_DISP: begin
				disp_RS_1.op1_ready     = 1;
				disp_RS_1.op1_value     = mem_disp_1;
				disp_RS_1.op1_PRF_index = id_disp_1.opa_PRN;

				disp_LSQ_1.offset               = mem_disp_1;
				disp_LSQ_1.value_to_store       = PRF_out_1.value_opa;
				disp_LSQ_1.value_to_store_ready = PRF_out_1.ready_opa;
				disp_LSQ_1.value_to_store_PRN   = id_disp_1.opa_PRN;
			end
			ALU_OPA_IS_NPC: begin
				disp_RS_1.op1_ready     = 1;
				disp_RS_1.op1_value     = id_disp_1.next_pc;
				disp_RS_1.op1_PRF_index = id_disp_1.opa_PRN;
			end
			ALU_OPA_IS_NOT3: begin
				disp_RS_1.op1_ready     = 1;
				disp_RS_1.op1_value     = ~64'h3;
				disp_RS_1.op1_PRF_index = id_disp_1.opa_PRN;
			end
		endcase
	end

	
	//
	// ALU id_disp_0.opB mux
	//
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		disp_RS_0.op2_ready     = 0;
		disp_RS_0.op2_value     = 0;
		disp_RS_0.op2_PRF_index = 0;

		disp_LSQ_0.base_addr_ready = 0;
		disp_LSQ_0.base_addr       = 0;
		disp_LSQ_0.base_addr_PRN   = 0;
		
		case (id_disp_0.opb_select)
			ALU_OPB_IS_REGB: begin
				disp_RS_0.op2_ready     = PRF_out_0.ready_opb;
				disp_RS_0.op2_value     = PRF_out_0.value_opb;
				disp_RS_0.op2_PRF_index = id_disp_0.opb_PRN;

				disp_LSQ_0.base_addr_ready = PRF_out_0.ready_opb;
				disp_LSQ_0.base_addr       = PRF_out_0.value_opb;
				disp_LSQ_0.base_addr_PRN   = id_disp_0.opb_PRN;
			end
			ALU_OPB_IS_ALU_IMM:	begin
				disp_RS_0.op2_ready     = 1;
				disp_RS_0.op2_value     = alu_imm_0;
				disp_RS_0.op2_PRF_index = id_disp_0.opb_PRN;
			end
			ALU_OPB_IS_BR_DISP: begin
				disp_RS_0.op2_ready     = PRF_out_0.ready_opa;
				disp_RS_0.op2_value     = PRF_out_0.value_opa;
				disp_RS_0.op2_PRF_index = id_disp_0.opa_PRN;
			end
		endcase 
	end
	
	//
	// ALU id_disp_1.opB mux
	//
	always_comb begin
		 // Default value, Set only because the case isnt full.  If you see this
		 // value on the output of the mux you have an invalid opb_select
		disp_RS_1.op2_ready     = 0;
		disp_RS_1.op2_value     = 0;
		disp_RS_1.op2_PRF_index = 0;
		
		disp_LSQ_1.base_addr_ready = 0;
		disp_LSQ_1.base_addr       = 0;
		disp_LSQ_1.base_addr_PRN   = 0;
		
		case (id_disp_1.opb_select)
			ALU_OPB_IS_REGB: begin
				disp_RS_1.op2_ready     = PRF_out_1.ready_opb;
				disp_RS_1.op2_value     = PRF_out_1.value_opb;
				disp_RS_1.op2_PRF_index = id_disp_1.opb_PRN;

				disp_LSQ_1.base_addr_ready = PRF_out_1.ready_opb;
				disp_LSQ_1.base_addr       = PRF_out_1.value_opb;
				disp_LSQ_1.base_addr_PRN   = id_disp_1.opb_PRN;
			end
			ALU_OPB_IS_ALU_IMM: begin
				disp_RS_1.op2_ready     = 1;
				disp_RS_1.op2_value     = alu_imm_1;
				disp_RS_1.op2_PRF_index = id_disp_1.opb_PRN;
			end
			ALU_OPB_IS_BR_DISP: begin
				disp_RS_1.op2_ready     = PRF_out_1.ready_opa;
				disp_RS_1.op2_value     = PRF_out_1.value_opa;
				disp_RS_1.op2_PRF_index = id_disp_1.opa_PRN;
			end
		endcase 
	end
	
	// Handling destination registers for instructions 0 and 1
	assign disp_RS_0.dest_PRF_index = id_disp_0.PRN_dest;
	assign disp_RS_1.dest_PRF_index = id_disp_1.PRN_dest;
	
	assign disp_ROB_0.ARN_dest = id_disp_0.ARN_dest;
	assign disp_ROB_0.PRN_dest = id_disp_0.PRN_dest;
	assign disp_ROB_1.ARN_dest = id_disp_1.ARN_dest;
	assign disp_ROB_1.PRN_dest = id_disp_1.PRN_dest;
	
	assign disp_LSQ_0.PRN_dest = id_disp_0.PRN_dest;
	assign disp_LSQ_1.PRN_dest = id_disp_1.PRN_dest;
	

	// Determining if instructions can be dispatched
	// and if so to which modules
	assign multi_threaded  = id_disp_0.thread_ID != id_disp_1.thread_ID;
	assign thread_0_active = id_disp_0.thread_ID == 0;
	// This block calculates if there is a stall due to ROB capacity
	always_comb begin
		// stall both if stall_0 and threads are equal
		ROB_stall_0 = 0;
		ROB_stall_1 = 0;
		if(thread_0_active) begin
			if(ROB_0_full && !multi_threaded) begin  // If both instr go to ROB_0, stall if ROB_0 full
				ROB_stall_0 = 1;
				ROB_stall_1 = 1;
			end
			else if(ROB_0_full)											 // Otherwise, stall just the one that goes to ROB_0
				ROB_stall_0 = 1;
			
			if(ROB_0_almost_full && !multi_threaded) // If both instr go to ROB_0, stall 2nd if almost_full
				ROB_stall_1 = 1;
		end
		if(ROB_1_full && !multi_threaded && !thread_0_active) begin // If both instr to ROB_1, stall if full
			ROB_stall_0 = 1;
			ROB_stall_1 = 1;
		end
		else if(ROB_1_full && multi_threaded)			 // If only second instr goes to ROB_1, stall that if full
			ROB_stall_1 = 1;

		if(ROB_1_almost_full && !multi_threaded && !thread_0_active) // If both instr to ROB_1, stall second if almost_full
			ROB_stall_1 = 1;

		// QUESTION: do both instructions need to stall if either stalls or will IF handle it in the case that
		//           both instructions are from the same thread, 0 dispatches but 1 doesn't.
		//           IE: will fetch move the second instruction to the first slot, and decode squashes?
		// I will assume that if one stalls both stall in the case that there is only 1 active thread. 
		// -- simpler but potential to hurt perf in edge cases?
	end

	// This block calculates if there is a stall due to RS capacity -> thread_0 given priority
	// If the instruction doesn't need the RS, then the stall will be low
	// If not multithreaed, will need to check if either is high and stall both?
	always_comb begin
			// Note the below 2 if statements were originally copied from the dispatch logic, now the to_dispatch bits will be used there.
		RS_0_to_dispatch = 0;
		RS_1_to_dispatch = 0;
		if(id_disp_0.ARN_dest==`ZERO_REG && id_disp_0.instr_type!=BRANCH && id_disp_0.instr_type!=UNCOND_BRANCH) begin   // The only operations with ZERO_REG as dest don't go to RS, or are certain branches
			RS_0_to_dispatch = 0;
		end // if id_disp_1.ARN_dest == `ZERO_REG
		else begin
			RS_0_to_dispatch = 1;
		end 

		if(id_disp_1.ARN_dest==`ZERO_REG && id_disp_1.instr_type!=BRANCH && id_disp_1.instr_type!=UNCOND_BRANCH) begin   // The only operations with ZERO_REG as dest don't go to RS, or are certain branches
			RS_1_to_dispatch = 0;
		end // if id_disp_1.ARN_dest == `ZERO_REG
		else begin
			RS_1_to_dispatch = 1;
		end // else

		RS_stall_0 = 0;
		RS_stall_1 = 0;
		if(RS_full) begin
			if(RS_0_to_dispatch)
				RS_stall_0 = 1;
			if(RS_1_to_dispatch)
				RS_stall_1 = 1;
		end // if RS_full
		else if(RS_almost_full) begin
			if(RS_0_to_dispatch && RS_1_to_dispatch) begin
				RS_stall_1 = 1;
			end //if both would dispatch
		end // else if
	end // comb


	// This block determines if the LSQ being full/almost_full will cause a stall
	//   and which ones would be stalled.
	always_comb begin
		LSQ_stall_0 = 0;
		LSQ_stall_1 = 0;
		if(LSQ_full) begin
			if(disp_to_LSQ_0)
				LSQ_stall_0 = 1;
			if(disp_to_LSQ_1)
				LSQ_stall_1 = 1;
		end // if RS_full
		else if(LSQ_almost_full) begin
			if(disp_to_LSQ_0 && disp_to_LSQ_1) begin  // thread_0 has priority
				LSQ_stall_1 = 1;
			end //if both would dispatch
		end // else if
	end

	// This block uses the intermediate bits for various stalls and determines
	//   if an instruction is to be stalled. I assumed we would stall both instructions if
	//   either had stalled and the threads were the same (multi_threaded == 0)
	always_comb begin
		mispredict_thread = thread_0_active ? mispredict_ROB_0 : mispredict_ROB_1;
		if(multi_threaded) begin
			stall_0 = (ROB_stall_0 || RS_stall_0 || LSQ_stall_0) && !mispredict_ROB_0;
			stall_1 = (ROB_stall_1 || RS_stall_1 || LSQ_stall_1) && !mispredict_ROB_1;
		end
		else begin
			stall_0 = (ROB_stall_0 || RS_stall_0 || LSQ_stall_0 || ROB_stall_1 || RS_stall_1 || LSQ_stall_1) 
			          && !mispredict_thread;
			stall_1 = stall_0;
		end
	end

	assign disp_to_LSQ_0 = id_disp_0.rd_mem || id_disp_0.wr_mem;
	assign disp_to_LSQ_1 = id_disp_1.rd_mem || id_disp_1.wr_mem;

	always_comb begin
		if(multi_threaded) begin
			stall_or_mispredict_0 = stall_0 || mispredict_ROB_0 || !id_disp_0.valid;
			stall_or_mispredict_1 = stall_1 || mispredict_ROB_1 || !id_disp_1.valid;
		end
		else if(thread_0_active) begin
			stall_or_mispredict_0 = stall_0 || mispredict_ROB_0 || !id_disp_0.valid;
			stall_or_mispredict_1 = stall_1 || mispredict_ROB_0 || !id_disp_1.valid;
		end
		else begin
			stall_or_mispredict_0 = stall_0 || mispredict_ROB_1 || !id_disp_0.valid;
			stall_or_mispredict_1 = stall_1 || mispredict_ROB_1 || !id_disp_1.valid;
		end
	end

	always_comb begin
		disp_ROB_0.instr_type = id_disp_0.instr_type;
		disp_ROB_1.instr_type = id_disp_1.instr_type;

		if(!stall_or_mispredict_0) begin
			disp_ROB_0.dispatch = 1;

			if(disp_to_LSQ_0) begin
				disp_LSQ_0.dispatch = 1;
				disp_RS_0.dispatch  = 0;
			end	
			else begin
				disp_LSQ_0.dispatch = 0;
				disp_RS_0.dispatch  = RS_0_to_dispatch;   // Logic in RS_stall logic
			end // else

			if( ((!RS_0_to_dispatch && !id_disp_0.wr_mem) || id_disp_0.rd_mem) && 
					(id_disp_0.PRN_dest == `ZERO_REG_PRN)   &&
				  (id_disp_0.instr_type != FORK)          &&
					(id_disp_0.instr_type != HALT) ) begin
				disp_ROB_0.instr_type  = NOOP;
				disp_LSQ_0.dispatch    = 0;
			end else begin
				disp_ROB_0.instr_type  = id_disp_0.instr_type;
			end

		end // if( !stall_or_mispredict_0 )
		else begin
			disp_ROB_0.dispatch = 0;
			disp_RS_0.dispatch  = 0;
			disp_LSQ_0.dispatch = 0;
		end

		if(!stall_or_mispredict_1) begin
			disp_ROB_1.dispatch = 1;

			if(disp_to_LSQ_1) begin
				disp_LSQ_1.dispatch = 1;
				disp_RS_1.dispatch  = 0;
			end	// if(disp_to_LSQ_1)
			else begin
				disp_LSQ_1.dispatch = 0;
				disp_RS_1.dispatch  = RS_1_to_dispatch;  // Logic in RS_stall logic
			end // else

				if( ((!RS_1_to_dispatch && !id_disp_1.wr_mem) || id_disp_1.rd_mem) && 
					(id_disp_1.PRN_dest == `ZERO_REG_PRN)   &&
				  (id_disp_1.instr_type != FORK)          &&
					(id_disp_1.instr_type != HALT) ) begin
				disp_ROB_1.instr_type  = NOOP;
				disp_LSQ_1.dispatch    = 0;
			end else begin
				disp_ROB_1.instr_type  = id_disp_1.instr_type;
			end

		end // if( !stall_or_mispredict_1 )
		else begin
			disp_ROB_1.dispatch = 0;
			disp_RS_1.dispatch  = 0;
			disp_LSQ_1.dispatch = 0;
		end // else
	end // comb

	// Passing everything else through for ROB
	assign disp_ROB_0.dispatch_pc = id_disp_0.instr_type==FORK ? fork_disp_0 : id_disp_0.pc;
	assign disp_ROB_1.dispatch_pc = id_disp_1.instr_type==FORK ? fork_disp_1 : id_disp_1.pc;

	assign disp_ROB_0.thread_ID   = id_disp_0.thread_ID;
	assign disp_ROB_1.thread_ID   = id_disp_1.thread_ID;

	// Passing everything else through for RS
	assign ROB_0_tail_plus = ROB_0_tail + 1'b1;           // For ROB_index
	assign ROB_1_tail_plus = ROB_1_tail + 1'b1;           // For ROB_index

	assign disp_RS_0.branch_cond_op = id_disp_0.instr[28:26];
	assign disp_RS_1.branch_cond_op = id_disp_1.instr[28:26];

	assign disp_RS_0.branch_disp = id_disp_0.instr[20:0];
	assign disp_RS_1.branch_disp = id_disp_1.instr[20:0];

	assign disp_RS_0.instr_type = id_disp_0.instr_type;
	assign disp_RS_1.instr_type = id_disp_1.instr_type;

	assign disp_RS_0.operation = id_disp_0.alu_func;
	assign disp_RS_1.operation = id_disp_1.alu_func;

	assign disp_RS_0.branch_predicted_taken = id_disp_0.branch_taken;
	assign disp_RS_1.branch_predicted_taken = id_disp_1.branch_taken;

	// ** handling ROB_index
	always_comb begin
		if(multi_threaded) begin
			disp_RS_0.ROB_index = ROB_0_tail;
			disp_RS_1.ROB_index = ROB_1_tail;
		end 
		else begin
			if(thread_0_active) begin
				disp_RS_0.ROB_index = ROB_0_tail;
				disp_RS_1.ROB_index = ROB_0_tail_plus;
			end 
			else begin
				disp_RS_0.ROB_index = ROB_1_tail;
				disp_RS_1.ROB_index = ROB_1_tail_plus;
			end
		end
	end

	always_comb begin
		if(id_disp_0.alu_func == ALU_MULQ)	
			disp_RS_0.op_type = MULT;
		else if((id_disp_0.instr_type == BRANCH) || (id_disp_0.instr_type == UNCOND_BRANCH))
			disp_RS_0.op_type = BRANCH_OP;
		else
			disp_RS_0.op_type = ALU;

		if(id_disp_1.alu_func == ALU_MULQ)	
			disp_RS_1.op_type = MULT;
		else if((id_disp_1.instr_type == BRANCH) || (id_disp_1.instr_type == UNCOND_BRANCH))
			disp_RS_1.op_type = BRANCH_OP;
		else
			disp_RS_1.op_type = ALU;
	end

	assign disp_RS_0.thread_ID          = id_disp_0.thread_ID;
	assign disp_RS_0.next_pc            = id_disp_0.next_pc;
	assign disp_RS_0.branch_target_addr = id_disp_0.branch_target_addr;

	assign disp_RS_1.thread_ID          = id_disp_1.thread_ID;
	assign disp_RS_1.next_pc            = id_disp_1.next_pc;
	assign disp_RS_1.branch_target_addr = id_disp_1.branch_target_addr;

	//Passing everything else through for LSQ
	assign disp_LSQ_0.rd_mem    = id_disp_0.rd_mem;
	assign disp_LSQ_0.wr_mem    = id_disp_0.wr_mem;
	assign disp_LSQ_0.ldl_mem   = id_disp_0.ldl_mem;
	assign disp_LSQ_0.stc_mem   = id_disp_0.stc_mem;
	assign disp_LSQ_0.thread_ID = id_disp_0.thread_ID;

	assign disp_LSQ_1.rd_mem    = id_disp_1.rd_mem;
	assign disp_LSQ_1.wr_mem    = id_disp_1.wr_mem;
	assign disp_LSQ_1.ldl_mem   = id_disp_1.ldl_mem;
	assign disp_LSQ_1.stc_mem   = id_disp_1.stc_mem;
	assign disp_LSQ_1.thread_ID = id_disp_1.thread_ID;

	// ** handling ROB_index
	always_comb begin
		if(multi_threaded) begin
			disp_LSQ_0.ROB_index = ROB_0_tail;
			disp_LSQ_1.ROB_index = ROB_1_tail;
		end
		else begin
			if(thread_0_active) begin
				disp_LSQ_0.ROB_index = ROB_0_tail;
				disp_LSQ_1.ROB_index = ROB_0_tail_plus;
			end 
			else begin
				disp_LSQ_0.ROB_index = ROB_1_tail;
				disp_LSQ_1.ROB_index = ROB_1_tail_plus;
			end
		end
	end
endmodule