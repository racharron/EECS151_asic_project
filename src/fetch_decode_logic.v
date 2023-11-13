`include "Opcode.vh"

module fetch_decode_logic (
  input [31:0] instruction,
  output reg [2:0] immediate_select
);
  // Decodes the instruction to output the appropriate imm_select for the immediate generator.
  always @(*) begin
    case (instruction[6:0])
      `OPC_JAL: immediate_select = `IMM_J;
      `OPC_STORE: immediate_select = `IMM_S;
      `OPC_BRANCH: immediate_select = `IMM_B;
      `OPC_CSR: immediate_select = `IMM_CSR;
      `OPC_LUI, `OPC_AUIPC: immediate_select = `IMM_U;
      `OPC_ARI_ITYPE: immediate_select = `IMM_I;
      default: immediate_select = `IMM_I;
    endcase
  end
endmodule