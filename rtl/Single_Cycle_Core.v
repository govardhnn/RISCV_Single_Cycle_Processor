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
module Single_Cycle_Core(
			 input wire 	    clk, reset,
			 input wire [31:0]  Instr,
			 input wire [31:0]  ReadData,
			 output wire [31:0] PC,
			 output wire 	    MemWrite,
			 output wire [31:0] ALUResult, WriteData
			 );

   wire        MemWriteDecoded, Trap;
   assign MemWrite = MemWriteDecoded & ~reset & ~Trap;

   wire        ALUSrc, RegWrite, Jump, Zero, PCSrc, LT, LTU;
   wire        PCSrcA, CSRWrite, CSRSrc;
   wire [1:0]  ResultSrc;
   wire [2:0]  ImmSrc;
   wire [3:0]  ALUControl;

   Control_Unit Control (
			  .op(Instr[6:0]),
			  .funct3(Instr[14:12]),
			  .funct7b5(Instr[30]),
			  .Zero(Zero),
			  .LT(LT),
			  .LTU(LTU),
			  .ResultSrc(ResultSrc),
			  .MemWrite(MemWriteDecoded),
			  .PCSrc(PCSrc),
			  .ALUSrc(ALUSrc),
			  .RegWrite(RegWrite),
			  .Jump(Jump),
			  .PCSrcA(PCSrcA),
			  .CSRWrite(CSRWrite),
			  .CSRSrc(CSRSrc),
			  .ImmSrc(ImmSrc),
			  .ALUControl(ALUControl)
			  );

   Core_Datapath Datapath (
			    .clk(clk),
			    .reset(reset),
			    .ResultSrc(ResultSrc),
			    .PCSrc(PCSrc),
			    .ALUSrc(ALUSrc),
			    .RegWrite(RegWrite),
			    .PCSrcA(PCSrcA),
			    .CSRWrite(CSRWrite),
			    .CSRSrc(CSRSrc),
			    .ImmSrc(ImmSrc),
			    .ALUControl(ALUControl),
			    .Instr(Instr),
			    .ReadData(ReadData),
			    .Zero(Zero),
			    .LT(LT),
			    .LTU(LTU),
			    .PC(PC),
			    .ALUResult(ALUResult),
			    .WriteData(WriteData),
                            .Trap(Trap)
			    );

endmodule
