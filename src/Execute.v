module Execute (
    input clk, reset,

    /// Previous is either the output of the ALU, or a load.
    input [31:0] pc, reg_A, reg_B, imm, previous,
    input [3:0] alu_op,
    input add_rshift_type,
    input shift_imm,

    input [4:0] rs1, rs2_shamt, prev_rd,
    input prev_reg_we,

    input a_sel, b_sel,

    output jump,
    output [31:0] result
);

    wire [31:0] A, B;
    wire forward_A, forward_B;
    
    assign A = a_sel ? (forward_A ? previous : reg_A) : pc;
    assign B = b_sel ? imm : forward_B ? previous : reg_B;

    assign forward_A = (rs1 == prev_rd) & prev_reg_we;
    assign forward_B = (rs2 == prev_rd) & prev_reg_we;
    
endmodule