// cachemem32x64

`timescale 1ns/100ps

module icachemem (
	input clock, reset, wr1_en,
	input [1:0] [4:0] rd1_idx,
	input [1:0] [7:0] rd1_tag,
	input  [4:0] wr1_idx,
	input  [7:0] wr1_tag,
	input [63:0] wr1_data, 
	input  [1:0] changed_addr,

	output logic [31:0]      valids,
	output logic [31:0] [63:0] data,
	output logic [31:0]  [8:0] tags,
	output logic [1:0] [63:0] rd1_data,
	output logic [1:0] rd1_valid
);
	logic      [15:0] lru, n_lru;

	logic [1:0] [3:0] rd1_set;
	logic       [3:0] wr1_set;

	logic       [8:0] actual_wr1_tag;
	logic [1:0] [8:0] actual_rd1_tag;
	
	logic       [4:0] actual_wr1_idx;

	always_comb begin
		n_lru = lru;

		for(int j=0; j<2; j++) begin
			actual_rd1_tag[j] = {rd1_tag[j], rd1_idx[j][4]};
			rd1_set[j]        = rd1_idx[j][3:0];
			rd1_valid[j]      = 0;
			rd1_data[j]       = 0;

			if(valids[{rd1_set[j], 1'b0}] && (tags[{rd1_set[j], 1'b0}] == actual_rd1_tag[j])) begin
				rd1_valid[j]      = 1;
				rd1_data[j]       = data[{rd1_set[j], 1'b0}];
				if(changed_addr[j])
					n_lru[rd1_set[j]] = 1;
			end
			else if(valids[{rd1_set[j], 1'b1}] && (tags[{rd1_set[j], 1'b1}] == actual_rd1_tag[j])) begin
				rd1_valid[j]      = 1;
				rd1_data[j]       = data[{rd1_set[j], 1'b1}];
				if(changed_addr[j])
					n_lru[rd1_set[j]] = 0;
			end
		end

		actual_wr1_idx = 0;
		actual_wr1_tag = 0;
		wr1_set        = 0;

		if(wr1_en) begin
			wr1_set        = wr1_idx[3:0];
			actual_wr1_tag = {wr1_tag, wr1_idx[4]};
			actual_wr1_idx = {wr1_set, n_lru[wr1_set]};
			n_lru[wr1_set] = !n_lru[wr1_set];
		end
	end

	always_ff @(posedge clock) begin
		if(reset) begin
			valids <= `SD 31'b0;
			lru    <= `SD 0;
		
		end else begin
			lru    <= `SD n_lru;
			if(wr1_en) 
				valids[actual_wr1_idx] <= `SD 1;
		end
	end

	always_ff @(posedge clock) begin
		if(wr1_en) begin
			data[actual_wr1_idx] <= `SD wr1_data;
			tags[actual_wr1_idx] <= `SD actual_wr1_tag;
		end
	end
endmodule
