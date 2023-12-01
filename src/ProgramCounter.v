module ProgramCounter (
	input clk, reset, stall,
	input pc_select,
	input [31:0] alu_result,
	output [31:0] pc,
	output [31:0] next_pc
);
	wire [31:0] current_pc;
	assign next_pc = stall ? pc : (pc_select & !reset) ? {alu_result[31:2], 2'b00} : pc + 32'd4;

	REGISTER_R_CE #(
		.N(32),
		.INIT(`PC_RESET - 32'd4)
	) pc_register (
		.q(current_pc),
		.d(next_pc),
		.clk(clk),
		.rst(reset),
		.ce(!stall)
	);

	assign pc = current_pc;

	///	Bear in mind that next_pc is what gets exposed, and is effectively the PC.
	PC_resets_correctly:
	assert property (
		///	At the very beginning, stall is erroneously true
		@(posedge clk) disable iff (stall) reset |=> next_pc == 32'h00002000
	) 
	else $error("PC reset to %h", $sampled(next_pc));

endmodule
