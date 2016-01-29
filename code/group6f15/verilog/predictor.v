//////////////////////////////////////////////////////
// Module: Branch predictor                         //
//                                                  //
// Description: Will predict if a branch will       //
// be predicted or not and will branch to a         //
// a predicted adress. This will require a local    //
// predictor and a branch buffer table              //
//                                                  //
//////////////////////////////////////////////////////
`timescale 1ns/100ps

module BTB(

    // Inputs
    input clock,
    input reset,
    input committed_is_branch_0,    // only if committed inst. is branch is the BTB updated
    input committed_is_branch_1,
    input branch_taken_ROB_0,       // only if committed inst. is a taken branch is the BTB updated
    input branch_taken_ROB_1,       // from ROB
    input [`ADDR_BITS-1:0] pc_0,    // from IF
    input [`ADDR_BITS-1:0] pc_1,    // from IF
    input [`ADDR_BITS-1:0] branch_target_ROB_0, // from ROB
    input [`ADDR_BITS-1:0] branch_target_ROB_1, // from ROB
    input [`ADDR_BITS-1:0] branch_pc_ROB_0, // from ROB
    input [`ADDR_BITS-1:0] branch_pc_ROB_1, // from ROB

    // Outputs
    output logic [`ADDR_BITS-1:0] pred_target_add_0, // If the two instructions are both taken branches, output 2 addresses
    output logic [`ADDR_BITS-1:0] pred_target_add_1,
    output logic branch_in_BTB_0,   // If the branch is found in the BTB, use the predicted address given above (only if predicted taken)
    output logic branch_in_BTB_1
    );
    
    BTB_DATA [`BTB_SIZE-1:0] BTB_arr;
    BTB_DATA [`BTB_SIZE-1:0] n_BTB_arr;
    logic [`BTB_BITS-1:0] pc_index_0, pc_index_1, pc_index_ROB_0, pc_index_ROB_1;

    // Discard the last 2 bits of the PC, and use the next `BTB_BITS (4 at the moment) to index the BTB
    // First two are used to index the BTB to make a prediction
    // Last two are used to index the BTB to update when a branch commits
    assign pc_index_0       = pc_0[`BTB_BITS+1:2];
    assign pc_index_1       = pc_1[`BTB_BITS+1:2]; 
    assign pc_index_ROB_0   = branch_pc_ROB_0[`BTB_BITS+1:2];
    assign pc_index_ROB_1   = branch_pc_ROB_1[`BTB_BITS+1:2];
    
    always_comb begin

        // Assign current values of BTB to next BTB's values in case not all of them are modified

        /*for(int j=0; j< `BTB_SIZE; j++) begin
            n_BTB_arr[j].valid           = BTB_arr[j].valid;
            n_BTB_arr[j].pc              = BTB_arr[j].pc; 
            n_BTB_arr[j].pred_target_add = BTB_arr[j].pred_target_add; 
        end */
        n_BTB_arr = BTB_arr;

        // Update the BTB with newly committed branches //////////////////////////////////////////
        // If the committed instruction is a taken branch, update the BTB
        if(branch_taken_ROB_0 && committed_is_branch_0) begin
            n_BTB_arr[pc_index_ROB_0].valid              = 1'b1;
            n_BTB_arr[pc_index_ROB_0].pc                 = branch_pc_ROB_0;
            n_BTB_arr[pc_index_ROB_0].pred_target_add    = branch_target_ROB_0;
        end

        if(branch_taken_ROB_1 && committed_is_branch_1) begin
            n_BTB_arr[pc_index_ROB_1].valid              = 1'b1;
            n_BTB_arr[pc_index_ROB_1].pc                 = branch_pc_ROB_1;
            n_BTB_arr[pc_index_ROB_1].pred_target_add    = branch_target_ROB_1;
        end

        // Set outputs of BTB (to IF) ////////////////////////////////////////////////////////////
        // If the BTB entry is valid, the branch instruction was predicted taken, and the instruction is valid, use the BTB's address.
        // Otherwise, predict the branch as NT and assign a dummy address to the output
        // Always pass along address found in BTB (only use it when the branch is predicted Taken)
        pred_target_add_0   = BTB_arr[pc_index_0].pred_target_add;
        pred_target_add_1   = BTB_arr[pc_index_1].pred_target_add;
        branch_in_BTB_0     = BTB_arr[pc_index_0].valid && (BTB_arr[pc_index_0].pc==pc_0);
        branch_in_BTB_1     = BTB_arr[pc_index_1].valid && (BTB_arr[pc_index_1].pc==pc_1);
        // Ignores aliasing: if entry is valid, pass along the address (even if it is for a different branch)
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock)
    begin
        if(reset) begin            
            for(int j=0; j<`BTB_SIZE; j++) begin
                BTB_arr[j].valid            <= #1 1'b0;
                BTB_arr[j].pc               <= #1 `ADDR_BITS'hDEAD_0000_DEAD_0000;
                BTB_arr[j].pred_target_add  <= #1 `ADDR_BITS'hDEAD_0000_DADA_0000;
            end
        end else begin
            /*for(int j=0; j<`BTB_SIZE; j++) begin
                BTB_arr[j].valid            <= #1 n_BTB_arr[j].valid;    
                BTB_arr[j].pc               <= #1 n_BTB_arr[j].pc; 
                BTB_arr[j].pred_target_add  <= #1 n_BTB_arr[j].pred_target_add; 
            end */
            BTB_arr <= #1 n_BTB_arr;
        end
    end

endmodule 

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module Local_History(

    // Inputs
    input clock,
    input reset,
    input committed_is_branch_0, // from ROB
    input committed_is_branch_1, // from ROB
    input [`ADDR_BITS-1:0] pc_0, // from IF
    input [`ADDR_BITS-1:0] pc_1, // from IF
    input [`ADDR_BITS-1:0] branch_pc_ROB_0,
    input [`ADDR_BITS-1:0] branch_pc_ROB_1,
    input branch_taken_0,        // from ROB
    input branch_taken_1,        // from ROB

    // Outputs
    output logic branch_pred_0,
    output logic branch_pred_1
    );

    //sets up our history and pattern table that will work together to make a prediction
    logic [`HISTORY_TABLE_SIZE-1:0] [`BRANCH_HISTORY_BITS-1:0] branch_history, n_branch_history;
    logic [`PATTERN_TABLE_SIZE-1:0] [1:0] pattern_history, n_pattern_history;
    logic [`BRANCH_HISTORY_BITS-1:0] pred_index_0, pred_index_1, pred_in_update_0, pred_in_update_1;
 
    logic [`BRANCH_PC_BITS-1:0] pc_index_0; //these will hold the part of the pc that will use to index in the history table
    logic [`BRANCH_PC_BITS-1:0] pc_index_1;
    logic [`BRANCH_PC_BITS-1:0] pc_index_ROB_0;
    logic [`BRANCH_PC_BITS-1:0] pc_index_ROB_1;

    logic n_branch_pred_0, n_branch_pred_1;   
    
    always_comb begin
        n_branch_history = branch_history;
        n_pattern_history = pattern_history;

        pc_index_ROB_0 = branch_pc_ROB_0[`BRANCH_PC_BITS+1:2];
        pc_index_ROB_1 = branch_pc_ROB_1[`BRANCH_PC_BITS+1:2];

        // Update predictor with recently committed branches ///////////////////////////////////////////

        // Update the history of this branch (shift left so lsb bit is most recent branch's direction)
        // Update the counter depending on whether the branch was taken or not (doesn't depend on mispredict)
        if(committed_is_branch_0) begin
            
            n_branch_history[pc_index_ROB_0] = {branch_history[pc_index_ROB_0][`BRANCH_HISTORY_BITS-2:0], branch_taken_0};
            pred_in_update_0 = branch_history[pc_index_ROB_0];

            case(pattern_history[pred_in_update_0])
                2'b00:  n_pattern_history[pred_in_update_0] = branch_taken_0 ? 2'b01 : 2'b00;
                2'b01:  n_pattern_history[pred_in_update_0] = branch_taken_0 ? 2'b10 : 2'b00;
                2'b10:  n_pattern_history[pred_in_update_0] = branch_taken_0 ? 2'b11 : 2'b01;
                2'b11:  n_pattern_history[pred_in_update_0] = branch_taken_0 ? 2'b11 : 2'b10;
            endcase
        end else begin
            pred_in_update_0 = 0;
        end

        // Update the history of this branch (shift left so lsb bit is most recent branch's direction)
        // Update the counter depending on whether the branch was taken or not (doesn't depend on mispredict)
        if(committed_is_branch_1) begin

            
            n_branch_history[pc_index_ROB_1] = {branch_history[pc_index_ROB_1][`BRANCH_HISTORY_BITS-2:0], branch_taken_1};
            pred_in_update_1 = branch_history[pc_index_ROB_1];

            case(pattern_history[pred_in_update_1])
                2'b00:  n_pattern_history[pred_in_update_1] = branch_taken_1 ? 2'b01 : 2'b00;
                2'b01:  n_pattern_history[pred_in_update_1] = branch_taken_1 ? 2'b10 : 2'b00;
                2'b10:  n_pattern_history[pred_in_update_1] = branch_taken_1 ? 2'b11 : 2'b01;
                2'b11:  n_pattern_history[pred_in_update_1] = branch_taken_1 ? 2'b11 : 2'b10;
            endcase
        end else begin
            pred_in_update_1 = 0;
        end

        // Prediction for current pc from IF
        pc_index_0 = pc_0[`BRANCH_PC_BITS+1:2];
        pc_index_1 = pc_1[`BRANCH_PC_BITS+1:2];

        // Need to index into the current history to make a prediction for next time
        pred_index_0 = n_branch_history[pc_index_0];
        pred_index_1 = n_branch_history[pc_index_1];

        // Make a prediction based on the history in the current cycle
        branch_pred_0 =   pattern_history[pred_index_0] == 2'b00 ? 1'b0 : 
                          pattern_history[pred_index_0] == 2'b01 ? 1'b0 : 
                          pattern_history[pred_index_0] == 2'b10 ? 1'b1 : 
                          pattern_history[pred_index_0] == 2'b11 ? 1'b1 : 1'b0;

        branch_pred_1 = pattern_history[pred_index_1] == 2'b00 ? 1'b0 : 
                          pattern_history[pred_index_1] == 2'b01 ? 1'b0 : 
                          pattern_history[pred_index_1] == 2'b10 ? 1'b1 : 
                          pattern_history[pred_index_1] == 2'b11 ? 1'b1 : 1'b0;
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin

            for(int i=0; i<`HISTORY_TABLE_SIZE; i++) 
                branch_history[i] <= #1 `BRANCH_HISTORY_BITS'b0;            
            for(int j=0; j<`PATTERN_TABLE_SIZE; j++) 
                pattern_history[j] <= #1 2'b01;

            /*branch_pred_0 <= #1 1'b0;
            branch_pred_1 <= #1 1'b0;*/
                                      
        end else begin
            branch_history  <= #1 n_branch_history; // these are arrays
            pattern_history <= #1 n_pattern_history;
            /*branch_pred_0   <= #1 n_branch_pred_0;
            branch_pred_1   <= #1 n_branch_pred_1;*/
        end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module predictor( // top level module (uses BTB and Local_history modules)

    // Inputs
    input              clock,
    input              reset,
    input [1:0] [63:0] if_pc,        // has pc_0, pc_1 inst_valid_0, inst_valid_1
    ROB_PRED rob_data_in,  //has committed_is_branch, branch_taken, ROB_branch_pc, branch_target

    // Outputs
    output PRED_IF pred_data_out// has branch_pred, is_branch, pred_target_add
    );      

    // BTB that holds the target address of branches 
    BTB BTB_0 (

        // Inputs
        .clock(clock),
        .reset(reset),
        .committed_is_branch_0(rob_data_in.committed_is_branch_0),
        .committed_is_branch_1(rob_data_in.committed_is_branch_1),
        .branch_taken_ROB_0(rob_data_in.branch_taken_0),
        .branch_taken_ROB_1(rob_data_in.branch_taken_1),
        .pc_0(if_pc[0]),
        .pc_1(if_pc[1]),
        .branch_target_ROB_0(rob_data_in.branch_target_0),
        .branch_target_ROB_1(rob_data_in.branch_target_1),
        .branch_pc_ROB_0(rob_data_in.branch_pc_ROB_0),
        .branch_pc_ROB_1(rob_data_in.branch_pc_ROB_1),

        // Outputs
        .pred_target_add_0(pred_data_out.pred_target_add_0),
        .pred_target_add_1(pred_data_out.pred_target_add_1),
        .branch_in_BTB_0(pred_data_out.branch_in_BTB_0),
        .branch_in_BTB_1(pred_data_out.branch_in_BTB_1)
    );

    // Local history pred that predicts the direction of a branch (T or NT)
    Local_History LH_0 (

        // Inputs
        .clock(clock),
        .reset(reset),
        .committed_is_branch_0(rob_data_in.committed_is_branch_0),
        .committed_is_branch_1(rob_data_in.committed_is_branch_1),
        .pc_0(if_pc[0]),
        .pc_1(if_pc[1]),
        .branch_pc_ROB_0(rob_data_in.branch_pc_ROB_0),
        .branch_pc_ROB_1(rob_data_in.branch_pc_ROB_1),
        .branch_taken_0(rob_data_in.branch_taken_0),
        .branch_taken_1(rob_data_in.branch_taken_1),

        // Outputs
        .branch_pred_0(pred_data_out.branch_pred_0),
        .branch_pred_1(pred_data_out.branch_pred_1)
    );

endmodule