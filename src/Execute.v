module Execute (
    input clk,

    /// Previous is either the output of the ALU, or a load.
    input [31:0] pc, reg_A, reg_B, imm, previous,
    input [3:0] alu_op,
    input is_jump, jump_conditional,
    input funct3,

    input [4:0] rs1, rs2_shamt, prev_rd,
    input prev_reg_we,

    input a_sel, b_sel,

    output jump,
    output [31:0] result
);

    wire [31:0] A, B, forwarded_A, forwarded_B;
    wire forward_A, forward_B;
    wire branch;
    
    assign A = a_sel ? forwarded_A : pc;
    assign B = b_sel ? imm : forwarded_B;

    assign forwarded_A = forward_A ? previous : reg_A;
    assign forwarded_B = forward_B ? previous : reg_B;

    assign forward_A = (rs1 == prev_rd) & prev_reg_we;
    assign forward_B = (rs2 == prev_rd) & prev_reg_we;

    assign jump = is_jump & (!jump_conditional | branch);

    ALU alu(A, B, alu_op, result);

    BranchControl bc(forwarded_A, forwarded_B, funct3, branch);
    
endmodule