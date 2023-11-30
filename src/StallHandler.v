module StallHandler (
    input clk, stall, reset,
    input [31:0] in,
    output [31:0] out
);

    reg [31:0] prev_in, stall_in;
    reg prev_stall, occupied;

    assign out = occupied && stall? prev_in : occupied && prev_stall ? stall_in : in;

    always @(posedge clk) begin
        if (!stall && !reset) begin
            prev_in <= in;
            occupied <= 1'b1;
        end
        if (stall) begin
            stall_in <= in;
        end
        if (reset) occupied <= 1'b0;
        prev_stall <= stall;
    end
    
endmodule