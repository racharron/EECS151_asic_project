module Regfile (
    input clk,
    input stall,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [4:0] prev_ra1, prev_ra2,
    input [31:0] wd, //write data
    output [31:0] rd1, rd2 // A, B
);
    reg prev_stall, forward_A, forward_B;

    reg [31:0] A, B, A_stall, B_stall, prev_wd;

    reg [31:0] registers_A [31:1];
    reg [31:0] registers_B [31:1];
    reg [31:0] registers_A_stall [31:1];
    reg [31:0] registers_B_stall [31:1];

    assign rd1 = forward_A ? prev_wd : prev_stall ? A_stall : A;
    assign rd2 = forward_B ? prev_wd : prev_stall ? B_stall : B;

    always @(posedge clk) begin
        A <= ra1 == 5'd0 ? 32'd0 : registers_A[ra1];
        B <= ra2 == 5'd0 ? 32'd0 :  registers_B[ra2];
        A_stall <= prev_ra1 == 5'd0 ? 32'd0 : registers_A_stall[prev_ra1];
        B_stall <= prev_ra2 == 5'd0 ? 32'd0 : registers_B_stall[prev_ra2];
        forward_A <= we && wa != 5'd0 && wa == (stall ? prev_ra1 : ra1);
        forward_B <= we && wa != 5'd0 && wa == (stall ? prev_ra2 : ra2);
        prev_stall <= stall;
        if (we && wa != 5'd0) begin
            registers_A[wa] <= wd;
            registers_B[wa] <= wd;
            registers_A_stall[wa] <= wd;
            registers_B_stall[wa] <= wd;
            prev_wd <= wd;
        end
    end
endmodule
