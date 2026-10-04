"""Summarise a stress_result.json into a per-year table (mean/p99 tick cost, memory, save size, load time).

  python tools/qa/summarize_stress.py <stress_result.json> [--year-days 365]
"""
from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path


def summarize(report: dict, year_days: int = 365) -> list[dict]:
    rows = []
    samples = report.get("samples", [])
    for start in range(0, len(samples), year_days):
        chunk = samples[start:start + year_days]
        if not chunk:
            continue
        saved = [s for s in chunk if "gzip_bytes" in s]
        frame_key = "frame_p99_ms" if all("frame_p99_ms" in s for s in chunk) else "tick_p99_ms"
        rows.append({
            "days": f"{chunk[0]['day']}-{chunk[-1]['day']}",
            "mean_ms": statistics.mean(s["simulation_ms"] for s in chunk),
            "worst_day_p99_ms": max(s.get(frame_key, 0) for s in chunk),
            "worst_tick_ms": max(s.get("tick_max_ms", 0) for s in chunk),
            "memory_mb": max(s["memory_bytes"] for s in chunk) / 1048576,
            "gzip_mb": max((s["gzip_bytes"] for s in saved), default=0) / 1e6,
            "json_mb": max((s.get("json_bytes", 0) for s in saved), default=0) / 1e6,
            "load_ms": max((s["load_ms"] for s in saved), default=0),
            "order_ms": statistics.mean(s.get("order_ms_per_order", 0) for s in chunk),
            "journal": chunk[-1].get("journal_entries", 0),
            "orders_held": chunk[-1].get("orders_held", 0),
        })
    return rows


def render(rows: list[dict]) -> str:
    head = "| days | mean tick ms | worst-day p99 ms | worst tick ms | memory MB | save gzip MB | load ms | ms/order | journal | orders held |\n|---|---|---|---|---|---|---|---|---|---|\n"
    body = "".join(
        f"| {r['days']} | {r['mean_ms']:.2f} | {r['worst_day_p99_ms']:.1f} | {r['worst_tick_ms']:.0f} | {r['memory_mb']:.0f} | {r['gzip_mb']:.2f} | {r['load_ms']:.0f} | {r['order_ms']:.2f} | {r['journal']} | {r['orders_held']} |\n"
        for r in rows)
    return head + body


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--year-days", type=int, default=365)
    args = parser.parse_args()
    print(render(summarize(json.loads(args.report.read_text(encoding="utf-8")), args.year_days)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
