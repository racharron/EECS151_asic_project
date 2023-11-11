module DecodeRead (
    input clk, stall, bubble,
    input [31:0] instr,

    output [3:0] alu_op,
    output reg is_jump, is_branch,
    output reg [2:0] funct3,
    output reg a_sel, b_sel,
    /// Register WE, Memory WE (for stores), Memory Read Request (for loads)
    output reg reg_we, mem_we, mem_rr,
    /// The immediate shift around amount and rs2 are combined in the same bus.
    output reg [4:0] rd,
    output [4:0] rs1, rs2,
    output reg [31:0] imm,
    output reg csr_write
);

    wire [6:0] opcode, funct7;
    wire add_rshift_type_wire;
    wire [2:0] funct3_wire;
    wire [4:0] rd_wire;
    wire [31:0] imm_wire;

    assign add_rshift_type_wire = funct7[5];

    Decoder decoder(
        instr,
        opcode,
        funct3_wire,
        rd_wire, rs1, rs2,
        funct7,
        imm_wire
    );

    ALUdec alu_dec(opcode, funct3_wire, add_rshift_type_wire, alu_op);

    always @(posedge clk) begin
        if (bubble) begin
            reg_we <= 1'b0;
            mem_we <= 1'b0;
            mem_rr <= 1'b0;
            csr_write <= 1'b0;
            is_jump <= 1'b0;
        end else if (!stall) begin
            funct3 <= funct3_wire;
            is_jump <= (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_BRANCH);
            is_branch <= opcode == `OPC_BRANCH;
            a_sel <= ((opcode == `OPC_JAL) | (opcode == `OPC_AUIPC) | (opcode ==`OPC_BRANCH)) ? 1'b0 
                : ((opcode == `OPC_STORE) | (opcode == `OPC_LOAD) | (opcode == `OPC_ARI_RTYPE) 
                    | (opcode == `OPC_ARI_ITYPE) | (opcode == `OPC_CSR)) ? 1'b1
                : 1'bx;
            b_sel <= ((opcode == `OPC_STORE) | (opcode == `OPC_ARI_RTYPE)) ? 1'b0
                : ((opcode == `OPC_LUI) | (opcode == `OPC_AUIPC) | (opcode == `OPC_JAL) | (opcode == `OPC_CSR)
                    | (opcode == `OPC_JALR) | (opcode == `OPC_BRANCH) | (opcode == `OPC_LOAD)
                    | (opcode == `OPC_STORE) | (opcode == `OPC_ARI_ITYPE)) ? 1'b1
                : 1'bx;
            reg_we <= (opcode == `OPC_LUI) | (opcode == `OPC_AUIPC) | (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_LOAD) | (opcode == `OPC_ARI_ITYPE)
                | (opcode == `OPC_ARI_RTYPE);
            mem_we <= opcode == `OPC_STORE;
            mem_rr <= opcode == `OPC_LOAD;
            csr_write <= opcode == `OPC_CSR;
            rd <= rd_wire;
            imm <= imm_wire;
        end
    end
    
endmodule