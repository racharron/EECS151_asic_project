module BubbleGenerator (
    input mem_req_reg_we, mem_resp_reg_we, wb_reg_we,
    input mem_req_rr, mem_resp_rr, wb_rr,
    input [4:0] mem_req_rd, mem_resp_rd, wb_rd, 
    input ex_a_sel_reg, ex_b_sel_reg,

    input [4:0] ex_rs1, ex_rs2,
    input ex_store, ex_branch,
    output bubble
);
    wire mem_req_bubble, mem_resp_bubble, wb_bubble;
    assign mem_req_bubble = mem_req_reg_we && mem_req_rr && mem_req_rd != 5'd0 
        && (((ex_a_sel_reg | ex_branch) && ex_rs1 == mem_req_rd) | ((ex_b_sel_reg | ex_store | ex_branch) && ex_rs2 == mem_req_rd));
    assign mem_resp_bubble = mem_resp_reg_we && mem_resp_rr && mem_resp_rd != 5'd0 
        && (((ex_a_sel_reg | ex_branch) && ex_rs1 == mem_resp_rd) | ((ex_b_sel_reg | ex_store | ex_branch) && ex_rs2 == mem_resp_rd));
    assign wb_bubble = wb_reg_we && wb_rr && wb_rd != 5'd0 
        && (((ex_a_sel_reg | ex_branch) && ex_rs1 == wb_rd) | ((ex_b_sel_reg | ex_store | ex_branch) && ex_rs2 == wb_rd));
    assign bubble = mem_req_bubble | mem_resp_bubble | wb_bubble;
endmodule