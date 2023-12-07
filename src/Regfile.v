module Regfile (
    input clk,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [31:0] wd, //write data
    output [31:0] rd1, rd2 // A, B
);
    reg [31:0] registers [32];

    assign rd1 = ra1 == 5'd0 ? 32'd0 : registers[ra1];
    assign rd2 = ra2 == 5'd0 ? 32'd0 : registers[ra2];

    always @(posedge clk) begin
        if (we && wa != 5'd0) registers[wa] <= wd;
    end
endmodule
