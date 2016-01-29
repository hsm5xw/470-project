//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
`timescale 1ns/100ps

module alu(
		input [63:0] opa,
		input [63:0] opb,
		input  [4:0] func,
   
		output logic [63:0] result
	);

    // This function computes a signed less-than operation
	function signed_lt;
		input [63:0] a, b;

		if (a[63] == b[63]) 
			signed_lt = (a < b); // signs match: signed compare same as unsigned
		else
			signed_lt = a[63];   // signs differ: a is smaller if neg, larger if pos
	endfunction

	always_comb
		begin
		case (func)
			 ALU_ADDQ:   result = opa + opb;
			 ALU_SUBQ:   result = opa - opb;
			 ALU_AND:    result = opa & opb;
			 ALU_BIC:    result = opa & ~opb;
			 ALU_BIS:    result = opa | opb;
			 ALU_ORNOT:  result = opa | ~opb;
			 ALU_XOR:    result = opa ^ opb;
			 ALU_EQV:    result = opa ^ ~opb;
			 ALU_SRL:    result = opa >> opb[5:0];
			 ALU_SLL:    result = opa << opb[5:0];
			 ALU_SRA:    result = (opa >> opb[5:0]) | ({64{opa[63]}} << (64 - opb[5:0])); // arithmetic from logical shift

			//`ALU_MULQ:   result = opa * opb;	// ****************** NEED TO FIX IT !!!!!!!!!!!!!!!!!!!


			 ALU_CMPULT: result = { 63'd0, (opa < opb) };
			 ALU_CMPEQ:  result = { 63'd0, (opa == opb) };
			 ALU_CMPULE: result = { 63'd0, (opa <= opb) };
			 ALU_CMPLT:  result = { 63'd0, signed_lt(opa, opb) };
			 ALU_CMPLE:  result = { 63'd0, (signed_lt(opa, opb) || (opa == opb)) };
			default:     result = 64'hdeadbeefbaadbeef;	// here only to force
									// a combinational solution
									// a casex would be better
		endcase
	end
endmodule // alu