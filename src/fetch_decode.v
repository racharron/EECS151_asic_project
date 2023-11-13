`include "const.vh"
module fetch_decode #(
  parameter IMEM_AWIDTH = 32,
  parameter RESET_PC = `PC_RESET
)(
  input clk,
  input rst,

  output [IMEM_AWIDTH-1:0] imem_addr,
  input [31:0] imem_inst,

  input pc_select,
  input [31:0] alu_result,
  output [31:0] pc_out,

  input [2:0] immediate_select,

  output [31:0] instruction_out,
  output [31:0] immediate_out
);

  wire [31:0] pc;
  wire [31:0] next_pc;
  wire [31:0] instruction;

  ProgramCounter pc_module (
    .rst(rst),
    .clk(clk),

    .pc_select(pc_select),
    .alu_result(alu_result),
    .pc(pc),
    .next_pc(next_pc)
  );

  assign imem_addr = rst ? RESET_PC : next_pc;

  assign instruction = imem_inst;

  immediate_gen imm_gen (
    .immediate_select(immediate_select),
    .instruction(instruction),
    .imm_out(immediate_out)
  );

  assign instruction_out = instruction;
  assign pc_out = pc;

endmodule