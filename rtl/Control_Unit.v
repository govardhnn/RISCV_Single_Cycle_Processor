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
module Control_Unit(
		    input wire [6:0]  op,
		    input wire [2:0]  funct3,
		    input wire	      funct7b5, Zero, LT, LTU,

		    output wire [1:0] ResultSrc,
		    output wire	      MemWrite, PCSrc, ALUSrc, RegWrite, Jump, PCSrcA, CSRWrite,
		    output wire	      CSRSrc,    // 0=rs1, 1=zimm (funct3[2])
		    output wire [2:0] ImmSrc,
		    output wire [3:0] ALUControl
		    );

   wire [1:0] ALUop;
   wire       Branch;

   Main_Decoder Main_Decoder(
			      .op(op),
			      .funct3(funct3),
			      .ResultSrc(ResultSrc),
			      .MemWrite(MemWrite),
			      .Branch(Branch),
			      .ALUSrc(ALUSrc),
			      .RegWrite(RegWrite),
			      .Jump(Jump),
			      .PCSrcA(PCSrcA),
			      .CSRWrite(CSRWrite),
			      .ImmSrc(ImmSrc),
			      .ALUop(ALUop) );

   ALU_Decoder ALU_Decoder(
			    .opb5(op[5]),
			    .funct3(funct3),
			    .funct7b5(funct7b5),
			    .ALUOp(ALUop),
			    .ALUControl(ALUControl) );

   // CSRSrc: funct3[2]=1 selects zero-extended 5-bit zimm (CSRRWI/CSRRSI/CSRRCI)
   //         funct3[2]=0 selects rs1 register value  (CSRRW/CSRRS/CSRRC)
   assign CSRSrc = funct3[2];

   // Branch condition based on funct3:
   //   funct3[2:1]: 00=Zero (BEQ/BNE), 10=LT (BLT/BGE), 11=LTU (BLTU/BGEU)
   //   funct3[0]:   0=normal, 1=invert condition (BNE, BGE, BGEU)
   wire BranchCond;
   assign BranchCond = (funct3[2:1] == 2'b00) ? Zero :
                       (funct3[2:1] == 2'b10) ? LT   : LTU;
   assign PCSrc = (Branch & (BranchCond ^ funct3[0])) | Jump;

endmodule
