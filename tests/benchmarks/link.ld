OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 512K }
SECTIONS
{
  .text.init 0 : { *(.text.init) } > RAM
  ASSERT(SIZEOF(.text.init) <= 0x1000, "startup overlaps tohost")
  .tohost 0x1000 : { *(.tohost) } > RAM
  .text 0x2000 : { *(.text .text.*) } > RAM
  .rodata : { *(.rodata .rodata.*) } > RAM
  .data : { *(.data .data.*) } > RAM
  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata .srodata.*) *(.sdata .sdata.*)
  } > RAM
  .sbss (NOLOAD) : { *(.sbss .sbss.*) *(.scommon) } > RAM
  .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) } > RAM
  .tdata : {
    _tdata_begin = .;
    *(.tdata .tdata.*)
    _tdata_end = .;
  } > RAM
  .tbss (NOLOAD) : { *(.tbss .tbss.*) _tbss_end = .; } > RAM
  _end = .;
  /* Upstream crt.S places the single hart's stack at aligned _end + 128 KiB. */
  ASSERT(ALIGN(_end, 64) + 0x20000 <= LENGTH(RAM), "benchmark stack exceeds RAM")
}
