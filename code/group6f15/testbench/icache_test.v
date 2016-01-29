`timescale 1ns/100ps

module testbench();
	logic        clock;
	logic        reset;
	logic  [3:0] Imem2proc_response;
	logic [63:0] Imem2proc_data;
	logic  [3:0] Imem2proc_tag;

	logic [63:0] proc2Icache_addr;
	logic [63:0] cachemem_data;
	logic        cachemem_valid;

	logic  [1:0] proc2Imem_command;
	logic [63:0] proc2Imem_addr;

	logic [63:0] Icache_data_out;     // value is memory[proc2Icache_addr]
	logic        Icache_valid_out;    // when this is high

	logic  [4:0] current_index;
	logic  [7:0] current_tag;
	logic  [4:0] last_index;
	logic  [7:0] last_tag;
	logic        data_write_enable;

	icache ic (
		.clock             (clock),
		.reset             (reset),
		.Imem2proc_response(Imem2proc_response),
		.Imem2proc_data    (Imem2proc_data),
		.Imem2proc_tag     (Imem2proc_tag),
		.proc2Icache_addr  (proc2Icache_addr),
		.cachemem_data     (cachemem_data),
		.cachemem_valid    (cachemem_valid),
		.proc2Imem_command (proc2Imem_command),
		.proc2Imem_addr    (proc2Imem_addr),
		.Icache_data_out   (Icache_data_out),
		.Icache_valid_out  (Icache_valid_out),
		.current_index     (current_index),
		.current_tag       (current_tag),
		.last_index        (last_index),
		.last_tag          (last_tag),
		.data_write_enable (data_write_enable)
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

	task reset_inputs;
		begin
			@(negedge clock);
			reset = 1;
			@(negedge clock);
			reset = 0;
			@(negedge clock);
		end
	endtask

	initial 
	begin
		clock = 0;


		$display("@@@PASSED!");
		$finish;
	end // initial
endmodule
