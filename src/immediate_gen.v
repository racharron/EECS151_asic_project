`define IMM_I   3'b000
`define IMM_S   3'b001
`define IMM_B   3'b010
`define IMM_U   3'b011
`define IMM_J   3'b100
`define IMM_CSR 3'b110

module immediate_gen (
    input [2:0] immediate_select,
    input [31:0] instruction,
    output [31:0] imm_out
);
  reg [31:0] out_internal;

  always @(*) begin
    case (immediate_select)
      `IMM_I: out_internal = { {20{ instruction[31] }}, instruction[31:20] };
      `IMM_S: out_internal = { {20{ instruction[31] }}, instruction[31:25], instruction[11:7] };
      `IMM_B: out_internal = { {19{ instruction[31] }}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
      `IMM_U: out_internal = { instruction[31:12], 12'b0 };
      `IMM_J: out_internal = { {11{ instruction[31] }}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
      `IMM_CSR: out_internal = { 27'b0, instruction[19:15] };
      default: out_internal = 32'b0; // avoid latch synthesis
    endcase
  end

  assign imm_out = out_internal;
endmodule