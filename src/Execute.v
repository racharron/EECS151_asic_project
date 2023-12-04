module Execute (
    /// Previous is either the output of the ALU, or a load.
    input [31:0] pc, reg_A, reg_B, imm, previous, writeback,
    input [3:0] alu_op,
    input is_jump, is_branch,
    input [2:0] funct3,

    input [4:0] rs1, rs2, prev_rd, wb_rd,
    input prev_reg_we, wb_reg_we, 

    input a_sel_reg,// a_forwards_prev, a_forwards_wb,
    input b_sel_reg,// b_forwards_prev, b_forwards_wb,

    output do_jump,
    output [31:0] result, store_data
);
    wire [31:0] A, B, forwarded_A, forwarded_B;
    wire forward_A_alu, forward_B_alu, forward_A_wb, forward_B_wb;
    wire condition_true;
    
    assign A = a_sel_reg ? forwarded_A : pc;
    assign B = b_sel_reg ? forwarded_B : imm;

    //  TODO: fix forwarding
    //  On read bubbles, the original writeback is lost, and not forwarded properly (???)

    assign forwarded_A = forward_A_alu ? previous : forward_A_wb ? writeback : reg_A;
    assign forwarded_B = forward_B_alu ? previous : forward_B_wb ? writeback : reg_B;

    assign forward_A_alu = rs1 == prev_rd && prev_rd != 5'd0 && prev_reg_we;
    assign forward_B_alu = rs2 == prev_rd && prev_rd != 5'd0 && prev_reg_we;
    assign forward_A_wb = rs1 == wb_rd && wb_rd != 5'd0 && wb_reg_we;
    assign forward_B_wb = rs2 == wb_rd && wb_rd != 5'd0 && wb_reg_we;

    assign do_jump = is_jump && (!is_branch || condition_true);

    assign store_data = forwarded_B;

    ALU alu(A, B, alu_op, result);

    BranchControl bc(forwarded_A, forwarded_B, funct3, condition_true);
    
endmodule