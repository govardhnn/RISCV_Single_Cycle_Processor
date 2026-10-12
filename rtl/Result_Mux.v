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

// ResultSrc encoding:
//   00 = ALUResult  (R-type, I-type, LUI, AUIPC, branches)
//   01 = ReadData   (loads)
//   10 = PC+4       (JAL, JALR)
//   11 = CSRReadData (CSR instructions)

module Result_Mux (
		   input wire [31:0]  ALUResult, ReadData, PC_Plus_4, CSRReadData,
		   input wire [1:0]   ResultSrc,
		   output wire [31:0] Result
		   );

   assign Result = (ResultSrc == 2'b11) ? CSRReadData :
                    ResultSrc[1]         ? PC_Plus_4   :
                    ResultSrc[0]         ? ReadData     : ALUResult;

endmodule
