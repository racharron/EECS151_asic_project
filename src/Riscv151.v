`include "const.vh"

module Riscv151(
    input clk,
    input reset,

    // Memory system ports
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    input [31:0] dcache_dout,
    input [31:0] icache_dout,
    input stall,
    output [31:0] csr

);

  wire [6:0] opcode;
  wire [2:0] funct3;
  wire [4:0] rd, rs1, rs2;
  wire [6:0] funct7;
  wire [31:0] imm;
  wire csr_instr;
  wire csr_imm_instr;

  wire add_rshift_type = funct7[5];

  wire pc_select;
  wire [31:0] alu_result;

  pc_counter pc_counter(
    rst, clk,
    pc_select,
    alu_result,
    pc0
  );
  wire [31:0] pc0, pc1, pc2, pc3;
  REGISTER_R_CE#(.N(32)) pc_reg_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc1),
    .d(pc0)
  );
  REGISTER_R_CE#(.N(32)) pc_reg_2(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc2),
    .d(pc1)
  );
  REGISTER_R_CE#(.N(32)) pc_reg_3(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc3),
    .d(pc2)
  );

  assign icache_addr = next_pc;

  Decoder decoder(
    icache_dout,
    opcode,
    funct3,
    rd, rs1, rs2,
    funct7,
    imm,
    csr_instr, csr_imm_instr
  );

endmodule
