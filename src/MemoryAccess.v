module MemoryAccess (
    input stall, mem_we,
    input [2:0] funct3,
    input [31:0] alu_result,
    output [3:0] bwe,
    output [31:0] dcache_addr, dcache_din,
    input [31:0] data
);
    wire [31:0] address;
    wire [3:0] raw_bwe;
    assign address = alu_result;
    assign dcache_addr = {address[31:2], 2'b00};
    assign bwe = stall ? 4'h0 : raw_bwe;

    Store store_unit(
        .addr(address), .value(data),
        .funct3(funct3),
        .we(mem_we),
        .bwe(raw_bwe),
        .write_out(dcache_din)
    );

endmodule