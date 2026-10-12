`timescale 1ns / 1ps
/*
 * Copyright (c) 2023 Govardhan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

module ALU(
	   input wire signed [31:0]  A,B, // made it signed for sra to work
	   input wire signed [3:0]   ALUControl,
	   output wire signed	     Zero,
	   output wire		     LT,
	   output wire		     LTU,
	   output wire signed [31:0] Result );

   reg [31:0]			     ResultReg;
   wire [31:0]			     temp,Sum;
   wire				     V,slt, sltu; //overflow

   //~B if ALUControl[0] is set 1 for subtraction (R Type]
   assign temp = ALUControl[0] ? ~B:B;
   //Sum is addition of A + B + 0 or
   //Sum is subtraction of A + ~B + 1 <2's complement>
   assign Sum = A + temp + {31'b0, ALUControl[0]};
   //checks for overflow if result has different sign than operands
   assign V = (ALUControl[0]) ? 
              (~(A[31] ^ B[31]) & (A[31] ^ Sum[31])) : // to check for addition - (operands same sign)&(result has diff sign than A)
              ((A[31] ^ B[31]) & (~(A[31] ^ Sum[31]))); // to check for subtraction - (operands have diff sign)&(result has same sign as A)  
   assign slt = (A[31] == B[31]) ? (A < B) : A[31]; // because for signed numbers, of both are of same sign, we can compare A and B, but if they are of different sign we can take the MSB of A
   //if A is positive and B is negative => A is not less than B, slt = 0 ie. A[31]
   //if A is negative and B is positive -> A is definitely lass than B, so slt = 1 ie. A[31]
   
   assign sltu = $unsigned(A) < $unsigned(B); //unsigned comparison
   

   always@(*)
     case(ALUControl)
       4'b0000: ResultReg = Sum; //add
       4'b0001: ResultReg = Sum; //sub
       4'b0010: ResultReg = A&B; //and
       4'b0011: ResultReg = A|B; //or
       4'b0100: ResultReg = A^B; //xor
       
       4'b0101: ResultReg = {31'b0,slt}; //slt
       4'b0110: ResultReg = {31'b0,sltu}; // sltu
       4'b0111: ResultReg = {A[31:12],12'b0}; //lui
       4'b1000: ResultReg = A + {B[31:12],12'b0}; // AUIPC
       4'b1001: ResultReg = {B[31:12],12'b0}; // LUI
       
       4'b1010: ResultReg = A << B[4:0]; // sll, slli
       4'b1011: ResultReg = A >>> B[4:0]; // sra
       4'b1100: ResultReg = A >> B[4:0]; // srl
       
       //to add sll, slli,
       //to add sra
       default:  ResultReg = 'bx;

     endcase

   assign Zero   = (ResultReg == 32'b0);
   assign LT     = slt;
   assign LTU    = sltu;
   assign Result = ResultReg;

endmodule
