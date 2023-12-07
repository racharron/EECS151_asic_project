module DataSelector (
    input clk,
    input a_sel_reg, b_sel_reg,
    input [31:0] reg_A_1, reg_B_1, pc, imm, ex_alu_result, mem_req_alu_result, mem_resp_alu_result, writeback,
    input [4:0] rs1, rs2,
    input ex_reg_we, mem_req_reg_we, mem_resp_reg_we, wb_reg_we,
    input [4:0] ex_rd, mem_req_rd, mem_resp_rd, wb_rd,
    output [31:0] reg_A_2, reg_B_2, A_2, B_2
);
    RegSelector a (
        .clk(clk),
        .sel_reg(a_sel_reg),
        .reg_1(reg_A_1), .other(pc),
        .ex_alu_result(ex_alu_result),
        .mem_req_alu_result(mem_req_alu_result),
        .mem_resp_alu_result(mem_resp_alu_result),
        .writeback(writeback),
        .rs(rs1),
        .ex_reg_we(ex_reg_we), .mem_req_reg_we(mem_req_reg_we), .mem_resp_reg_we(mem_resp_reg_we), .wb_reg_we(wb_reg_we),
        .ex_rd(ex_rd), .mem_req_rd(mem_req_rd), .mem_resp_rd(mem_resp_rd), .wb_rd(wb_rd),
        .reg_2(reg_A_2), .op_2(A_2)
    );
    RegSelector b (
        .clk(clk),
        .sel_reg(b_sel_reg),
        .reg_1(reg_B_1), .other(imm),
        .ex_alu_result(ex_alu_result),
        .mem_req_alu_result(mem_req_alu_result),
        .mem_resp_alu_result(mem_resp_alu_result),
        .writeback(writeback),
        .rs(rs2),
        .ex_reg_we(ex_reg_we), .mem_req_reg_we(mem_req_reg_we), .mem_resp_reg_we(mem_resp_reg_we), .wb_reg_we(wb_reg_we),
        .ex_rd(ex_rd), .mem_req_rd(mem_req_rd), .mem_resp_rd(mem_resp_rd), .wb_rd(wb_rd),
        .reg_2(reg_B_2), .op_2(B_2)
    );
endmodule