module Regfile (
    input clk, stall,
    input we,  //write enable
    input [4:0] ra1, ra2, wa, // address A, address B, and write address
    input [31:0] wd, //write data
    output reg [31:0] rd1, rd2 // A, B
);
    wire [31:0] din, rd_1, rd_2;
    //x0 should always be zero
    assign din = (wa == 0) ? 32'd0 : wd;

    REG_1W2R #(
        .DWIDTH(32),
        .AWIDTH(5),
        .DEPTH(32)
    ) REG_1W2R (
        .clk(clk),
        .d0(din),
        .addr0(wa),
        .we(we & |wa & !stall),
        .q1(rd_1),
        .addr1(ra1),
        .q2(rd_2), 
        .addr2(ra2)
    );

    always @(posedge clk) begin
        if (!stall) begin
            rd1 <= (ra1 == 0) ? 32'd0 : (we & (ra1 == wa)) ? wd : rd_1;
            rd2 <= (ra2 == 0) ? 32'd0 : (we & (ra2 == wa)) ? wd : rd_2;
        end
    end
    
    x0_always_0:
    assert property (
        /// We ignore if time = 0, because it hasn't been set yet.
        @(posedge |REG_1W2R.mem[0]) $time == 0
    ) 
    else   $error("x0 = %h @ $d", $sampled(REG_1W2R.mem[0]), $time);
endmodule
