module Store (
    input [31:0] addr, value,
    input [2:0] funct3,
    input we,
    /// Byte write enables, all 0 indicates no write
    output reg [3:0] bwe,
    output reg [31:0] write_out
);
    always @(*) begin
        case (funct3)
            `FNC_SB: begin
                bwe <= {4{we}} & 4'b0001 << addr[1:0];
                write_out <= value << {addr[1:0], 3'b000};
            end
            `FNC_SH: begin
                bwe <= {4{we}} & 4'b0011 << {addr[1], 1'b0};
                write_out <= value << {addr[1], 4'b0000};
            end
            `FNC_SW: begin
                bwe <= {4{we}} & 4'b1111;
                write_out <= value;
            end
            default: begin
                bwe <= 4'b0000;
                write_out <= 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
            end
        endcase
    end
endmodule