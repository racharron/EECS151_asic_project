`define NO_FORWARD        2'b00
`define ONE_CYCLE_FORWARD 2'b01
`define TWO_CYCLE_FORWARD 2'b10

/*EXECUTE STAGE 
ALU, Branch Comparator, Forwarding Muxes: inA, inB*/
module execute (
  input clk,

  input [31:0] instruction,

  input [31:0] rs1,
  input [31:0] rs2,  //rs2

  input [31:0] immediate,  //imm

  input [31:0] writeback,
  input [1:0] a_forward_select, //inA
  input [1:0] b_forward_select, //inB
  
  input [31:0] pc,

  input a_select,
  input b_select,

  input unsigned_compare,
  output less_than,
  output equal,
  
  input [3:0] alu_select,
  output [31:0] alu_result,

  output [31:0] mem_write,
  output reg [31:0] csr_out
);
  wire [31:0] old_writeback;

  reg [31:0] tohost_csr = 32'b0;

  REGISTER #(.N(32)) wb_reg (
    .clk(clk),
    .d(writeback),
    .q(old_writeback)
  );

  reg [31:0] forwarded_rs1;
  reg [31:0] forwarded_rs2;
  assign mem_write = forwarded_rs2;
  
  //Forwarding MUXes 
  always @(*) begin
    case (a_forward_select)
      `NO_FORWARD: forwarded_rs1 = rs1;
      `ONE_CYCLE_FORWARD: forwarded_rs1 = writeback;
      `TWO_CYCLE_FORWARD: forwarded_rs1 = old_writeback;
      default: forwarded_rs1 = rs1;
    endcase

    case (b_forward_select)
        `NO_FORWARD: forwarded_rs2 = rs2;
        `ONE_CYCLE_FORWARD: forwarded_rs2 = writeback;
        `TWO_CYCLE_FORWARD: forwarded_rs2 = old_writeback;
        default: forwarded_rs2 = rs2;
    endcase

    if (instruction[6:0] == `OPC_CSR) begin
      if (instruction[14]) tohost_csr = immediate; // CSRRWI
      else tohost_csr = forwarded_rs1;  
    end
  end
  assign csr_out = tohost_csr;

  branch_comp compare (
    .unsign(unsigned_compare),
    .A(forwarded_rs1),
    .B(forwarded_rs2),

    .less_than(less_than),
    .br_equal(equal)
  );

  wire [31:0] ALU_A;
  wire [31:0] ALU_B;

  //Asel and Bsel Muxes
  assign ALU_A = a_select ? pc : forwarded_rs1;
  assign ALU_B = b_select ? immediate : forwarded_rs2;

  ALU alu (
    .A(ALU_A),
    .B(ALU_B),
    .Out(alu_result),
    .ALUop(alu_select)
  );

  
endmodule