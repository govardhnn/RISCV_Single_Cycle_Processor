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

// Minimal machine-only CSR bank. No external interrupts or lower privilege
// modes: MPP is fixed to M, mie/mip read as zero, mtvec uses direct mode.
module CSR_File (
   input clk, reset, Access, WE, Trap, MRET,
   input [2:0] funct3,
   input [11:0] CSRAddr,
   input [31:0] WD, PC, Cause, TrapValue,
   output reg [31:0] RD,
   output Illegal,
   output [31:0] TrapVector, ExceptionPC
);
   reg [31:0] mstatus, mtvec, mscratch, mepc, mcause, mtval;
   reg [63:0] mcycle, minstret;
   reg [2:0] mcountinhibit;
   reg Known;
   reg [31:0] NewValue;

   assign TrapVector = mtvec;
   assign ExceptionPC = mepc;
   assign Illegal = Access && (!Known || (WE && CSRAddr[11:10] == 2'b11));

   always @(*) begin
      Known = 1;
      case (CSRAddr)
         12'h300: RD = mstatus;
         12'h301: RD = 32'h40000100; // RV32, I extension; fixed WARL value
         12'h304, 12'h310, 12'h344: RD = 0; // mie, mstatush, mip
         12'h305: RD = mtvec;
         12'h320: RD = {29'b0, mcountinhibit};
         12'h340: RD = mscratch;
         12'h341: RD = mepc;
         12'h342: RD = mcause;
         12'h343: RD = mtval;
         12'hb00, 12'hc00: RD = mcycle[31:0];
         12'hb80, 12'hc80: RD = mcycle[63:32];
         12'hb02, 12'hc02: RD = minstret[31:0];
         12'hb82, 12'hc82: RD = minstret[63:32];
         12'hf11, 12'hf12, 12'hf13, 12'hf14, 12'hf15: RD = 0;
         default: begin RD = 0; Known = 0; end
      endcase
      case (funct3[1:0])
         2'b01: NewValue = WD;
         2'b10: NewValue = RD | WD;
         2'b11: NewValue = RD & ~WD;
         default: NewValue = RD;
      endcase
   end

   always @(posedge clk or posedge reset) begin
      if (reset) begin
         mstatus <= 32'h00001800;
         mtvec <= 0;
         mscratch <= 0;
         mepc <= 0;
         mcause <= 0;
         mtval <= 0;
         mcycle <= 0;
         minstret <= 0;
         mcountinhibit <= 0;
      end else begin
         if (!mcountinhibit[0]) mcycle <= mcycle + 64'd1;
         if (!mcountinhibit[2] && !Trap) minstret <= minstret + 64'd1;
         if (Trap) begin
            mepc <= {PC[31:2], 2'b00};
            mcause <= Cause;
            mtval <= TrapValue;
            mstatus[7] <= mstatus[3]; // MPIE <- MIE
            mstatus[3] <= 0;
         end else if (MRET) begin
            mstatus[3] <= mstatus[7];
            mstatus[7] <= 1;
         end else if (Access && WE && !Illegal) begin
            case (CSRAddr)
               12'h300: mstatus <= (NewValue & 32'h00000088) | 32'h00001800;
               12'h305: mtvec <= {NewValue[31:2], 2'b00};
               12'h320: mcountinhibit <= NewValue[2:0] & 3'b101;
               12'h340: mscratch <= NewValue;
               12'h341: mepc <= {NewValue[31:2], 2'b00};
               12'h342: mcause <= NewValue;
               12'h343: mtval <= NewValue;
               // An explicit counter write overrides this instruction's increment.
               12'hb00: mcycle <= {mcycle[63:32], NewValue};
               12'hb80: mcycle <= {NewValue, mcycle[31:0]};
               12'hb02: minstret <= {minstret[63:32], NewValue};
               12'hb82: minstret <= {NewValue, minstret[31:0]};
               default: ; // Fixed WARL CSRs ignore writes.
            endcase
         end
      end
   end
endmodule
