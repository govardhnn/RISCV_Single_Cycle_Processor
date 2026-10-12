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

module Extend(
	      input wire [31:7]  Instr,
	      input wire [2:0] 	 ImmSrc,
	      output wire [31:0] ImmExt );

   reg [31:0] 			 ImmExtReg;

   always@(*)
     case(ImmSrc)
       //I-type
       3'b000: ImmExtReg = {{20{Instr[31]}},Instr[31:20]};
       //S-type(stores)
       3'b001: ImmExtReg = {{20{Instr[31]}},Instr[31:25],Instr[11:7]};
       //B-type(branches)
       3'b010: ImmExtReg = {{20{Instr[31]}},Instr[7],Instr[30:25],Instr[11:8],1'b0};
       //J-type(jal)
       3'b011: ImmExtReg = {{12{Instr[31]}},Instr[19:12],Instr[20],Instr[30:21],1'b0};
       //U-type(lui, auipc): upper 20 bits shifted to [31:12]
       3'b100: ImmExtReg = {Instr[31:12],12'b0};
       default: ImmExtReg = 32'bx; //undefined
     endcase
   
   assign ImmExt = ImmExtReg;

endmodule
