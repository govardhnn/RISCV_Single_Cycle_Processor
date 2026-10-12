#!/usr/bin/env python3
"""Convert a flat binary (from objcopy -O binary) to Verilog $readmemh hex.

Usage: bin2hex.py <input.bin> <output.hex>

Each 4-byte little-endian word in the binary is written as a single hex
entry starting at word address @00000000, so $readmemh loads the array
from index 0 onwards with no address remapping needed in the testbench.
"""
import sys
import struct

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.hex>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "rb") as f:
        data = f.read()

    with open(sys.argv[2], "w") as f:
        f.write("@00000000\n")
        for i in range(0, len(data), 4):
            chunk = data[i : i + 4].ljust(4, b"\x00")
            word = struct.unpack("<I", chunk)[0]   # little-endian 32-bit word
            f.write(f"{word:08x}\n")

if __name__ == "__main__":
    main()
