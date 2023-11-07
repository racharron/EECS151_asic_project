module BranchControl (
    input [31:0] A, B,
    input [2:0] funct3,
    output branch
);
    wire less, unsign, inv, less_than, br_equal;
    assign {less, unsign, inv} = funct3;
    assign branch = inv ^ (less ? less_than : br_equal);
    branch_comp bc (
        .unsign(unsign),
        .A(A),
        .B(B),
        .less_than(less_than),
        .br_equal(br_equal)
    );
endmodule
