`include "Opcode.vh"

module store_mask (
    input [31:0] instruction,
    input [31:0] mem_addr,
    input [31:0] pc,

    output [3:0] dmem_we,

    input [31:0] mem_write,
    output reg [31:0] shifted_mem_write
);
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] opcode = instruction[6:0];

    reg[3:0] dmem_write;
    wire [1:0] offset = mem_addr[1:0];
    assign dmem_we = dmem_write;

    always @(*) begin
        dmem_write = 4'b0000;
        shifted_mem_write = mem_write;

        if (opcode == `OPC_STORE) begin
            case (funct3) 
                `FNC_SB: begin
                    shifted_mem_write = mem_write << {offset, 3'b000};
                    dmem_write = 4'b0001 << offset;
                end
                `FNC_SH: begin
                    shifted_mem_write = mem_write << {offset[1], 4'b0000};
                    dmem_write = 4'b0011 << {offset[1], 1'b0};
                end
                `FNC_SW: begin
                    dmem_write = 4'b1111;
                end
            endcase
        end
    end
    
endmodule