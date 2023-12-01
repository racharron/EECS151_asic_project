module Execute (
    /// Previous is either the output of the ALU, or a load.
    input [31:0] pc, reg_A, reg_B, imm, previous,
    input [3:0] alu_op,
    input is_jump, is_branch,
    input [2:0] funct3,

    input [4:0] rs1, rs2, prev_rd,
    input prev_reg_we, mem_we,

    input a_sel, b_sel,

    output do_jump,
    output [31:0] result, store_data, store_address,
    output [3:0] bwe
);

    wire [31:0] A, B, forwarded_A, forwarded_B;
    wire [31:0] address;
    wire forward_A, forward_B;
    wire condition_true;
    wire [3:0] store_bytes;
    
    assign A = a_sel ? forwarded_A : pc;
    assign B = b_sel ? imm : forwarded_B;

    assign forwarded_A = forward_A ? previous : reg_A;
    assign forwarded_B = forward_B ? previous : reg_B;

    assign forward_A = rs1 == prev_rd && prev_rd != 5'd0 && prev_reg_we;
    assign forward_B = rs2 == prev_rd && prev_rd != 5'd0 && prev_reg_we;

    assign do_jump = is_jump && (!is_branch || condition_true);

    assign address = forwarded_A + imm;
    assign store_address = {address[31:2], 2'd0};
    assign bwe = mem_we ? store_bytes : 4'h0;

    Store store_unit(
        .addr(address), .value(forwarded_B),
        .funct3(funct3),
        .we(mem_we),
        .bwe(store_bytes),
        .write_out(store_data)
    );

    ALU alu(A, B, alu_op, result);

    BranchControl bc(forwarded_A, forwarded_B, funct3, condition_true);
    
endmodule