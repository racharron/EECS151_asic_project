module DecodeRead (
    input clk, stall, bubble,
    input [31:0] instr,
    input we,
    input [4:0] wa,
    input [31:0] wd,

    output [31:0] ra, rb,
    output reg [3:0] alu_op,
    output reg add_rshift_type,
    /// Indicates if we are doing a shift by immediate.
    output reg shift_imm,
    output reg a_sel, b_sel,
    /// Register WE, Memory WE (for stores), Memory Read Request (for loads)
    output reg reg_we, mem_we, mem_rr,
    /// The immediate shift around amount and rs2 are combined in the same bus.
    output reg [4:0] rd, rs1, rs2_shamt,
    output reg [31:0] imm,
    output reg csr_write, csr_imm
);

    wire [6:0] opcode, funct7;
    wire [2:0] funct3;
    wire [3:0] alu_op_wire;
    wire add_rshift_type_wire;
    wire [4:0] rd_wire, rs1_wire, rs2_shamt_wire;
    wire [31:0] imm_wire;

    assign add_rshift_type_wire = funct7[5];

    Decoder decoder(
        instr,
        opcode,
        funct3,
        rd_wire, rs1_wire, rs2_shamt_wire,
        funct7,
        imm_wire
    );

    ALUdec alu_dec(opcode, funct3, add_rshift_type_wire, alu_op_wire);

    regfile regfile (
        .clk(clk),
        .we(we),  //write enable
        .ra1(rs1_wire), .ra2(rs2_shamt_wire), .wa(rd), // address A, address B, and write address
        .wd(wd), //write data
        .rd1(ra), .rd2(rb) // A, B
    );

    always @(posedge clk) begin
        if (stall | bubble) begin
            reg_we <= 1'b0;
            mem_we <= 1'b0;
            mem_rr <= 1'b0;
            csr_write <= 1'b0;
        end else begin
            alu_op <= alu_op_wire;
            add_rshift_type <= add_rshift_type;
            shift_imm <= (opcode == `OPC_ARI_ITYPE) & ((funct3 == `FNC_SLL) | (funct3 == `FNC_SRL_SRA));
            a_sel <= ((opcode == `OPC_JAL) | (opcode == `OPC_AUIPC) | (opcode ==`OPC_BRANCH)) ? 1'b0 
                : ((opcode == `OPC_STORE) | (opcode == `OPC_LOAD) | (opcode == `OPC_ARI_RTYPE) | (opcode == `OPC_ARI_ITYPE)) ? 1'b1
                : 1'bx;
            b_sel <= ((opcode == `OPC_STORE) | (opcode == `OPC_ARI_RTYPE)) ? 1'b0
                : ((opcode == `OPC_LUI) | (opcode == `OPC_AUIPC) | (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_BRANCH) | (opcode == `OPC_LOAD)
                    | (opcode == `OPC_STORE) | (opcode == `OPC_ARI_ITYPE)) ? 1'b1
                : 1'bx;
            reg_we <= (opcode == `OPC_LUI) | (opcode == `OPC_AUIPC) | (opcode == `OPC_JAL) | (opcode == `OPC_JALR) | (opcode == `OPC_LOAD) | (opcode == `OPC_ARI_ITYPE)
                | (opcode == `OPC_ARI_RTYPE);
            mem_we <= opcode == `OPC_STORE;
            mem_rr <= opcode == `OPC_LOAD;
            csr_write <= opcode == `OPC_CSR;
            csr_imm <= funct3 == `FNC_RWI;
            rd <= rd_wire;
            rs1 <= rs1_wire;
            rs2_shamt <= rs2_shamt_wire;
            imm <= imm_wire;
        end
    end
    
endmodule