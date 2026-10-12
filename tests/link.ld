OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
    /* Code starts at 0x0 — matches the processor's PC reset value */
    . = 0x00000000;
    .text.init : { *(.text.init) }
    .text      : { *(.text)      }

    /* tohost word is placed on its own 4 KB page so its address is
     * a fixed constant (0x1000) regardless of code size.           */
    . = ALIGN(0x1000);
    .tohost    : { *(.tohost)    }

    /* Data follows on the next 4 KB page */
    . = ALIGN(0x1000);
    .data      : { *(.data)      }
    .bss       : { *(.bss)       }
    _end = .;
}
