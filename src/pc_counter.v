`include "const.vh"
module pc_counter (
	input rst,
	input clk,
	input pc_select,
	input [31:0] alu_result,
	output [31:0] pc
);
	wire [31:0] current_pc;
	wire [31:0] next_pc;
	assign next_pc = pc_select ? alu_result : pc + 32'd4;

	REGISTER_R #(
		.N(32),
		.INIT(`PC_RESET)
	) pc (
		.q(current_pc),
		.d(next_pc),
		.clk(clk),
		.rst(rst)
	);

	assign pc = current_pc;
endmodule