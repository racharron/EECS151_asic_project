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

  wire [31:0] instruction;
  wire [2:0] funct3_2, funct3_3;
  wire [4:0] rd, rs1, rs2;
  wire [31:0] imm;
  wire csr_instr;
  wire csr_imm_instr;

  wire pc_select;
  wire [31:0] alu_result;

  /// Fed into IMEM.
  wire [31:0] next_pc;
  /// This connects the PC register to the decode-read stage PC buffer.
  /// It allows delaying PC enough for the instruction to catch up to it.
  wire [31:0] pc_0;
  /// The value of PC in the decode-read stage.
  wire [31:0] pc_1;
  /// The value of PC in the execute stage.
  wire [31:0] pc_2;
  /// The value of PC in the writeback stage.
  wire [31:0] pc_3;

  /// Signals indicating if this instruction should cause a jump.
  /// jump_3 is also the bubble signal.
  wire jump_2, jump_3;
  
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
  wire [31:0] imm_2;

  /// The value that is written to the register file
  wire [31:0] writeback;

  wire [3:0] alu_op_2;
  wire a_sel_2, b_sel_2;
  wire is_jump_2, jump_conditional_2;

  wire csr_write_2, csr_write_3;

  wire [31:0] alu_result_2, alu_result_3;
  wire [31:0] store_data_2, store_data_3;

  reg branch_delay;
  wire bubble;
  /// Pause indicates that stage 3 is beginning a read, and everything should temporarily halt.
  /// Internal stall is a synonym for stall | pause
  wire pause, internal_stall;

  assign instruction = icache_dout;
  assign dcache_re = mem_rr_3;
  assign icache_re = 1'b1;
  assign internal_stall = stall | pause;

  /// This holds the PC value used for getting the next instruction.  
  /// It has to be delayed due to memory being synchronous.
  ProgramCounter pc(
    reset, clk,
    jump_2,
    alu_result_2,
    pc_0, next_pc
  );

  /// The special CSR register used to communicate with the testbench.
  REGISTER_R_CE#(.N(32)) tohost(
    .clk(clk), .rst(reset),
    .ce(csr_write_3),
    .q(csr),
    .d(writeback)
  );

  /// The output of this is the value of PC in the decode-read stage.
  /// Since IMEM is synchronous, we have to wait a clock cycle to get
  /// the instruction, which is why this is seperate from pc.
  REGISTER_R_CE#(.N(32)) pc_0_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(pc_1),
    .d(pc_0)
  );
  /// The outut of this is the vale of PC in the execute stage.
  REGISTER_R_CE#(.N(32)) pc_1_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(pc_2),
    .d(pc_1)
  );
  /// The output of this is the value of PC in the writeback stage.
  REGISTER_R_CE#(.N(32)) pc_2_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(pc_3),
    .d(pc_2)
  );

  REGISTER_R_CE#(.N(32)) reg_A_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(reg_A_2),
    .d(reg_A_1)
  );
  REGISTER_R_CE#(.N(32)) reg_B_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(reg_B_2),
    .d(reg_B_1)
  );

  REGISTER_R_CE#(.N(32)) result_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(alu_result_3),
    .d(alu_result_2)
  );

  REGISTER_R_CE#(.N(32)) store_data_buffer(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(store_data_3),
    .d(store_data_2)
  );

  REGISTER_R_CE#(.N(8)) flags_buffer_2_3(
    .clk(clk), .rst(reset | bubble),
    .ce(!internal_stall & !jump_3),
    .q({reg_we_3, csr_write_3, mem_we_3, mem_rr_3, jump_3, funct3_3}),
    .d({reg_we_2, csr_write_2, mem_we_2, mem_rr_2, jump_2, funct3_2})
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_2_3(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(rd_3),
    .d(rd_2)
  );

  assign icache_addr = next_pc;

  assign bubble = jump_3 | ~|branch_delay;

  DecodeRead stage1(
      .clk(clk), .stall(internal_stall), .bubble(bubble | reset),
      .instr(instruction),
      .we(reg_we_3),
      .wa(rd_3),
      .wd(alu_result_2),

      .ra(reg_A_1), .rb(reg_B_1),
      .alu_op(alu_op_2),
      .is_jump(is_jump_2),
      .jump_conditional(jump_conditional_2),
      .funct3(funct3_2),
      .a_sel(a_sel_2), .b_sel(b_sel_2),
      .reg_we(reg_we_2), .mem_we(mem_we_2), .mem_rr(mem_rr_2),
      .rd(rd_2), .rs1(rs1_2), .rs2_shamt(rs2_2),
      .imm(imm_2),
      .csr_write(csr_write_2)
  );

  Execute stage2(
    .clk(clk),

    .pc(pc_2), .reg_A(reg_A_2), .reg_B(reg_B_2),
    .imm(imm_2), .previous(writeback),

    .alu_op(alu_op_2),
    .is_jump(is_jump_2), .jump_conditional(jump_conditional_2),
    .funct3(funct3_2),

    .rs1(rs1_2), .rs2(rs2_2), .prev_rd(rd_3),

    .prev_reg_we(reg_we_3),

    .a_sel(a_sel_2), .b_sel(b_sel_2),

    .jump(jump_2),
    .result(alu_result_2), .store_data(store_data_2)
  );

  always @(posedge clk) begin
    if(reset) branch_delay = 1'b1;
    else if (branch_delay) branch_delay = 1'b0;
    else if (jump_3) branch_delay = 1'b1;
  end

  assign dcache_addr = alu_result_3[31:2];

  Writeback stage3 (
    .clk(clk), .reset(reset), .stall(stall),
    .pc(pc_3),
    .alu_result(alu_result_3),
    .write_data(store_data_3),
    .dcache_output(dcache_dout),
    .funct3(funct3_3),
    .reg_we(reg_we_3), .mem_we(mem_we_3), .mem_rr(mem_rr_3), .jump(jump_3),
    .writeback(writeback), .memory_out(dcache_din),
    .mem_bytes_we(dcache_we),
    .initial_pause(pause)
  );

endmodule
