`timescale 1ns / 1ps
`include "logger.vh"
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

// This register file has two read ports and one write port.
// clk
// Write performed using enable WE3, address WA2 and data WD3
// Read 1 performed using RA1, and collected at RD1
// Read 2 performed using RA2, and collected at RD2

module Register_File(
		     input wire 	clk, WE3,
		     input wire [4:0] 	RA1,RA2,WA3,
		     input wire [31:0] 	WD3,
		     output wire [31:0] RD1,RD2
		     );

   reg [31:0] 				REG_MEM_BLOCK[31:0];

// x0 is hardwired to zero; discard writes as well as forcing reads.
   always@(posedge clk)
     begin
	if(WE3 && WA3 != 0) begin
	   REG_MEM_BLOCK[WA3] <= WD3;
`ifdef DEBUG_LOG
	   `LOG_INFO(("[RegFile   ] x%0d <= 0x%08h", WA3, WD3))
`endif
	end
     end

// This is the benefit of the RISC-V ISA specifying that the R0 is always hardcoded to 0
// If RA1 or RA2 is 0, then the data is always 0
   assign RD1 = (RA1 != 0) ? REG_MEM_BLOCK[RA1] : 0;
   assign RD2 = (RA2 != 0) ? REG_MEM_BLOCK[RA2] : 0;

endmodule
