module RegSelector (
    input clk,
    input sel_reg,
    input [31:0] reg_1, other, ex_alu_result, mem_req_alu_result, mem_resp_alu_result, writeback,
    input [4:0] rs,
    input ex_reg_we, mem_req_reg_we, mem_resp_reg_we, wb_reg_we,
    input [4:0] ex_rd, mem_req_rd, mem_resp_rd, wb_rd,
    output reg [31:0] reg_2, op_2
);
    always @(posedge clk) begin
        if (rs == 5'd0) begin
            reg_2 = 32'd0;
        end else begin
            if (ex_reg_we && rs == ex_rd) reg_2 = ex_alu_result;
            else if (mem_req_reg_we && rs == mem_req_rd) reg_2 = mem_req_alu_result;
            else if (mem_resp_reg_we && rs == mem_resp_rd) reg_2 = mem_resp_alu_result;
            else if (wb_reg_we && rs == wb_rd) reg_2 = writeback;
            else reg_2 = reg_1;
        end
        op_2 = sel_reg ? reg_2 : other;
    end
endmodule
