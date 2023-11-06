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

  /// Fed into IMEM.
  wire [31:0] next_pc;
  /// This connects the PC register to the decode-read stage PC buffer.
  /// It allows delaying PC enough for the instruction to catch up to it.
  wire [31:0] pc0;
  /// The value of PC in the decode-read stage.
  wire [31:0] pc1;
  /// The value of PC in the execute stage.
  wire [31:0] pc2;
  /// The value of PC in the writeback stage.
  wire [31:0] pc3;

  /// An interstage signal that indicates that the preceding stages
  /// should become bubbles.
  wire bubble;
  
  /// The register file write enables for each stage of the pipeline.
  wire reg_we_1, reg_we_2, reg_we_3;
  /// The memory write enables for each stage of the pipeline.
  wire mem_we_1, mem_we_2, mem_we_3;
  /// The memory read request for each stage of the pipeline.
  wire mem_rr_1, mem_rr_2, mem_rr_3;
  
  /// The rd index for each stage of the pipeline.
  wire [4:0] rd_1, rd_2, rd_3;
  /// The rs1 index for each stage of the pipeline.
  wire [4:0] rs1_1, rs1_2, rs1_3;
  /// The rs2 index for each stage of the pipeline.
  wire [4:0] rs2_1, rs2_2;

  /// The A and B values from the registers for each stage of the pipeline.
  wire [31:0] reg_A_1, reg_A_2, reg_B_1, reg_B_2;

  /// The generated immediates across the first two stages of the pipeline.
  wire [31:0] imm_1, imm_2;

  /// The value that is written to the register file
  wire [31:0] writeback;

  wire [3:0] alu_op_1, alu_op_2;
  wire add_rshift_type_1, add_rshift_type_2;
  wire shift_imm_1, shift_imm_2;
  wire a_sel_1, a_sel_2, b_sel_1, b_sel_2;

  wire csr_write_1, csr_write_2, csr_write_3;
  wire csr_imm_1, csr_imm_2, csr_imm_3;

  /// This holds the PC value used for getting the next instruction.  
  /// It has to be delayed due to memory being synchronous.
  ProgramCounter pc(
    reset, clk,
    pc_select,
    alu_result,
    pc0, next_pc
  );
  /// The output of this is the value of PC in the decode-read stage.
  /// Since IMEM is synchronous, we have to wait a clock cycle to get
  /// the instruction, which is why this is seperate from pc.
  REGISTER_R_CE#(.N(32)) pc_0_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc1),
    .d(pc0)
  );
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_1_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc2),
    .d(pc1)
  );
  /// The output of this is the value of PC in the writeback stage.
  REGISTER_R_CE#(.N(32)) pc_2_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc3),
    .d(pc2)
  );

  REGISTER_R_CE#(.N(32)) reg_A_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(reg_A_2),
    .d(reg_A_1)
  );
  REGISTER_R_CE#(.N(32)) reg_B_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(reg_B_2),
    .d(reg_B_1)
  );

  REGISTER_R_CE#(.N(5)) alu_ctrl_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q({alu_op_2, add_rshift_type_2}),
    .d({alu_op_1, add_rshift_type_1})
  );

  REGISTER_R_CE shift_imm_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(shift_imm_2),
    .d(shift_imm_1)
  );

  REGISTER_R_CE a_sel_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(a_sel_2),
    .d(a_sel_1)
  );

  REGISTER_R_CE b_sel_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(b_sel_2),
    .d(b_sel_1)
  );

  REGISTER_R_CE reg_we_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(reg_we_2),
    .d(reg_we_1)
  );

  REGISTER_R_CE mem_we_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(mem_we_2),
    .d(mem_we_1)
  );

  REGISTER_R_CE mem_rr_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(mem_rr_2),
    .d(mem_rr_1)
  );
  
  REGISTER_R_CE#(.N(5)) rd_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(rd_2),
    .d(rd_1)
  );
  
  REGISTER_R_CE#(.N(5)) rs1_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(rs1_2),
    .d(rs1_1)
  );
  
  REGISTER_R_CE#(.N(5)) rs2_buffer_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(rs2_2),
    .d(rs2_1)
  );

  REGISTER_R_CE#(.N(32)) imm_buffer(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(imm_2),
    .d(imm_1)
  );

  assign icache_addr = next_pc;

  DecodeRead stage1(
      .clk(clk), .stall(stall), .bubble(bubble),
      .instr(icache_dout),
      .we(reg_we_3),
      .wa(rd_3),
      .wd(writeback),

      .ra(reg_A_1), .rb(reg_B_1),
      .alu_op(alu_op_1),
      .add_rshift_type(add_rshift_type_1),
      .shift_imm(shift_imm_1),
      .a_sel(a_sel_1), .b_sel(b_sel_1),
      .reg_we(reg_we_1), .mem_we(mem_we_1), .mem_rr(mem_rr_1),
      .rd(rd_1), .rs1(rs1_1), .rs2_shamt(rs2_1),
      .imm(imm_1),
      .csr_write(csr_write_1), .csr_imm(csr_imm_1)
  );

endmodule
