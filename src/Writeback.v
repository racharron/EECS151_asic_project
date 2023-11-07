module Writeback (
  input clk,
  input [31:0] pc,
  input [31:0] alu_result,
  input [31:0] dcache_output,
  input [2:0] funct3,
  input is_branch,
  input is_jump,
  input is_load,
  input is_store,
  input csr_enable,
  output reg [31:0] writeback,
  output reg reg_write_enable
);
  
  reg [31:0] unmasked_load;
  wire [31:0] masked_load;

  ld mask (
    .mem_address(alu_result),
    .mem_output(unmasked_load),
    .funct3(funct3),
    .load_out(masked_load)
  );
  
  wire [31:0] pc_plus_four;
  assign pc_plus_four = pc + 32'd4;

  always @(*) begin
    reg_write_enable = 1'b1;
    writeback = alu_result;
        
    //writeback mux
    if (is_store) reg_write_enable = 1'b0;
    else if (is_load) writeback = masked_load;
    else if (is_branch) reg_write_enable = 1'b0;
    else if (is_jump) writeback = pc_plus_four;

    if (csr_enable) begin
        reg_write_enable = 1'b0;
    end 
    unmasked_load = dcache_output;
  end 
endmodule