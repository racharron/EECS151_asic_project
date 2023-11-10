module Writeback (
  input clk, reset, stall,
  input [31:0] pc,
  input [31:0] alu_result,
  input [31:0] write_data,
  input [31:0] dcache_output,
  input [2:0] funct3,
  input reg_we, mem_we, mem_rr, jump,

  output [31:0] writeback, memory_out,
  output [3:0] mem_bytes_we,
  /// Tells the CPU to pause for at least one cycle, so that the memory has time to at least get the address.
  /// In the no_cache_mem model, there is no stall signal to tell the CPU to wait a cycle.
  output initial_pause
);
  
  
  reg continue_load;
  wire jalr;
  wire [31:0] masked_load;

  ld mask (
    .mem_address(alu_result),
    .mem_output(dcache_output),
    .funct3(funct3),
    .load_out(masked_load)
  );

  Store store_unit(
    .addr(alu_result), .value(write_data),
    .funct3(funct3),
    .we(mem_we),
    .bwe(mem_bytes_we),
    .write_out(memory_out)
  );
  

  assign initial_pause = mem_rr & !continue_load;
  assign jalr = reg_we & jump;
  assign writeback = jalr ? pc + 32'd4
    : mem_rr ? masked_load
    : alu_result;

  always @(posedge clk) begin
    if (reset) continue_load <= 1'b0;
    else if (continue_load & !stall) continue_load <= 1'b0;
    else if (mem_rr) continue_load <= 1'b1;
  end
endmodule