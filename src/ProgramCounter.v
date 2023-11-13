module ProgramCounter (
	input rst,
	input clk,
	input pc_select,
	input [31:0] alu_result,
	output [31:0] pc,
	output [31:0] next_pc
);
	wire [31:0] current_pc;
	wire [31:0] next_pc_internal;
	assign next_pc_internal = pc_select ? alu_result : current_pc + 32'd4;

	REGISTER_R #(
		.N(32),
		.INIT(`PC_RESET)
	) pc_address (
		.q(current_pc),
		.d(next_pc_internal),
		.clk(clk),
		.rst(rst)
	);

	assign pc = current_pc;
	assign next_pc = next_pc_internal;
endmodule