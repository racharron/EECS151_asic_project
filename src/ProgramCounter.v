module ProgramCounter (
	input clk, reset, stall,
	input pc_select,
	input [31:0] alu_result,
	output [31:0] pc,
	output [31:0] next_pc
);
	wire [31:0] current_pc;
	assign next_pc = (pc_select & !reset) ? {alu_result[31:2], 2'b00} : pc + 32'd4;

	REGISTER_R #(
		.N(32),
		.INIT(`PC_RESET - 32'd4)
	) pc_register (
		.q(current_pc),
		.d(stall ? current_pc : next_pc),
		.clk(clk),
		.rst(reset)
	);

	assign pc = current_pc;
endmodule