#!/usr/bin/env python3
"""Run RTL benchmarks, retaining console logs and a machine-readable summary."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

SKIPPED = {
    "mm": "requires an atomic barrier and libm fma (not available in this runtime)",
    "mt-matmul": "requires atomic barriers; multicore execution is unsupported",
    "mt-vvadd": "requires atomic barriers; multicore execution is unsupported",
    "mt-memcpy": "requires atomic barriers; multicore execution is unsupported",
    "pmp": "requires PMP and additional privileged features",
    "vec-daxpy": "requires vector and floating-point instructions",
    "vec-sgemm": "requires vector and floating-point instructions",
    "vec-memcpy": "requires vector instructions",
    "vec-strcmp": "requires vector instructions",
}


def add_workload_metrics(row, output):
    """Use timed workload cycles, never whole-program cycles, for scores."""
    if row["name"] == "dhrystone":
        header = Path(__file__).resolve().parents[1] / "riscv-tests/benchmarks/dhrystone/dhrystone.h"
        match = re.search(r"^#define\s+NUMBER_OF_RUNS\s+(\d+)", header.read_text(), re.M)
        if not match or "measured_mcycle" not in row:
            raise RuntimeError("Dhrystone iteration count or measured cycles missing")
        row["iterations"] = int(match[1])
        row["workload_cycles"] = row["measured_mcycle"]
        if row["iterations"] <= 0 or row["workload_cycles"] <= 0:
            raise RuntimeError("Dhrystone iteration/cycle counts must be positive")
        row["dmips_per_mhz"] = row["iterations"] * 1_000_000 / (row["workload_cycles"] * 1757)
    elif row["name"] in ("coremark", "coremark-validation"):
        # Upstream main returns zero even on CRC or minimum-duration failures.
        if "Correct operation validated." not in output or "ERROR!" in output:
            raise RuntimeError("CoreMark validation failed; inspect CRC/timing diagnostics in log")
        def value(label):
            match = re.search(rf"^{re.escape(label)}\s*:\s*(\d+)$", output, re.M)
            if not match or int(match[1]) <= 0:
                raise RuntimeError(f"CoreMark {label} missing or invalid")
            return int(match[1])
        row["iterations"] = value("Iterations")
        row["workload_cycles"] = value("Total ticks")
        row["reference_clock_hz"] = value("Reference clock Hz")
        row["reference_seconds"] = row["workload_cycles"] / row["reference_clock_hz"]
        if row["reference_seconds"] < 10:
            raise RuntimeError("CoreMark timed region is shorter than 10 reference seconds")
        row["crc_validated"] = True
        if row["name"] == "coremark":
            row["coremark_per_mhz"] = row["iterations"] * 1_000_000 / row["workload_cycles"]
    if "iterations" in row:
        row["cycles_per_iteration"] = row["workload_cycles"] / row["iterations"]


def publish_readme(path, results, counts):
    """Replace only the marked results block; subset runs replace the last run."""
    start = "<!-- benchmark-results:start -->"
    end = "<!-- benchmark-results:end -->"
    original = path.read_text()
    if original.count(start) != 1 or original.count(end) != 1:
        raise ValueError(f"{path} must contain exactly one benchmark-results marker pair")
    left = original.index(start) + len(start)
    right = original.index(end)
    if right < left:
        raise ValueError(f"benchmark-results markers are reversed in {path}")

    def cell(value):
        return str(value).replace("\\", "\\\\").replace("|", "\\|").replace("\n", " ").replace("\r", " ")

    lines = [
        "",
        "Latest benchmark invocation (RV32I, software arithmetic). "
        "Subset runs replace this table with only the selected benchmarks.",
        "",
        f"**{counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped.**",
        "",
        "| Benchmark | Result | Total cycles | Instructions retired | Details |",
        "|-----------|--------|-------------:|---------------------:|---------|",
    ]
    for row in results:
        cycles = f"{row['cycles']:,}" if "cycles" in row else "—"
        retired = f"{row['instret']:,}" if "instret" in row else "—"
        lines.append(f"| {cell(row['name'])} | {cell(row['status'])} | {cycles} | "
                     f"{retired} | {cell(row.get('reason', ''))} |")
    lines.extend([
        "",
        "Total counts include startup, warmup, verification, and console output. "
        "These are RTL simulation results with ideal single-cycle memory.",
        "",
    ])
    scored = [row for row in results if row["status"] == "PASS" and "iterations" in row]
    if scored:
        lines.extend([
            "#### Workload performance",
            "",
            "| Benchmark | Iterations | Measured cycles | Cycles/iteration | Estimated normalized score |",
            "|-----------|-----------:|----------------:|-----------------:|----------------------------|",
        ])
        for row in scored:
            if "dmips_per_mhz" in row:
                score = f"{row['dmips_per_mhz']:.2f} DMIPS/MHz"
            elif "coremark_per_mhz" in row:
                score = f"{row['coremark_per_mhz']:.2f} CoreMark/MHz"
            else:
                score = "CRC validation run"
            lines.append(f"| {cell(row['name'])} | {row['iterations']:,} | {row['workload_cycles']:,} | "
                         f"{row['cycles_per_iteration']:,.2f} | {score} |")
        lines.extend([
            "",
            "Scores use the measured workload region: DMIPS/MHz = "
            "iterations × 1,000,000 / (cycles × 1757); CoreMark/MHz = "
            "iterations × 1,000,000 / cycles. These are simulation estimates, "
            "not measured hardware scores or certified benchmark submissions.",
            "",
        ])
        for row in scored:
            if row["name"] == "coremark":
                lines.extend([
                    f"CoreMark performance seeds: `0,0,0x66`; 2,000-byte dataset; one context. "
                    f"Timed duration: {row['reference_seconds']:.2f} seconds at the explicitly "
                    f"assumed {row['reference_clock_hz']:,} Hz simulation reference clock. "
                    "The separate validation run uses seeds `0x3415,0x3415,0x66`.",
                    "",
                ])
    updated = original[:left] + "\n".join(lines) + "\n" + original[right:]
    if updated != original:
        path.write_text(updated)


def symbols(nm, elf):
    result = subprocess.run([nm, "--defined-only", str(elf)],
                            check=True, capture_output=True, text=True)
    table = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 3:
            table[fields[2]] = int(fields[0], 16)
    return table


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim", required=True)
    parser.add_argument("--nm", required=True)
    parser.add_argument("--dir", type=Path, required=True)
    parser.add_argument("--max-cycles", type=int, default=100_000_000)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--readme", type=Path, help="refresh the marked README results section")
    parser.add_argument("benchmarks", nargs="+")
    args = parser.parse_args()
    results = []
    print("\n=== Application benchmarks (RV32I, software arithmetic) ===", flush=True)
    for name in args.benchmarks:
        row = {"name": name}
        if name in SKIPPED:
            row.update(status="SKIP", reason=SKIPPED[name])
            print(f"SKIP {name:12} {row['reason']}", flush=True)
            results.append(row)
            continue
        log = args.dir / f"bench-{name}.log"
        try:
            syms = symbols(args.nm, args.dir / f"bench-{name}.elf")
            command = [str(Path(args.sim).resolve()),
                       f"+HEXFILE={args.dir / f'bench-{name}.hex'}",
                       f"+TOHOST={syms['tohost']:x}",
                       f"+FROMHOST={syms['fromhost']:x}",
                       f"+MAX_CYCLES={args.max_cycles}"]
            proc = subprocess.run(command, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True,
                                  timeout=args.timeout)
            log.write_text(proc.stdout)
            match = re.search(r"^PASS cycles=(\d+) instret=(\d+)$", proc.stdout, re.M)
            if proc.returncode != 0 or match is None:
                raise RuntimeError(f"simulator failed (exit {proc.returncode}); see {log}")
            row.update(status="PASS", cycles=int(match[1]), instret=int(match[2]))
            for counter in ("mcycle", "minstret"):
                measured = re.search(rf"^{counter} = (\d+)$", proc.stdout, re.M)
                if measured:
                    row[f"measured_{counter}"] = int(measured[1])
            add_workload_metrics(row, proc.stdout)
            print(f"PASS {name:12} {row['cycles']:>10,} total cycles"
                  f"  {row['instret']:>10,} retired", flush=True)
        except subprocess.TimeoutExpired as exc:
            output = exc.stdout or b""
            log.write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
            row.update(status="FAIL", reason=f"wall timeout after {args.timeout}s; see {log}")
            print(f"FAIL {name:12} {row['reason']}", flush=True)
        except (OSError, KeyError, ValueError, subprocess.CalledProcessError, RuntimeError) as exc:
            row.update(status="FAIL", reason=str(exc))
            print(f"FAIL {name:12} {exc}", flush=True)
        results.append(row)
    report = args.dir / "benchmark-results.json"
    report.write_text(json.dumps(results, indent=2) + "\n")
    counts = {status: sum(row["status"] == status for row in results)
              for status in ("PASS", "FAIL", "SKIP")}
    print(f"\n{counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped")
    print(f"Logs: {args.dir}/bench-*.log; summary: {report}")
    if args.readme:
        try:
            publish_readme(args.readme, results, counts)
        except (OSError, ValueError) as exc:
            print(f"README update failed: {exc}", file=sys.stderr)
            return 1
        print(f"README results updated: {args.readme}")
    return bool(counts["FAIL"])


if __name__ == "__main__":
    sys.exit(main())
