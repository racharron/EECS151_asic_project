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

  /// Adds a delay after reset to let everything propagate first
  /// This is the value of reset from the previous cycle.
  reg prev_reset;

  wire [2:0] funct3_1, funct3_2, funct3_3;

  /// Fed into IMEM.
  wire [31:0] next_pc;
  /// The value of PC in the decode-read stage.
  wire [31:0] pc_1;
  /// The value of PC in the execute stage.
  wire [31:0] pc_2;
  /// The value of PC in the writeback stage.
  wire [31:0] pc_3;

  /// The instruction that stage 1 can see.  Outputted by the stall handler.
  wire [31:0] instruction;

  /// Signals indicating if this instruction should cause a jump.
  /// jump_3 is also the bubble signal.
  wire do_jump_2, do_jump_3;
  
  /// The register file write enables for each stage of the pipeline.
  wire reg_we_1, reg_we_2, reg_we_3;
  /// The memory write enables for each stage of the pipeline.
  wire mem_we_1, mem_we_2, mem_we_3;
  /// The memory read request for each stage of the pipeline.
  wire mem_rr_1, mem_rr_2, mem_rr_3;
  
  /// The rd index for each stage of the pipeline.
  wire [4:0] rd_1, rd_2, rd_3;
  /// The rs1 index for each stage of the pipeline.
  wire [4:0] rs1_1, rs1_2;
  /// The rs2 index for each stage of the pipeline.
  wire [4:0] rs2_1, rs2_2;

  /// The A and B values from the registers for each stage of the pipeline.
  wire [31:0] reg_A_2, reg_B_2;

  /// The generated immediates across the first two stages of the pipeline.
  wire [31:0] imm_1, imm_2;

  /// The value that is written to the register file
  wire [31:0] writeback;

  wire [3:0] alu_op_1, alu_op_2;
  wire a_sel_1, a_sel_2;
  wire b_sel_1, b_sel_2;
  wire is_jump_1, is_jump_2;
  wire is_branch_1, is_branch_2;

  /// Indicates that we should write to the CSR register in writeback.
  wire csr_write_1, csr_write_2, csr_write_3;

  wire [31:0] alu_result_2, alu_result_3;
  wire [31:0] store_data_2, store_data_3;

  /// Indicates if we should turn the following instructions into nops.
  /// Signalled on taken jumps.
  wire bubble;
  /// Pause indicates that stage 3 is beginning a read, and everything should temporarily halt.
  /// Internal stall is a synonym for stall | pause
  /// We also stall for a cycle after reset because otherwise the cache becomes undefined.
  /// This is a hack, but it works.
  wire pause, internal_stall;

  assign dcache_re = mem_rr_3;
  assign icache_re = 1'b1;
  assign internal_stall = stall | pause | prev_reset;

  assign icache_addr = next_pc;

  assign bubble = do_jump_2;

  /// This holds the PC value used for getting the next instruction.  
  /// It has to be delayed due to memory being synchronous.
  ProgramCounter pc(
    clk, reset, internal_stall,
    do_jump_2,
    alu_result_2,
    pc_1, next_pc
  );

  Regfile regfile(
    .clk(clk), .stall(internal_stall),
    .we(reg_we_3),
    .ra1(rs1_1), .ra2(rs2_1), .wa(rd_3),
    .wd(writeback),
    .rd1(reg_A_2), .rd2(reg_B_2)
  );

  /// The special CSR register used to communicate with the testbench.
  REGISTER_R_CE#(.N(32)) tohost(
    .clk(clk), .rst(reset),
    .ce(csr_write_3),
    .q(csr),
    .d(writeback)
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

  REGISTER_R_CE#(.N(5)) rs1_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(rs1_2),
    .d(rs1_1)
  );

  REGISTER_R_CE#(.N(5)) rs2_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(rs2_2),
    .d(rs2_1)
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

  REGISTER_R_CE#(.N(4)) flags_buffer_1_2(
    .clk(clk), .rst(reset | (bubble & !internal_stall)),
    .ce(!internal_stall),
    .q({reg_we_2, csr_write_2, mem_we_2, mem_rr_2}),
    .d({reg_we_1, csr_write_1, mem_we_1, mem_rr_1})
  );

  REGISTER_R_CE#(.N(5)) flags_buffer_2_3(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q({reg_we_3, csr_write_3, mem_we_3, mem_rr_3, do_jump_3}),
    .d({reg_we_2, csr_write_2, mem_we_2, mem_rr_2, do_jump_2})
  );

  REGISTER_R_CE#(.N(2)) jump_flag_buffer_1_2(
    .clk(clk), .rst(reset | (bubble & !internal_stall)),
    .ce(!internal_stall),
    .q({is_jump_2, is_branch_2}),
    .d({is_jump_1, is_branch_1})
  );

  REGISTER_R_CE#(.N(3)) funct3_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!internal_stall),
    .q(funct3_2),
    .d(funct3_1)
  );

  REGISTER_R_CE#(.N(3)) funct3_buffer_2_3(
    .clk(clk), .rst(1'b0),
    .ce(!internal_stall),
    .q(funct3_3),
    .d(funct3_2)
  );

  REGISTER_R_CE#(.N(4)) alu_op_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!internal_stall),
    .q(alu_op_2),
    .d(alu_op_1)
  );

  REGISTER_R_CE#(.N(2)) select_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!internal_stall),
    .q({a_sel_2, b_sel_2}),
    .d({a_sel_1, b_sel_1})
  );

  REGISTER_R_CE#(.N(32)) imm_buffer_1_2(
    .clk(clk), .rst(1'b0),
    .ce(!internal_stall),
    .q(imm_2),
    .d(imm_1)
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_1_2(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(rd_2),
    .d(rd_1)
  );

  REGISTER_R_CE#(.N(5)) rd_buffer_2_3(
    .clk(clk), .rst(reset),
    .ce(!internal_stall),
    .q(rd_3),
    .d(rd_2)
  );

  StallHandler stall_handler(clk, internal_stall, reset, icache_dout, instruction);

  DecodeRead stage1(
      .stall(internal_stall), .bubble(bubble | reset),
      .instr(instruction),

      .alu_op(alu_op_1),
      .is_jump(is_jump_1),
      .is_branch(is_branch_1),
      .funct3(funct3_1),
      .a_sel(a_sel_1), .b_sel(b_sel_1),
      .reg_we(reg_we_1), .mem_we(mem_we_1), .mem_rr(mem_rr_1),
      .rd(rd_1), .rs1(rs1_1), .rs2(rs2_1),
      .imm(imm_1),
      .csr_write(csr_write_1)
  );

  Execute stage2(
    .pc(pc_2), .reg_A(reg_A_2), .reg_B(reg_B_2),
    .imm(imm_2), .previous(writeback),

    .alu_op(alu_op_2),
    .is_jump(is_jump_2), .is_branch(is_branch_2),
    .funct3(funct3_2),

    .rs1(rs1_2), .rs2(rs2_2), .prev_rd(rd_3),

    .prev_reg_we(reg_we_3),

    .a_sel(a_sel_2), .b_sel(b_sel_2),

    .do_jump(do_jump_2),
    .result(alu_result_2), .store_data(store_data_2)
  );

  assign dcache_addr = {alu_result_3[31:2], 2'b00};

  Writeback stage3 (
    .clk(clk), .reset(reset), .stall(internal_stall),
    .pc(pc_3),
    .alu_result(alu_result_3),
    .write_data(store_data_3),
    .dcache_output(dcache_dout),
    .funct3(funct3_3),
    .reg_we(reg_we_3), .mem_we(mem_we_3), .mem_rr(mem_rr_3), .do_jump(do_jump_3),
    .writeback(writeback), .memory_out(dcache_din),
    .mem_bytes_we(dcache_we),
    .initial_pause(pause)
  );

  always @(posedge clk) prev_reset <= reset;

endmodule
