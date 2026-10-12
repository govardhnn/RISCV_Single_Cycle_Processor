`timescale 1ns/1ps
// Run upstream benchmark binaries against the actual top module and memory.
// Implements the HTIF console/exit protocol used by common/syscalls.c.
module benchmarks_tb;
   localparam MEM_WORDS = 131072; // 512 KiB; must match tests/benchmarks/link.ld
   reg clk = 0, reset = 1;
   always #5 clk = ~clk;
   wire [31:0] WriteData, DataAddr;
   wire MemWrite;
   Single_Cycle_Top #(.MEM_WORDS(MEM_WORDS), .INIT_FILE("")) dut (
      .clk(clk), .reset(reset), .WriteData(WriteData),
      .DataAddr(DataAddr), .MemWrite(MemWrite)
   );
   string hexfile;
   reg [31:0] tohost_addr, fromhost_addr;
   longint unsigned cycles = 0, max_cycles = 100000000;
   reg [31:0] command, buffer_addr, length, descriptor;
   reg [31:0] byte_word;
   integer i;

   initial begin
      if (!$value$plusargs("HEXFILE=%s", hexfile) ||
          !$value$plusargs("TOHOST=%h", tohost_addr) ||
          !$value$plusargs("FROMHOST=%h", fromhost_addr))
         $fatal(1, "HEXFILE, TOHOST, and FROMHOST are required");
      if ($value$plusargs("MAX_CYCLES=%d", max_cycles)) begin end
      if (tohost_addr[2:0] != 0 || fromhost_addr[2:0] != 0 ||
          tohost_addr >= MEM_WORDS*4-8 || fromhost_addr >= MEM_WORDS*4-8)
         $fatal(1, "invalid HTIF addresses");
      #1;
      $readmemh(hexfile, dut.Data_Memory.RAM);
      repeat (2) @(negedge clk);
      reset = 0;
   end

   always @(posedge clk) begin
      if (!reset) begin
         cycles <= cycles + 1;
         if (cycles >= max_cycles) $fatal(1, "TIMEOUT PC=%08h", dut.PC);
         if (dut.PC >= MEM_WORDS*4) $fatal(1, "instruction address out of bounds");
         if ((dut.Instr[6:0] == 7'h03 || dut.Instr[6:0] == 7'h23) &&
             DataAddr >= MEM_WORDS*4)
            $fatal(1, "data address out of bounds: PC=%08h address=%08h", dut.PC, DataAddr);
         if (dut.core_top.Trap)
            $fatal(1, "unexpected trap PC=%08h instruction=%08h cause=%0d",
                   dut.PC, dut.Instr, dut.core_top.Datapath.Cause);
      end
   end

   // Service the host mailbox between CPU edges, after stores have committed.
   always @(negedge clk) begin
      if (!reset) begin
         command = dut.Data_Memory.RAM[tohost_addr >> 2];
         if (command != 0) begin
            if (command[0]) begin
               if (command != 1) $fatal(1, "FAIL exit=%0d", command >> 1);
               $display("\nPASS cycles=%0d instret=%0d", cycles,
                        dut.core_top.Datapath.CSR_inst.minstret);
               $finish;
            end else begin
               if (command[2:0] != 0 || command > MEM_WORDS*4-64)
                  $fatal(1, "invalid HTIF descriptor %08h", command);
               descriptor = command >> 2;
               // Eight uint64_t arguments, laid out as sixteen RV32 words.
               if (dut.Data_Memory.RAM[descriptor] != 64 ||
                   dut.Data_Memory.RAM[descriptor+2] != 1)
                  $fatal(1, "unsupported HTIF syscall");
               buffer_addr = dut.Data_Memory.RAM[descriptor+4];
               length = dut.Data_Memory.RAM[descriptor+6];
               if (buffer_addr >= MEM_WORDS*4 || length > MEM_WORDS*4-buffer_addr)
                  $fatal(1, "HTIF buffer out of bounds");
               for (i = 0; i < length; i = i + 1) begin
                  byte_word = dut.Data_Memory.RAM[(buffer_addr+32'(i)) >> 2];
                  $write("%c", 8'(byte_word >> (8*((buffer_addr+32'(i)) & 3))));
               end
               dut.Data_Memory.RAM[descriptor] = length;
               dut.Data_Memory.RAM[descriptor+1] = 0;
               dut.Data_Memory.RAM[tohost_addr >> 2] = 0;
               dut.Data_Memory.RAM[(tohost_addr >> 2)+1] = 0;
               dut.Data_Memory.RAM[fromhost_addr >> 2] = 1;
               dut.Data_Memory.RAM[(fromhost_addr >> 2)+1] = 0;
            end
         end
      end
   end
endmodule
