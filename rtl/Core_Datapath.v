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

module Core_Datapath(
		     input	    clk, reset,
		     input [1:0]    ResultSrc,
		     input	    PCSrc, ALUSrc,
		     input	    RegWrite,
		     input	    PCSrcA,          // 0=rs1, 1=PC (for AUIPC)
		     input	    CSRWrite,
		     input	    CSRSrc,          // 0=rs1, 1=zimm (for CSR immediate variants)
		     input [2:0]    ImmSrc,
		     input [3:0]    ALUControl,
		     input [31:0]   Instr,
		     input [31:0]   ReadData,

		     output	    Zero,
		     output         LT,
		     output         LTU,
                     output         Trap,
		     output [31:0]  PC,
		     output [31:0]  ALUResult, WriteData
		     );

   wire [31:0] PCnext, PCplus4, PCtarget, BranchTarget, NormalNext;
   wire [31:0] TrapVector, ExceptionPC;
   wire Legal, CSRIllegal;
   wire IsJALR = Instr[6:0] == 7'b1100111;
   wire IsMRET = Instr == 32'h30200073;
   wire IsLoad = Instr[6:0] == 7'b0000011;
   wire IsStore = Instr[6:0] == 7'b0100011;
   wire CSRWriteEnable = CSRWrite &&
        ((Instr[13:12] == 2'b01) || (Instr[19:15] != 0));
   reg Exception;
   reg [31:0] Cause, TrapValue;
   assign Trap = Exception && !reset;
   assign PCtarget = IsJALR ? {ALUResult[31:1], 1'b0} : BranchTarget;
   assign PCnext = Trap ? TrapVector : IsMRET ? ExceptionPC : NormalNext;

   Instruction_Check Check_inst (.Instr(Instr), .Legal(Legal));

   // Suppress every architectural write on an exception. Branch alignment
   // matters only when the branch is taken (IALIGN=32, no compressed ISA).
   always @(*) begin
      Exception = 1'b0;
      Cause = 0;
      TrapValue = 0;
      if (!Legal || (CSRWrite && CSRIllegal)) begin
         Exception = 1; Cause = 2; TrapValue = Instr;
      end else if (Instr == 32'h00000073) begin
         Exception = 1; Cause = 11; // ECALL from machine mode
      end else if (Instr == 32'h00100073) begin
         Exception = 1; Cause = 3; TrapValue = PC;
      end else if (PCSrc && PCtarget[1:0] != 0) begin
         Exception = 1; Cause = 0; TrapValue = PCtarget;
      end else if ((IsLoad || IsStore) &&
                   (((Instr[13:12] == 2'b01) && ALUResult[0]) ||
                    ((Instr[13:12] == 2'b10) && ALUResult[1:0] != 0))) begin
         Exception = 1; Cause = IsStore ? 6 : 4; TrapValue = ALUResult;
      end
   end
   wire [31:0] ImmExt;
   wire [31:0] RD1;                          // raw rs1 from register file
   wire [31:0] SrcA, SrcB;
   wire [31:0] Result;
   wire [31:0] CSRReadData;
   wire [31:0] CSRWriteData;

   PC PC_inst (
	       .clk(clk),
	       .reset(reset),
	       .PCNext(PCnext),
	       .PC(PC)
	       );

   PC_Plus_4 PCPlus4_inst (
			   .PC(PC),
			   .PCPlus4(PCplus4)
			   );

   PC_Target PCTarget_inst (
			    .PC(PC),
			    .ImmExt(ImmExt),
			    .PCTarget(BranchTarget)
			    );

   PC_Mux PCmux_inst (
		      .PC_Plus_4(PCplus4),
		      .PC_Target(PCtarget),
		      .PCSrc(PCSrc),
		      .PC_Next(NormalNext)
		      );

   Register_File Register_inst (
				 .clk(clk),
				 .WE3(RegWrite && !reset && !Trap),
				 .RA1(Instr[19:15]),
				 .RA2(Instr[24:20]),
				 .WA3(Instr[11:7]),
				 .WD3(Result),
				 .RD1(RD1),
				 .RD2(WriteData)
				 );

   Extend Extend_inst (
		       .Instr(Instr[31:7]),
		       .ImmSrc(ImmSrc),
		       .ImmExt(ImmExt)
		       );

   // SrcA mux: select PC for AUIPC, rs1 for everything else
   assign SrcA = PCSrcA ? PC : RD1;

   // CSR write data mux: zimm (zero-extended rs1 field) or rs1 register value
   assign CSRWriteData = CSRSrc ? {27'b0, Instr[19:15]} : RD1;

   ALU_Mux ALU_Mux_inst (
			  .WD(WriteData),
			  .ImmExt(ImmExt),
			  .ALUSrc(ALUSrc),
			  .B(SrcB)
			  );

   ALU ALU_inst (
		 .A(SrcA),
		 .B(SrcB),
		 .ALUControl(ALUControl),
		 .Zero(Zero),
		 .LT(LT),
		 .LTU(LTU),
		 .Result(ALUResult)
		 );

   CSR_File CSR_inst (
		      .clk(clk),
		      .reset(reset),
                      .Access(CSRWrite),
                      .WE(CSRWriteEnable),
                      .Trap(Trap),
                      .MRET(IsMRET),
                      .PC(PC),
                      .Cause(Cause),
                      .TrapValue(TrapValue),
                      .Illegal(CSRIllegal),
                      .TrapVector(TrapVector),
                      .ExceptionPC(ExceptionPC),
		      .funct3(Instr[14:12]),
		      .CSRAddr(Instr[31:20]),
		      .WD(CSRWriteData),
		      .RD(CSRReadData)
		      );

   // Instruction trace — fires each cycle with the PC and raw instruction word.
   // Set LOG_LEVEL=4 (DEBUG) to also see load/CSR read results.
`ifdef DEBUG_LOG
   always @(posedge clk) begin
      if (!reset) begin
	 `LOG_INFO(("[Core      ] PC=0x%08h  INSTR=0x%08h  op=%07b  funct3=%03b  funct7b=%b",
	             PC, Instr, Instr[6:0], Instr[14:12], Instr[30]))
	 if (ResultSrc == 2'b01)
	   `LOG_DEBUG(("[Core      ] LOAD  result=0x%08h  from addr=0x%08h", ReadData, ALUResult))
	 if (ResultSrc == 2'b11)
	   `LOG_DEBUG(("[Core      ] CSR   read=0x%08h  csr_addr=0x%03h", CSRReadData, Instr[31:20]))
      end
   end
`endif

   Result_Mux Result_Mux_inst (
			        .ALUResult(ALUResult),
			        .ReadData(ReadData),
			        .PC_Plus_4(PCplus4),
			        .CSRReadData(CSRReadData),
			        .ResultSrc(ResultSrc),
			        .Result(Result)
			        );

endmodule
