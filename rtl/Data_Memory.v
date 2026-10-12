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

module Data_Memory #(
                           parameter WORDS = 64,
                           parameter INIT_FILE = ""
                           )(
		   input wire 	      clk, WE,
		   input wire [2:0]   funct3,
		   input wire [31:0]  A, WD,
		   input wire [31:0]  IA,
                           output wire [31:0] Instr,
                           output wire [31:0] RD
		   );

   reg [31:0] 			      RAM[0:WORDS-1];

   localparam INDEX_BITS = WORDS > 1 ? $clog2(WORDS) : 1;
   wire [INDEX_BITS-1:0] DataIndex = A[INDEX_BITS+1:2];
   wire [INDEX_BITS-1:0] InstrIndex = IA[INDEX_BITS+1:2];
   integer i;
   initial begin
      for (i = 0; i < WORDS; i = i + 1) RAM[i] = 0;
      if (INIT_FILE != "") $readmemh(INIT_FILE, RAM);
   end

   // Shared, uncached instruction/data storage. Clocked stores are visible
   // to the next instruction fetch, so FENCE.I needs no extra hardware.
   assign Instr = IA[31:2] < WORDS ? RAM[InstrIndex] : 32'b0;

   // Read with byte/halfword extraction and sign/zero extension
   reg [31:0] RDreg;
   always @(*) begin
      if (A[31:2] >= WORDS) RDreg = 0;
      else case (funct3)
        3'b000: // LB - sign-extended byte
          case (A[1:0])
            2'b00: RDreg = {{24{RAM[DataIndex][7]}},  RAM[DataIndex][7:0]};
            2'b01: RDreg = {{24{RAM[DataIndex][15]}}, RAM[DataIndex][15:8]};
            2'b10: RDreg = {{24{RAM[DataIndex][23]}}, RAM[DataIndex][23:16]};
            2'b11: RDreg = {{24{RAM[DataIndex][31]}}, RAM[DataIndex][31:24]};
          endcase
        3'b001: // LH - sign-extended halfword
          case (A[1])
            1'b0: RDreg = {{16{RAM[DataIndex][15]}}, RAM[DataIndex][15:0]};
            1'b1: RDreg = {{16{RAM[DataIndex][31]}}, RAM[DataIndex][31:16]};
          endcase
        3'b100: // LBU - zero-extended byte
          case (A[1:0])
            2'b00: RDreg = {24'b0, RAM[DataIndex][7:0]};
            2'b01: RDreg = {24'b0, RAM[DataIndex][15:8]};
            2'b10: RDreg = {24'b0, RAM[DataIndex][23:16]};
            2'b11: RDreg = {24'b0, RAM[DataIndex][31:24]};
          endcase
        3'b101: // LHU - zero-extended halfword
          case (A[1])
            1'b0: RDreg = {16'b0, RAM[DataIndex][15:0]};
            1'b1: RDreg = {16'b0, RAM[DataIndex][31:16]};
          endcase
        default: RDreg = RAM[DataIndex]; // LW - full word
      endcase
   end
   assign RD = RDreg;

   // Write with byte/halfword lane enables
   always @(posedge clk) begin
      if (WE && A[31:2] < WORDS) begin
         case (funct3)
           3'b000: begin // SB
             case (A[1:0])
               2'b00: RAM[DataIndex][7:0]   <= WD[7:0];
               2'b01: RAM[DataIndex][15:8]  <= WD[7:0];
               2'b10: RAM[DataIndex][23:16] <= WD[7:0];
               2'b11: RAM[DataIndex][31:24] <= WD[7:0];
             endcase
`ifdef DEBUG_LOG
             `LOG_INFO(("[DataMem   ] WRITE SB  addr=0x%08h  data=0x%02h", A, WD[7:0]))
`endif
           end
           3'b001: begin // SH
             case (A[1])
               1'b0: RAM[DataIndex][15:0]  <= WD[15:0];
               1'b1: RAM[DataIndex][31:16] <= WD[15:0];
             endcase
`ifdef DEBUG_LOG
             `LOG_INFO(("[DataMem   ] WRITE SH  addr=0x%08h  data=0x%04h", A, WD[15:0]))
`endif
           end
           default: begin // SW
             RAM[DataIndex] <= WD;
`ifdef DEBUG_LOG
             `LOG_INFO(("[DataMem   ] WRITE SW  addr=0x%08h  data=0x%08h", A, WD))
`endif
           end
         endcase
      end
   end

`ifdef DEBUG_LOG
   // Log combinational reads at posedge for load instructions.
   // Reads are always live; this fires whenever address/funct3 settle — use DEBUG level.
   always @(posedge clk) begin
      if (!WE) begin
         case (funct3)
           3'b000: `LOG_DEBUG(("[DataMem   ] READ  LB   addr=0x%08h  data=0x%08h", A, RDreg))
           3'b001: `LOG_DEBUG(("[DataMem   ] READ  LH   addr=0x%08h  data=0x%08h", A, RDreg))
           3'b010: `LOG_DEBUG(("[DataMem   ] READ  LW   addr=0x%08h  data=0x%08h", A, RDreg))
           3'b100: `LOG_DEBUG(("[DataMem   ] READ  LBU  addr=0x%08h  data=0x%08h", A, RDreg))
           3'b101: `LOG_DEBUG(("[DataMem   ] READ  LHU  addr=0x%08h  data=0x%08h", A, RDreg))
           default: ;
         endcase
      end
   end
`endif

endmodule
