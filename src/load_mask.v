`include "Opcode.vh"

module load_mask (
  input [31:0] mem_address,
  input [31:0] mem_output,
  input [31:0] instruction,
  output [31:0] load_out
);
  reg [31:0] out_internal;
  
  wire [1:0] offset;
  assign offset = mem_address[1:0];

  wire [2:0] funct3;
  assign funct3 = instruction[14:12];

  always @(*) begin
    case (funct3)
      `FNC_LH: begin
        case (offset)
          2'b00: out_internal = { {16{ mem_output[15] }}, mem_output[15:0] };
          2'b01: out_internal = { {16{ mem_output[23] }}, mem_output[23:8] };
          2'b10, 2'b11: out_internal = { {16{ mem_output[31] }}, mem_output[31:16] };
        endcase
      end
      `FNC_LB: begin
        case (offset)
          2'b00: out_internal = { {24{ mem_output[7]  }}, mem_output[7:0] };
          2'b01: out_internal = { {24{ mem_output[15] }}, mem_output[15:8] };
          2'b10: out_internal = { {24{ mem_output[23] }}, mem_output[23:16] };
          2'b11: out_internal = { {24{ mem_output[31] }}, mem_output[31:24] };
        endcase
      end
      `FNC_LHU: begin
        case (offset)
          2'b00: out_internal = { 16'b0, mem_output[15:0] };
          2'b01: out_internal = { 16'b0, mem_output[23:8] };
          2'b10, 2'b11: out_internal = { 16'b0, mem_output[31:16] };
        endcase
      end
      `FNC_LBU: begin
        case (offset)
          2'b00: out_internal = { 24'b0, mem_output[7:0] };
          2'b01: out_internal = { 24'b0, mem_output[15:8] };
          2'b10: out_internal = { 24'b0, mem_output[23:16] };
          2'b11: out_internal = { 24'b0, mem_output[31:24] };
        endcase
      end
      `FNC_LW: out_internal = mem_output;
      default: out_internal = mem_output;
    endcase
  end

  assign load_out = out_internal;
endmodule