`timescale 1ns/100ps

module rob #(parameter THREAD_ID=0) (
	input clock,
	input reset,
	input CDB CDB_0,
	input CDB CDB_1,
	input DISPATCH_ROB disp_ROB_0,
	input DISPATCH_ROB disp_ROB_1,

	output logic [`ROB_BITS-1:0] head_index, 
	output logic [`ROB_BITS-1:0] n_head_index, 
	output logic [`ROB_BITS-1:0] tail_index, 
	output logic [`ROB_BITS-1:0] n_tail_index, 
	output logic [`ROB_BITS:0]   count,

	output ROB_RRAT head,
	output ROB_RRAT head_plus1,
	output ROB_IF head_branch,
	output ROB_IF head_plus1_branch,
	output logic full,        // goes to dispatch
	output logic almost_full, // goes to dispatch
	output logic halt,        // instruction fetch
	output logic nuke,
	output logic fork_committed,
	output logic [`ADDR_BITS-1:0] fork_addr
);
	
	ROB_DATA [`ROB_SIZE-1:0] ROB_arr, n_ROB_arr; // holds ROB data for each entry
	logic [`ROB_BITS-1:0] head_index_plus_1, tail_index_plus_1;
	logic [`ROB_BITS-1:0] n_head_index_plus_1;
	logic [`ROB_BITS:0] n_count;
	logic n_full, n_almost_full, n_halt, n_head_nuke;
	logic n_committed_0, n_committed_1, n_mispredict_0, n_mispredict_1;
	logic CDB_0_valid_thread, CDB_1_valid_thread;
	logic dispatch_0_valid_thread, dispatch_1_valid_thread;
	logic dispatch_executed_0, dispatch_executed_1;
	logic dispatch_0_inst, dispatch_1_inst, dispatch_2_inst;
	logic CDB_0_head, CDB_0_head_plus1, CDB_1_head, CDB_1_head_plus1;
	logic n_branch_actually_taken_0, n_branch_actually_taken_1, n_is_branch_0, n_is_branch_1;
	logic [`ADDR_BITS-1:0] n_target_addr_0, n_target_addr_1, n_fork_addr;
	logic n_fork_committed, n_nuke;


	assign dispatch_executed_0 = disp_ROB_0.instr_type == HALT ||
	                             disp_ROB_0.instr_type == FORK ||
	                             disp_ROB_0.instr_type == NOOP;
  
	assign dispatch_executed_1 = disp_ROB_1.instr_type == HALT || 
	                             disp_ROB_1.instr_type == FORK ||
	                             disp_ROB_1.instr_type == NOOP;

	always_comb begin
		n_count             = count;
		head_index_plus_1   = head_index + 1;
		tail_index_plus_1   = tail_index + 1;

		
		// Are the incoming instructions going to the right ROB?
		dispatch_0_valid_thread = disp_ROB_0.dispatch && disp_ROB_0.thread_ID==THREAD_ID;
		dispatch_1_valid_thread = disp_ROB_1.dispatch && disp_ROB_1.thread_ID==THREAD_ID;

		
		// how many instructions are dispatching?
		dispatch_0_inst = !dispatch_0_valid_thread & !dispatch_1_valid_thread; // both read ports are not valid
		dispatch_1_inst = dispatch_0_valid_thread ^ dispatch_1_valid_thread;   // only one read port is valid
		dispatch_2_inst = dispatch_0_valid_thread & dispatch_1_valid_thread;   // both read ports are valid


		// figuring out the head and tail index for the next cycle
		n_head_index = nuke                 ? head_index     :
		               head_plus1.committed ? head_index + 2 :
		               head.committed       ? head_index + 1 : 
		               head_index;

		n_tail_index = dispatch_2_inst ? tail_index + 2 :
		               dispatch_1_inst ? tail_index + 1 :
		               tail_index;

		n_head_index_plus_1 = n_head_index + 1;

		
		// Are the CDBs broadcasting to either n_head or n_head_plus_1
		CDB_0_valid_thread = CDB_0.valid && CDB_0.thread_ID == THREAD_ID;
		CDB_1_valid_thread = CDB_1.valid && CDB_1.thread_ID == THREAD_ID;

		CDB_0_head       = CDB_0_valid_thread && CDB_0.ROB_index == n_head_index;
		CDB_0_head_plus1 = CDB_0_valid_thread && CDB_0.ROB_index == n_head_index_plus_1;
		CDB_1_head       = CDB_1_valid_thread && CDB_1.ROB_index == n_head_index;
		CDB_1_head_plus1 = CDB_1_valid_thread && CDB_1.ROB_index == n_head_index_plus_1;


		// is n_head committing? If yes, is it a branch? If yes, is it a mispredicted branch?
		n_committed_0 = (count > 0) && (ROB_arr[n_head_index].executed || CDB_0_head || CDB_1_head);

		n_is_branch_0 = n_committed_0 && ((ROB_arr[n_head_index].instr_type == BRANCH) ||
		                                  (ROB_arr[n_head_index].instr_type == UNCOND_BRANCH));

		n_mispredict_0 = !n_is_branch_0  ? 0 :
		                 CDB_0_head      ? CDB_0.mispredict :
		                 CDB_1_head      ? CDB_1.mispredict :
		                 ROB_arr[n_head_index].mispredict;

		// is n_head_plus_1 committing? If yes, is it a branch? If yes, is it a mispredicted branch?
		// For head_plus_1 to commit, head must commit and head can't be a halt or mispredicted branch
		n_head_nuke = (ROB_arr[n_head_index].instr_type==HALT) || n_mispredict_0;

		n_committed_1 = (count > 1) && !n_head_nuke && n_committed_0 && !(ROB_arr[head_index].instr_type == FORK)
		             && (ROB_arr[n_head_index_plus_1].executed || CDB_0_head_plus1 || CDB_1_head_plus1);

		n_is_branch_1 = n_committed_1 && ((ROB_arr[n_head_index_plus_1].instr_type == BRANCH) ||
		                                  (ROB_arr[n_head_index_plus_1].instr_type == UNCOND_BRANCH));

		n_mispredict_1 = !n_is_branch_1   ? 0 :
		                 CDB_0_head_plus1 ? CDB_0.mispredict :
		                 CDB_1_head_plus1 ? CDB_1.mispredict :
		                 ROB_arr[n_head_index_plus_1].mispredict;

		// is a halt instruction being committed? Do we have to nuke the ROB?
		n_halt = (ROB_arr[n_head_index].instr_type==HALT) || 
		         (n_committed_1 && ROB_arr[n_head_index_plus_1].instr_type==HALT);

		n_nuke = n_halt || n_mispredict_0 || n_mispredict_1;

		// Is the committed branch supposed to be taken? If yes, what is the target address?
		n_branch_actually_taken_0 = CDB_0_head ? CDB_0.branch_actually_taken :
		                            CDB_1_head ? CDB_1.branch_actually_taken :
		                            ROB_arr[n_head_index].branch_actually_taken;

		n_target_addr_0 = CDB_0_head ? CDB_0.FU_result :
		                  CDB_1_head ? CDB_1.FU_result :
		                  ROB_arr[n_head_index].target_addr;

		n_branch_actually_taken_1 = CDB_0_head_plus1 ? CDB_0.branch_actually_taken :
		                            CDB_1_head_plus1 ? CDB_1.branch_actually_taken :
		                            ROB_arr[n_head_index_plus_1].branch_actually_taken;

		n_target_addr_1 = CDB_0_head_plus1 ? CDB_0.FU_result :
		                  CDB_1_head_plus1 ? CDB_1.FU_result :
		                  ROB_arr[n_head_index_plus_1].target_addr;

		// is a fork instruction being committed? What is the fork address?
		if(n_committed_0 && (ROB_arr[n_head_index].instr_type == FORK)) begin
			n_fork_committed = 1;
			n_fork_addr      = ROB_arr[n_head_index].target_addr;
		end else if(n_committed_1 && (ROB_arr[n_head_index_plus_1].instr_type == FORK)) begin
			n_fork_committed = 1;
			n_fork_addr      = ROB_arr[n_head_index_plus_1].target_addr;
		end else begin
			n_fork_committed = 0;
			n_fork_addr      = 0;
		end

		// logic for count
		if(dispatch_0_inst)
			n_count = n_committed_1 ? count-2 :
			          n_committed_0 ? count-1 : count;
		if(dispatch_1_inst)
			n_count = n_committed_1 ? count-1 :
			          n_committed_0 ? count   : count+1;
		if(dispatch_2_inst)
			n_count = n_committed_1 ? count   :
			          n_committed_0 ? count+1 : count+2;

		n_full        = n_count >= `ROB_SIZE-2;
		n_almost_full = n_count == `ROB_SIZE-3;
	end

	always_comb begin
		// Update ROB array if an instruction in the ROB has finished executing
		// Update ROB array if an instruction was a mispredicted branch
		n_ROB_arr = ROB_arr;
		if(CDB_0_valid_thread) begin
			n_ROB_arr[CDB_0.ROB_index].executed              = 1;
			n_ROB_arr[CDB_0.ROB_index].mispredict            = CDB_0.mispredict;
			n_ROB_arr[CDB_0.ROB_index].branch_actually_taken = CDB_0.branch_actually_taken;
			n_ROB_arr[CDB_0.ROB_index].target_addr = CDB_0.FU_result;
		end 
		if(CDB_1_valid_thread) begin
			n_ROB_arr[CDB_1.ROB_index].executed              = 1;
			n_ROB_arr[CDB_1.ROB_index].mispredict            = CDB_1.mispredict;
			n_ROB_arr[CDB_1.ROB_index].branch_actually_taken = CDB_1.branch_actually_taken;
			n_ROB_arr[CDB_1.ROB_index].target_addr           = CDB_1.FU_result;
		end 
		
		// invalidate the entry occupied by the committed instruction(s)
		if(head.committed && !(dispatch_1_inst && (head_index == tail_index)) && 
		                     !(dispatch_2_inst && (head_index == tail_index_plus_1))) begin				
			n_ROB_arr[head_index].executed              = 0;
			n_ROB_arr[head_index].instr_type            = OTHER;
			n_ROB_arr[head_index].mispredict            = 0;
			n_ROB_arr[head_index].ARN_dest              = 0;          
			n_ROB_arr[head_index].PRN_dest              = 0;
			n_ROB_arr[head_index].branch_actually_taken = 0;
			n_ROB_arr[head_index].pc                    = 0;
			n_ROB_arr[head_index].target_addr           = 0;
		end
		if(head_plus1.committed && !(dispatch_2_inst && (head_index_plus_1 == tail_index_plus_1))) begin
			n_ROB_arr[head_index_plus_1].executed              = 0;
			n_ROB_arr[head_index_plus_1].instr_type            = OTHER;
			n_ROB_arr[head_index_plus_1].mispredict            = 0;
			n_ROB_arr[head_index_plus_1].ARN_dest              = 0;          
			n_ROB_arr[head_index_plus_1].PRN_dest              = 0;
			n_ROB_arr[head_index_plus_1].branch_actually_taken = 0;
			n_ROB_arr[head_index_plus_1].pc                    = 0;
			n_ROB_arr[head_index_plus_1].target_addr           = 0;
		end
		
		// if disp_ROB_0 is valid, fill tail index with disp_ROB_0
		// else, if disp_ROB_1 is valid, fill tail index with disp_ROB_1
		if(dispatch_0_valid_thread) begin
			n_ROB_arr[tail_index].ARN_dest              = disp_ROB_0.ARN_dest;          
			n_ROB_arr[tail_index].PRN_dest              = disp_ROB_0.PRN_dest;
			n_ROB_arr[tail_index].executed              = dispatch_executed_0;
			n_ROB_arr[tail_index].mispredict            = 0;
			n_ROB_arr[tail_index].branch_actually_taken = 0;
			n_ROB_arr[tail_index].instr_type            = disp_ROB_0.instr_type;
			n_ROB_arr[tail_index].pc                    = disp_ROB_0.dispatch_pc;
			n_ROB_arr[tail_index].target_addr           = disp_ROB_0.dispatch_pc;
		end else if(dispatch_1_valid_thread) begin
			n_ROB_arr[tail_index].ARN_dest              = disp_ROB_1.ARN_dest;          
			n_ROB_arr[tail_index].PRN_dest              = disp_ROB_1.PRN_dest;
			n_ROB_arr[tail_index].executed              = dispatch_executed_1;
			n_ROB_arr[tail_index].mispredict            = 0;
			n_ROB_arr[tail_index].branch_actually_taken = 0;
			n_ROB_arr[tail_index].instr_type            = disp_ROB_1.instr_type;
			n_ROB_arr[tail_index].pc                    = disp_ROB_1.dispatch_pc;
			n_ROB_arr[tail_index].target_addr           = disp_ROB_1.dispatch_pc;
		end
		
		// if both disp_ROB_0 and disp_ROB_1 are valid, fill tail_index_plus_1 with disp_ROB_1
		if(dispatch_2_inst) begin
			n_ROB_arr[tail_index_plus_1].ARN_dest              = disp_ROB_1.ARN_dest;          
			n_ROB_arr[tail_index_plus_1].PRN_dest              = disp_ROB_1.PRN_dest;
			n_ROB_arr[tail_index_plus_1].executed              = dispatch_executed_1;
			n_ROB_arr[tail_index_plus_1].mispredict            = 0;
			n_ROB_arr[tail_index_plus_1].branch_actually_taken = 0;
			n_ROB_arr[tail_index_plus_1].instr_type            = disp_ROB_1.instr_type;
			n_ROB_arr[tail_index_plus_1].pc                    = disp_ROB_1.dispatch_pc;
			n_ROB_arr[tail_index_plus_1].target_addr           = disp_ROB_1.dispatch_pc;
		end 
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			for(int i = 0; i < `ROB_SIZE; i++) begin
				ROB_arr[i].ARN_dest              <= #1 0;
				ROB_arr[i].PRN_dest              <= #1 0;
				ROB_arr[i].executed              <= #1 0;
				ROB_arr[i].mispredict            <= #1 0;
				ROB_arr[i].branch_actually_taken <= #1 0;
				ROB_arr[i].instr_type            <= #1 OTHER;
				ROB_arr[i].pc                    <= #1 0;
				ROB_arr[i].target_addr           <= #1 0;
			end

			head.committed <= #1 0;
			head.ARN_dest  <= #1 0;
			head.PRN_dest  <= #1 0;

			head_plus1.committed <= #1 0;
			head_plus1.ARN_dest  <= #1 0;
			head_plus1.PRN_dest  <= #1 0;

			head_branch.is_branch             <= #1 0;
			head_branch.branch_actually_taken <= #1 0;
			head_branch.mispredict            <= #1 0;
			head_branch.pc                    <= #1 0;
			head_branch.target_addr           <= #1 0;

			head_plus1_branch.is_branch             <= #1 0;
			head_plus1_branch.branch_actually_taken <= #1 0;
			head_plus1_branch.mispredict            <= #1 0;
			head_plus1_branch.pc                    <= #1 0;
			head_plus1_branch.target_addr           <= #1 0;

			full         <= #1 0;
			almost_full  <= #1 0;
			tail_index   <= #1 0;
			head_index   <= #1 0;
			count        <= #1 0;

			halt         <= #1 0;
			nuke         <= #1 0;
			fork_committed      <= #1 0;
			fork_addr    <= #1 0;
		end 
		else if(nuke) begin
			for(int i = 0; i < `ROB_SIZE; i++) begin
				ROB_arr[i].ARN_dest              <= #1 0;
				ROB_arr[i].PRN_dest              <= #1 0;
				ROB_arr[i].executed              <= #1 0;
				ROB_arr[i].mispredict            <= #1 0;
				ROB_arr[i].branch_actually_taken <= #1 0;
				ROB_arr[i].instr_type            <= #1 OTHER;
				ROB_arr[i].pc                    <= #1 0;
				ROB_arr[i].target_addr           <= #1 0;
			end

			head.committed <= #1 0;
			head.ARN_dest  <= #1 0;
			head.PRN_dest  <= #1 0;

			head_plus1.committed <= #1 0;
			head_plus1.ARN_dest  <= #1 0;
			head_plus1.PRN_dest  <= #1 0;

			head_branch.is_branch             <= #1 0;
			head_branch.branch_actually_taken <= #1 0;
			head_branch.mispredict            <= #1 0;
			head_branch.pc                    <= #1 0;
			head_branch.target_addr           <= #1 0;

			head_plus1_branch.is_branch             <= #1 0;
			head_plus1_branch.branch_actually_taken <= #1 0;
			head_plus1_branch.mispredict            <= #1 0;
			head_plus1_branch.pc                    <= #1 0;
			head_plus1_branch.target_addr           <= #1 0;

			full         <= #1 0;
			almost_full  <= #1 0;
			tail_index   <= #1 0;
			head_index   <= #1 0;
			count        <= #1 0;

			halt         <= #1 0;
			nuke         <= #1 0;
			fork_committed      <= #1 0;
			fork_addr    <= #1 0;
		end
		else begin
			head.committed <= #1 n_committed_0;
			head.pc        <= #1 ROB_arr[n_head_index].pc;
			head.ARN_dest  <= #1 ROB_arr[n_head_index].ARN_dest;
			head.PRN_dest  <= #1 ROB_arr[n_head_index].PRN_dest;
			
			head_plus1.committed <= #1 n_committed_1;
			head_plus1.pc        <= #1 ROB_arr[n_head_index_plus_1].pc;
			head_plus1.ARN_dest  <= #1 ROB_arr[n_head_index_plus_1].ARN_dest;
			head_plus1.PRN_dest  <= #1 ROB_arr[n_head_index_plus_1].PRN_dest;

			head_branch.is_branch             <= #1 n_is_branch_0;
			head_branch.branch_actually_taken <= #1 n_branch_actually_taken_0;
			head_branch.mispredict            <= #1 n_mispredict_0;
			head_branch.target_addr           <= #1 n_target_addr_0;
			head_branch.pc                    <= #1 ROB_arr[n_head_index].pc;

			head_plus1_branch.is_branch             <= #1 n_is_branch_1;
			head_plus1_branch.branch_actually_taken <= #1 n_branch_actually_taken_1;
			head_plus1_branch.mispredict            <= #1 n_mispredict_1;
			head_plus1_branch.target_addr           <= #1 n_target_addr_1;
			head_plus1_branch.pc                    <= #1 ROB_arr[n_head_index_plus_1].pc;

			halt         <= #1 n_halt;
			nuke         <= #1 n_nuke;
			fork_committed      <= #1 n_fork_committed;
			fork_addr    <= #1 n_fork_addr;

			full         <= #1 n_full;
			almost_full  <= #1 n_almost_full;
			tail_index   <= #1 n_tail_index;
			head_index   <= #1 n_head_index;
			count        <= #1 n_count;
			ROB_arr      <= #1 n_ROB_arr;
		end
	end
endmodule