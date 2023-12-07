module Execute (
    /// Previous is either the output of the ALU, or a load.
    input [31:0] A, B, reg_A, reg_B,
    input [3:0] alu_op,
    input is_jump, is_branch,
    input [2:0] funct3,

    output do_jump,
    output [31:0] result, jump_target
);
    wire condition_true;

    assign do_jump = is_jump && (!is_branch || condition_true);
    assign jump_target = A + B;

    ALU alu(A, B, alu_op, result);

    BranchControl bc(reg_A, reg_B, funct3, condition_true);
    
endmodule