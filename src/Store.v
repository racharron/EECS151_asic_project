module Store (
    input [31:0] addr, value,
    input [2:0] funct3,
    input we,
    output [3:0] bwe,
    output [31:0] write_out
);
    wire [3:0] enables;
    assign bwe = {4{we}} & enables;

    always @(*) begin
        case (funct3)
            `FNC_SB: begin
                enables <= 4'b0001 << addr[1:0];
                write_out <= value << {addr[1:0], 3'b000};
            end
            `FNC_SH: begin
                enables <= 4'b0011 << {addr[1], 1'b0};
                write_out <= value << {addr[1], 4'b0000};
            end
            `FNC_SW: begin
                enables <= 4'b1111;
                write_out <= 
            end
            default: begin
                bwe <= 4'bxxxx;
                write_out <= 32:'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
            end
        endcase
    end
endmodule