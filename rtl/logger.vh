// logger.vh — Unified simulation logger for the RISC-V Single-Cycle Processor
//
// Enable logging by compiling with DEBUG_LOG defined:
//   iverilog -DDEBUG_LOG ...
//   or add `define DEBUG_LOG before the include in a specific file.
//
// Control verbosity with LOG_LEVEL (default 3):
//   +define+LOG_LEVEL=4   → DEBUG (everything)
//   +define+LOG_LEVEL=3   → INFO  (instruction trace, reg/mem/csr writes)  ← default
//   +define+LOG_LEVEL=2   → WARN
//   +define+LOG_LEVEL=1   → ERROR only
//
// Usage — wrap every call site in `ifdef DEBUG_LOG / `endif:
//   `ifdef DEBUG_LOG
//     `LOG_INFO(("[ModuleName] field=0x%08h", wire_val))
//   `endif
//
// The double-paren passes the entire format+args as one macro argument so that
// internal commas do not confuse the preprocessor.

`ifndef LOGGER_VH
`define LOGGER_VH

`ifndef LOG_LEVEL
  `define LOG_LEVEL 3
`endif

`define LOG_ERROR(args) \
  begin $write("[%0t ns][ERROR] ", $time); $display args; end

`define LOG_WARN(args) \
  if (`LOG_LEVEL >= 2) begin $write("[%0t ns][WARN ] ", $time); $display args; end

`define LOG_INFO(args) \
  if (`LOG_LEVEL >= 3) begin $write("[%0t ns][INFO ] ", $time); $display args; end

`define LOG_DEBUG(args) \
  if (`LOG_LEVEL >= 4) begin $write("[%0t ns][DEBUG] ", $time); $display args; end

`endif // LOGGER_VH
