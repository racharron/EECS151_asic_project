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

  assign dcache_re = 1'b1;
  assign icache_re = 1'b1;

  wire we;
  wire [4:0] ra1, ra2, wa;
  wire [31:0] wd;
  wire [31:0] rd1, rd2;
  regfile rf (
    .clk(clk),
    .we(we),
    .ra1(ra1), .ra2(ra2), .wa(wa),
    .wd(wd),
    .rd1(rd1), .rd2(rd2)
  );

/* ***************** FETCH/DECODE STAGE *************** */
  wire regfile_write_enable;
  wire [31:0] writeback_value;
  wire [4:0] writeback_reg;

  wire pc_select;
  wire [31:0] x_alu_result;

  wire [31:0] fd_pc_out;
  
  wire [2:0] immediate_select;

  wire [31:0] fd_instruction_out;
  wire [31:0] fd_rs1_out;
  wire [31:0] fd_rs2_out;
  wire [31:0] fd_immediate_out;

  //Assigningthe input and outputs to the RegFile
  assign we = regfile_write_enable;
  assign ra1 = fd_instruction_out[19:15];
  assign ra2 = fd_instruction_out[24:20];
  assign wa = writeback_reg;
  assign wd = writeback_value;
  assign fd_rs1_out = rd1;
  assign fd_rs2_out = rd2;

  fetch_decode #(
    .IMEM_AWIDTH(32)
  ) fd (
    .clk(clk),
    .rst(reset),

    .imem_addr(icache_addr),
    .imem_inst(icache_dout),

    .pc_select(pc_select),
    .alu_result(x_alu_result),
    .pc_out(fd_pc_out),
    .immediate_select(immediate_select),
    
    .instruction_out(fd_instruction_out),
    .immediate_out(fd_immediate_out)
  );

  fetch_decode_logic fd_logic (
    .instruction(fd_instruction_out),
    .immediate_select(immediate_select)
  );

  /*Pipeline registers*/
  wire x_nop_stall;
  wire [31:0] x_pc;
  wire [31:0] x_instruction_in;
  wire [31:0] x_rs1_in;
  wire [31:0] x_rs2_in;
  wire [31:0] x_immediate_in;

  //PC register
  REGISTER #(.N(32)) fd_x_pc (
    .clk(clk),
    .d(fd_pc_out),
    .q(x_pc)
  );

  // Handle stalling
  wire [31:0] fd_instruction_stall;
  assign fd_instruction_stall = x_nop_stall ? `INSTR_NOP : fd_instruction_out;
 
  REGISTER #(.N(32)) fd_x_inst (
    .clk(clk),
    .d(fd_instruction_stall),
    .q(x_instruction_in)
  );

  //Execute RS1 register
  REGISTER #(.N(32)) fd_x_rs1 (
    .clk(clk),
    .d(fd_rs1_out),
    .q(x_rs1_in)
  );

  //Execute RS2 register
  REGISTER #(.N(32)) fd_x_rs2 (
    .clk(clk),
    .d(fd_rs2_out),
    .q(x_rs2_in)
  );

  //Execute IMM register
  REGISTER #(.N(32)) fd_x_imm (
    .clk(clk),
    .d(fd_immediate_out),
    .q(x_immediate_in)
  );


  /****************** EXECUTE STAGE *****************/
  // forwarding / control signals
  wire [1:0] a_forward_select;
  wire [1:0] b_forward_select;
  wire a_select;
  wire b_select;
  
  wire unsigned_compare;
  wire less_than;
  wire equal;

  wire [3:0] alu_select;
  wire [31:0] mem_write;
  wire [31:0] csr_result;
  execute ex (
    .clk(clk),
    .rs1(x_rs1_in),
    .rs2(x_rs2_in),

    .instruction(x_instruction_in),
    .immediate(x_immediate_in),

    .writeback(writeback_value),
    .a_forward_select(a_forward_select),
    .b_forward_select(b_forward_select),

    .pc(x_pc),

    .a_select(a_select),
    .b_select(b_select),
    
    .unsigned_compare(unsigned_compare),
    .less_than(less_than),
    .equal(equal),
    
    .alu_select(alu_select),
    .alu_result(x_alu_result),

    .mem_write(mem_write),
    .csr_out(csr_result)
  );

  execute_logic x_logic (
    .instruction(x_instruction_in),
    .less_than(less_than),
    .equal(equal),

    .alu_select(alu_select),
    .a_select(a_select),
    .b_select(b_select),
    .unsigned_compare(unsigned_compare),
    .nop_stall(x_nop_stall),
    .pc_select(pc_select)
  );
  
  wire [31:0] m_pc;
  wire [31:0] m_inst;
  wire [31:0] m_alu_out;

  //Pipeline Registers
  REGISTER #(.N(32)) x_m_inst (
    .clk(clk),
    .d(x_instruction_in),
    .q(m_inst)
  );

  REGISTER #(.N(32)) x_m_pc (
    .clk(clk),
    .d(x_pc),
    .q(m_pc)
  );

  REGISTER #(.N(32)) x_m_alu (
    .clk(clk),
    .d(x_alu_result),
    .q(m_alu_out)
  );

  /************* MEMORY/WRITEBACK STAGE ****************/

  //Handle stores for address partioning and memory
  wire [31:0] shifted_mem_write;

  store_mask mask (
    .instruction(x_instruction_in),
    .mem_addr(x_alu_result),
    .pc(x_pc),

    .dmem_we(dcache_we),
    .mem_write(mem_write),
    .shifted_mem_write(shifted_mem_write)
  );

  // memories act like pipeline registers
  // word-addressed not byte addressed
  assign dcache_addr = x_alu_result;
  assign dcache_din = shifted_mem_write;

  /* Memory / Writeback stage */
  assign writeback_reg = m_inst[11:7]; //rd
  
  //maybe we can pipeline nop if we fail some cases 
  memory_writeback m_wb (
    .clk(clk),
    .rst(reset),
    .pc(m_pc),
    .alu_result(m_alu_out),
    .dmem_output(dcache_dout),
    .instruction(m_inst),
    .writeback(writeback_value),
    .write_enable(regfile_write_enable)
  );

  forwarding_logic forwarder (
    .clk(clk),
    .fd_instruction(fd_instruction_out),
    .x_instruction(x_instruction_in),
    .m_instruction(m_inst),

    .a_forward_select(a_forward_select),
    .b_forward_select(b_forward_select)
  );

  REGISTER #(.N(32)) csr_output (
    .clk(clk),
    .d(csr_result),
    .q(csr)
  );
endmodule
