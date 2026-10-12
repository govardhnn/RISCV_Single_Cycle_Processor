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

// Control signal encoding (14 bits):
// RegWrite_ImmSrc[2:0]_ALUSrc_MemWrite_ResultSrc[1:0]_Branch_ALUop[1:0]_Jump_PCSrcA_CSRWrite
//
// ImmSrc: 000=I-type  001=S-type  010=B-type  011=J-type  100=U-type
// ResultSrc: 00=ALUResult  01=MemReadData  10=PC+4  11=CSRReadData
// ALUop:     00=add  01=sub  10=R/I-type  11=LUI
// PCSrcA:    0=rs1   1=PC  (selects ALU SrcA for AUIPC)
// CSRWrite:  1=write CSR register file

module Main_Decoder(
		    input wire [6:0]  op,
		    input wire [2:0]  funct3,
		    output wire [1:0] ResultSrc,
		    output wire       MemWrite, Branch, ALUSrc, RegWrite, Jump, PCSrcA, CSRWrite,
		    output wire [2:0] ImmSrc,
		    output wire [1:0] ALUop
		    );

   reg [13:0] control_signals;

   always@(*) begin
      case(op)
	//                RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUop_Jump_PCSrcA_CSRWrite
	7'b0000011: control_signals = 14'b1_000_1_0_01_0_00_0_0_0; // loads  (LB/LH/LW/LBU/LHU)
	7'b0100011: control_signals = 14'b0_001_1_1_00_0_00_0_0_0; // stores (SB/SH/SW)
	7'b0110011: control_signals = 14'b1_000_0_0_00_0_10_0_0_0; // R-type
	7'b0010011: control_signals = 14'b1_000_1_0_00_0_10_0_0_0; // I-type ALU
	7'b1100011: control_signals = 14'b0_010_0_0_00_1_01_0_0_0; // B-type branches
	7'b1101111: control_signals = 14'b1_011_0_0_10_0_00_1_0_0; // JAL
	7'b1100111: control_signals = 14'b1_000_1_0_10_0_00_1_0_0; // JALR
	7'b0110111: control_signals = 14'b1_100_1_0_00_0_11_0_0_0; // LUI
	7'b0010111: control_signals = 14'b1_100_1_0_00_0_00_0_1_0; // AUIPC (ALUop=add, SrcA=PC)
	7'b0001111: control_signals = 14'b0_000_0_0_00_0_00_0_0_0; // FENCE/FENCE.I: ordered, uncached memory
	7'b1110011: // ECALL/EBREAK/CSR
	  if (funct3 == 3'b000)
	    control_signals = 14'b0_000_0_0_00_0_00_0_0_0; // ECALL/EBREAK/MRET handled by trap logic
	  else
	    control_signals = 14'b1_000_0_0_11_0_00_0_0_1; // CSR (rd <- CSR, CSR <- op(CSR,rs1/zimm))
	7'b0000000: control_signals = 14'b0_000_0_0_00_0_00_0_0_0; // reset condition
	default:    control_signals = 14'b0_000_0_0_00_0_00_0_0_0;
      endcase
   end

   assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
	   ResultSrc, Branch, ALUop, Jump, PCSrcA, CSRWrite} = control_signals;

endmodule
