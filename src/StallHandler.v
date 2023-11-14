module StallHandler (
    input clk, stall,
    input [31:0] in,
    output [31:0] out
);

    reg [31:0] prev_in;
    reg prev_stall;

    assign out = prev_stall ? prev_in : in;

    always @(posedge clk) begin
        prev_in <= in;
        prev_stall <= stall;
    end
    
endmodule