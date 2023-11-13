`define NO_FORWARD        2'b00
`define ONE_CYCLE_FORWARD 2'b01
`define TWO_CYCLE_FORWARD 2'b10
`include "Opcode.vh"
module forwarding_logic(
  input clk,

  input [31:0] fd_instruction, //fetch/decode instruction
  input [31:0] x_instruction, //execute instruction
  input [31:0] m_instruction, //memory instruction

  output [1:0] a_forward_select,
  output [1:0] b_forward_select
);
  reg [1:0] a_forward_select_internal;
  reg [1:0] b_forward_select_internal;

  //Registers for piplining forwarding outputs
  REGISTER #(.N(2)) a_forward (
    .clk(clk),
    .d(a_forward_select_internal),
    .q(a_forward_select)
  );

  REGISTER #(.N(2)) b_forward (
    .clk(clk),
    .d(b_forward_select_internal),
    .q(b_forward_select)
  );

  wire [6:0] m_inst_opcode;
  assign m_inst_opcode = m_instruction[6:0];

  wire [6:0] x_inst_opcode;
  assign x_inst_opcode = x_instruction[6:0];

  wire [4:0] m_inst_rd, x_inst_rd, x_inst_rs1, x_inst_rs2, fd_inst_rs1, fd_inst_rs2;
  assign m_inst_rd = m_instruction[11:7];
  assign x_inst_rd = x_instruction[11:7];
  assign x_inst_rs1 = x_instruction[19:15];
  assign x_inst_rs2 = x_instruction[24:20];
  assign fd_inst_rs1 = fd_instruction[19:15];
  assign fd_inst_rs2 = fd_instruction[24:20];

  wire two_cycle_hazard;
  wire one_cycle_hazard;

  assign two_cycle_hazard = !(m_inst_opcode[6:2] == `OPC_BRANCH_5 || m_inst_opcode[6:2] == `OPC_STORE_5);
  assign one_cycle_hazard = !(x_inst_opcode[6:2] == `OPC_BRANCH_5 || x_inst_opcode[6:2] == `OPC_STORE_5);
  always @(*) begin
    case ({two_cycle_hazard, one_cycle_hazard})
      2'b11: begin
        a_forward_select_internal = (x_inst_rd != 5'b0 && x_inst_rd == fd_inst_rs1) ? `ONE_CYCLE_FORWARD : ((m_inst_rd != 5'b0 && m_inst_rd == fd_inst_rs1) ? `TWO_CYCLE_FORWARD : `NO_FORWARD);
        b_forward_select_internal = (x_inst_rd != 5'b0 && x_inst_rd == fd_inst_rs2) ? `ONE_CYCLE_FORWARD : ((m_inst_rd != 5'b0 && m_inst_rd == fd_inst_rs2) ? `TWO_CYCLE_FORWARD : `NO_FORWARD);
      end
      2'b10: begin
        a_forward_select_internal = (m_inst_rd != 5'b0 && m_inst_rd == fd_inst_rs1) ? `TWO_CYCLE_FORWARD : `NO_FORWARD;
        b_forward_select_internal = (m_inst_rd != 5'b0 && m_inst_rd == fd_inst_rs2) ? `TWO_CYCLE_FORWARD : `NO_FORWARD;
      end
      2'b01: begin
        a_forward_select_internal = (x_inst_rd != 5'b0 && x_inst_rd == fd_inst_rs1) ? `ONE_CYCLE_FORWARD : `NO_FORWARD;
        b_forward_select_internal = (x_inst_rd != 5'b0 && x_inst_rd == fd_inst_rs2) ? `ONE_CYCLE_FORWARD : `NO_FORWARD;
      end
      2'b00: begin
        a_forward_select_internal = `NO_FORWARD;
        b_forward_select_internal = `NO_FORWARD;
      end
    endcase
  end
endmodule
