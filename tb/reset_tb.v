`timescale 1ns/1ps
// Reset must stop writes even when the instruction input is a valid operation.
module reset_tb;
   reg clk = 0, reset = 1;
   reg [31:0] Instr = 32'b0;
   wire [31:0] PC, ALUResult, WriteData;
   wire MemWrite;
   always #5 clk = ~clk;
   Single_Cycle_Core dut (
      .clk(clk), .reset(reset), .Instr(Instr), .ReadData(32'b0),
      .PC(PC), .MemWrite(MemWrite), .ALUResult(ALUResult), .WriteData(WriteData)
   );
   initial begin
      repeat (2) @(negedge clk);
      reset = 0;
      Instr = 32'h00700293; // addi x5,x0,7
      @(negedge clk);
      if (dut.Datapath.Register_inst.REG_MEM_BLOCK[5] !== 7)
         $fatal(1, "setup failed");
      reset = 1;
      Instr = 32'h06300293; // addi x5,x0,99
      repeat (2) @(negedge clk);
      if (PC !== 0 || dut.Datapath.Register_inst.REG_MEM_BLOCK[5] !== 7)
         $fatal(1, "reset allowed register write or PC advance");
      Instr = 32'h00502023; // sw x5,0(x0)
      #1;
      if (MemWrite !== 0) $fatal(1, "reset allowed store");
      @(negedge clk);
      Instr = 32'h340fd073; // csrrwi x0,mscratch,31
      repeat (2) @(negedge clk);
      if (dut.Datapath.CSR_inst.mscratch !== 0 ||
          dut.Datapath.CSR_inst.mcycle !== 0)
         $fatal(1, "reset allowed CSR/counter update");
      reset = 0;
      @(negedge clk);
      if (dut.Datapath.CSR_inst.mscratch !== 31)
         $fatal(1, "CSR write did not resume after reset");
      $display("PASS reset side effects");
      $finish(0);
   end
   initial begin
      #1000;
      $fatal(1, "reset test timeout");
   end
endmodule
