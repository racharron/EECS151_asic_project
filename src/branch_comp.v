module branch_comp (
  input unsign,
  input [31:0] A,
  input [31:0] B,
  output less_than,
  output br_equal
);
  assign br_equal = A == B;
  assign less_than = unsign ? A < B : $signed(A) < $signed(B);
endmodule