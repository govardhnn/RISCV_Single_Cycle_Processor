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
module ALU_Decoder(
		   input wire	    opb5, //bit 5 of the opcode
		   input wire [2:0] funct3, // instr[14:12]
		   input wire	    funct7b5, // bit 30 of instruction
		   input wire [1:0] ALUOp,
		   output reg [3:0] ALUControl
		   );

   wire				    RtypeSub;
   assign RtypeSub = funct7b5 & opb5; //TRUE for R-type substract

   always@(*)
     begin
	case(ALUOp)
          2'b00:  ALUControl = 4'b0000; //addition
          2'b01:  ALUControl = 4'b0001; //subtraction or auipc
          2'b10: //ALUOp = 2'b10 and beyond
            case(funct3)//R-type or I-type ALU
              3'b000:    
                if (RtypeSub) ALUControl = 4'b0001; //sub
                else ALUControl = 4'b0000; //add,addi
                3'b001: ALUControl = 4'b1010; // sll, slli;
              3'b010: ALUControl = 4'b0101; //slt,slti
              3'b011: ALUControl = 4'b0110; //sltu, sltui
              3'b100: ALUControl = 4'b0100; //xor
              3'b101: 
                if (funct7b5) ALUControl = 4'b1011; //sra
                else ALUControl = 4'b1100; // srl
               
              3'b110: ALUControl = 4'b0011; //or,ori
              3'b111: ALUControl = 4'b0010; //and,andi
              default: ALUControl = 4'bxxx; 
            endcase
          2'b11: ALUControl = 4'b1001; // LUI: {B[31:12],12'b0} where B is U-type imm
          default: ALUControl = 4'bxxxx;
          //ALU Control
          //3'b000 = addition (add, addi)
          //3'b001 = subtraction (sub)
          //3'b010 = and (and, andi)
          //3'b011 = or (or, ori)
          //3'b100 = xor (xor, xori)
          //3'b101 = set less than (slt, slti)
          //3'b110 = set less than unsigned (sltu, sltui)
	endcase
     end

endmodule
