/*Memory/Writeback Stage
No need for a control logic as it is already incorporated into the module.*/
module memory_writeback(
  input clk,
  input rst,
  
  input [31:0] pc,
  input [31:0] alu_result,
  input [31:0] dmem_output,
  input [31:0] instruction,

  output reg [31:0] writeback,
  output reg write_enable
);
  
  reg [31:0] unmasked_load;
  wire [31:0] masked_load;

  //ld module
  load_mask mask (
    .mem_address(alu_result),
    .mem_output(unmasked_load),
    .instruction(instruction),
    .load_out(masked_load)
  );

  wire [6:0] opcode;
  assign opcode = instruction[6:0];
  
  wire [31:0] pc_plus_four;
  assign pc_plus_four = pc + 32'd4;


  always @(*) begin
    write_enable = 1'b1;
    writeback = alu_result;
    
    //Writeback MUX
    case (opcode)
      `OPC_STORE: write_enable = 1'b0;
      `OPC_LOAD: writeback = masked_load;
      `OPC_BRANCH: write_enable = 1'b0;
      `OPC_JAL, `OPC_JALR: writeback = pc_plus_four;
      `OPC_CSR: write_enable = 1'b0;
    endcase

    unmasked_load = dmem_output;
  end

endmodule