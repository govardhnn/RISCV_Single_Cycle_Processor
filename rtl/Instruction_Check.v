`timescale 1ns/1ps
// Validate complete encodings before allowing any architectural side effects.
// RV32I + Zicsr + Zifencei, with machine-mode MRET.
module Instruction_Check(input [31:0] Instr, output reg Legal);
   wire [6:0] op = Instr[6:0];
   wire [2:0] f3 = Instr[14:12];
   wire [6:0] f7 = Instr[31:25];
   always @(*) begin
      Legal = 0;
      case (op)
         7'h37, 7'h17, 7'h6f: Legal = 1; // LUI, AUIPC, JAL
         7'h67: Legal = f3 == 0;
         7'h63: Legal = f3 == 0 || f3 == 1 || f3 >= 4;
         7'h03: Legal = f3 == 0 || f3 == 1 || f3 == 2 || f3 == 4 || f3 == 5;
         7'h23: Legal = f3 <= 2;
         7'h13: begin
            case (f3)
               1: Legal = f7 == 0;
               5: Legal = f7 == 0 || f7 == 7'h20;
               default: Legal = 1;
            endcase
         end
         7'h33: Legal = f7 == 0 || (f7 == 7'h20 && (f3 == 0 || f3 == 5));
         // Reserved operand fields are ignored for forward compatibility.
         7'h0f: Legal = f3 == 0 || f3 == 1;
         7'h73: Legal = Instr == 32'h00000073 || Instr == 32'h00100073 ||
                       Instr == 32'h30200073 || f3 == 1 || f3 == 2 || f3 == 3 ||
                       f3 == 5 || f3 == 6 || f3 == 7;
         default: Legal = 0;
      endcase
   end
endmodule
