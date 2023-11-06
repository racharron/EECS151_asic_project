module regfile (
    input clk,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [31:0] wd, //write data
    output [31:0] rd1, rd2 // A, B
);
    wire [31:0] din, rd_1, rd_2;
    //x0 should always be zero
    assign rd1 = (ra1 == 0) ? 32'd0 : rd_1;
    assign rd2 = (ra2 == 0) ? 32'd0 : rd_2;

    REG_1W2R #(
        .DWIDTH(32),
        .AWIDTH(5),
        .DEPTH(32)
    ) REG_1W2R (
        .clk(clk),
        .d0(din),
        .addr0(wa),
        .we(we & |wa),
        .q1(rd_1),
        .addr1(ra1),
        .q2(rd_2), 
        .addr2(ra2)
    );
endmodule