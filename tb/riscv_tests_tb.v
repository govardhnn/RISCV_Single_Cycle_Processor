`timescale 1ns/1ps
// Top-level testbench for running riscv-tests ISA tests against
// Single_Cycle_Top, including the production unified memory.
//
// Usage (iverilog / vvp):
//   make sim
//   vvp sim/riscv_tests_sim +HEXFILE=path/to/test.hex
//
// Pass/fail is determined by writes to TOHOST_ADDR (0x1000):
//   WriteData == 1          → PASS
//   WriteData == N<<1|1     → FAIL, failing test number = N

module riscv_tests_tb;

  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  parameter MEM_WORDS   = 16384;         // 64 KB (word-addressed)
  parameter TOHOST_ADDR = 32'h0000_1000; // .tohost section base address
  parameter TIMEOUT_CYC = 1_000_000;     // give up after 1 M cycles

  // -------------------------------------------------------------------------
  // Clock and reset
  // -------------------------------------------------------------------------
  reg clk = 0, reset = 1;
  always #5 clk = ~clk; // 100 MHz

  // -------------------------------------------------------------------------
  // Memories
  // -------------------------------------------------------------------------
  wire [31:0] PC, ALUResult, WriteData;
  wire MemWrite;

  Single_Cycle_Top #(.MEM_WORDS(MEM_WORDS), .INIT_FILE("")) dut (
    .clk(clk), .reset(reset), .MemWrite(MemWrite),
    .DataAddr(ALUResult), .WriteData(WriteData)
  );
  assign PC = dut.PC;

  // -------------------------------------------------------------------------
  // tohost monitor — fires on the clock edge when the test writes its result
  // -------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!reset && MemWrite && ALUResult == TOHOST_ADDR) begin
      if (WriteData == 32'h1)
        $display("PASS");
      else
        $fatal(1, "FAIL (test %0d)", WriteData >> 1);
      $finish(0);
    end
  end

  // -------------------------------------------------------------------------
  // Initialisation: zero memories, load hex, deassert reset
  // -------------------------------------------------------------------------
  reg [8*256-1:0] hexfile;
  initial begin
    #1; // Let the memory module initialize before loading the image.

    if (!$value$plusargs("HEXFILE=%s", hexfile)) begin
      $fatal(1, "ERROR: +HEXFILE=<path> is required");
    end

    $readmemh(hexfile, dut.Data_Memory.RAM);

    // Hold reset for two clock edges, then release
    @(posedge clk); @(posedge clk);
    @(negedge clk);
    reset = 0;
  end

  // -------------------------------------------------------------------------
  // Timeout watchdog
  // -------------------------------------------------------------------------
  initial begin
    repeat (TIMEOUT_CYC) @(posedge clk);
    $fatal(1, "TIMEOUT PC=%08h", PC);
  end

endmodule
