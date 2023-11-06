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

  wire bubble;

  /// The register file write enables for each stage of the pipeline.
  wire reg_we_1, reg_we_2, reg_we_3;
  /// The memory write enables for each stage of the pipeline.
  wire mem_we_1, mem_we_2, mem_we_3;
  /// The memory read request for each stage of the pipeline.
  wire mem_rr_1, mem_rr_2, mem_rr_3;

  /// This holds the PC value used for getting the next instruction.  
  /// It has to be delayed due to memory being synchronous.
  ProgramCounter pc(
    rst, clk,
    pc_select,
    alu_result,
    pc0, next_pc
  );
  /// The output of this is the value of PC in the decode-read stage.
  /// Since IMEM is synchronous, we have to wait a clock cycle to get
  /// the instruction, which is why this is seperate from pc.
  REGISTER_R_CE#(.N(32)) pc_reg_1(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc1),
    .d(pc0)
  );
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_reg_2(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc2),
    .d(pc1)
  );
  /// The output of this is the value of PC in the writeback stage.
  REGISTER_R_CE#(.N(32)) pc_reg_3(
    .clk(clk), .rst(reset),
    .ce(!stall),
    .q(pc3),
    .d(pc2)
  );

  assign icache_addr = next_pc;

  DecodeRead stage1(
      .clk(clk), .stall(stall), .bubble(bubble),
      .instr(icache_dout),
      input we,
      input [4:0] wa,
      input [31:0] wd,

      output [31:0] ra, rb,
      output reg [3:0] alu_op,
      output reg add_rshift_type,
      output reg a_sel, b_sel,
      output reg reg_we, mem_we, mem_re,
      output reg [2:0] funct3,
      output reg [4:0] rd, rs1, rs2_shamt,
      output reg [31:0] imm,
      output reg csr_instr, csr_imm_instr,
      output reg exec
  );

endmodule
