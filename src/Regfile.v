module Regfile (
    input clk,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [31:0] wd, //write data
    output reg [31:0] rd1, rd2 // A, B
);

    reg [31:0] registers [31:1];

    always @(posedge clk) begin
        rd1 <= (ra1 == 5'd0) ? 32'd0 : (we && ra1 == wa) ? wd : registers[ra1];
        rd2 <= (ra2 == 5'd0) ? 32'd0 : (we && ra2 == wa) ? wd : registers[ra2];
        if (we && wa != 5'd0) begin
            registers[wa] <= wd;
        end
    end
endmodule
