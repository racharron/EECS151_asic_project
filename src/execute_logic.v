`include "Opcode.vh"
/*Selects the value for alu_select to be inputted to ALU, 
and sets the selection for MUXes like ASel and BSel.*/
module execute_logic (
  input [31:0] instruction,

  input less_than,
  input equal,

  output reg [3:0] alu_select,
  output reg a_select,
  output reg b_select,

  output unsigned_compare,
  output reg nop_stall,
  output reg pc_select
);
  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [6:0] funct7;

  assign opcode = instruction[6:0];
  assign funct3 = instruction[14:12];
  assign funct7 = instruction[31:25];

  assign unsigned_compare = funct3[1];

  ALUdec decode (
    .opcode(opcode),
    .funct(funct3),
    .add_rshift_type(funct7[5]),
    .ALUop(alu_select)
  );

  always @(*) begin

    a_select = 1'b0;
    b_select = 1'b0;
    nop_stall = 1'b0;
    pc_select = 1'b0;

    //Don't need case for R type; default values/cases above are correct
    case (opcode)
      `OPC_JAL: begin
        a_select = 1'b1; //pc
        pc_select = 1'b1; //alu
        nop_stall = 1'b1; //stall
        b_select = 1'b1; //imm
      end
      `OPC_BRANCH: begin
        a_select = 1'b1; //pc
        b_select = 1'b1; //imm

        case (funct3)
          `FNC_BEQ: if (equal) begin
            pc_select = 1'b1;
            nop_stall = 1'b1;
          end 
          `FNC_BNE: if (!equal) begin
            pc_select = 1'b1;
            nop_stall = 1'b1;
          end
          `FNC_BLT, `FNC_BLTU: if (less_than) begin
            pc_select = 1'b1;
            nop_stall = 1'b1;
          end
          `FNC_BGE, `FNC_BGEU: if (!less_than) begin
            pc_select = 1'b1;
            nop_stall = 1'b1;
          end
        endcase
      end
      `OPC_ARI_ITYPE: begin
        a_select = 1'b0; //rs1
        b_select = 1'b1; //imm
      end
      `OPC_JALR: begin
        a_select = 1'b0; //rs1
        b_select = 1'b1; //imm
        pc_select = 1'b1; //alu
        nop_stall = 1'b1; //stall
      end
      `OPC_LUI: begin
        a_select = 1'b1; //pc
        b_select = 1'b1; //imm
        b_select = 1'b1;
      end
      `OPC_AUIPC: begin
        a_select = 1'b1; //pc
        b_select = 1'b1; //imm
      end
      `OPC_STORE: begin
        b_select = 1'b1;
      end
      `OPC_LOAD: begin
        b_select = 1'b1;
      end
    endcase
  end
endmodule