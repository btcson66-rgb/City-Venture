"""Fail closed on exceeded budgets, incomplete workload and missing Web evidence.

--short checks native CI timing/save regressions; it never certifies Web/full coverage.
--probe permits missing content/platform coverage during profiling, but keeps budgets.
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path

DEFAULT_BUDGET = Path(__file__).with_name("perf_budget.json")


def validate(report: dict, budget: dict, *, short: bool = False, probe: bool = False) -> list[str]:
    if not isinstance(report, dict) or not isinstance(budget, dict):
        return ["Evidence and budget must be JSON objects"]
    if not isinstance(report.get("errors", []), list) or not all(isinstance(e, str) for e in report.get("errors", [])):
        return ["Errors must be a list of strings"]
    if not isinstance(report.get("samples", []), list) or not all(isinstance(s, dict) for s in report.get("samples", [])):
        return ["Samples must be a list of objects"]
    if not isinstance(report.get("options", {}), dict) or not isinstance(report.get("coverage", {}), dict):
        return ["Options and coverage must be objects"]
    errors = list(report.get("errors", []))
    samples = report.get("samples", [])
    if not samples or report.get("completed") is not True:
        errors.append("Missing samples or incomplete run")
        return errors
    required = {"simulation_ms", "load_ms", "gzip_bytes", "memory_bytes", "orders", "staff", "day"}
    for sample in samples:
        if not required <= sample.keys():
            errors.append("Incomplete daily metrics")
            return errors
        for field in required:
            value = sample[field]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                errors.append(f"Invalid numeric metric: {field}")
                return errors
        if sample.get("loaded") is not True or sample.get("balanced") is not True:
            errors.append(f"Day {sample['day']}: load/balance failure")
    if [s["day"] for s in samples] != list(range(1, len(samples) + 1)):
        errors.append("Daily observations are not contiguous")
    values = sorted(s["simulation_ms"] for s in samples)
    average = statistics.mean(values)
    p99 = values[max(0, math.ceil(len(values) * .99) - 1)]
    if average > budget["average_simulation_ms"]:
        errors.append(f"Mean simulation {average:.3f} ms exceeds {budget['average_simulation_ms']} ms")
    if p99 > budget["p99_simulation_ms"]:
        errors.append(f"p99 simulation {p99:.3f} ms exceeds {budget['p99_simulation_ms']} ms")
    for field, limit in [("gzip_bytes", "compressed_save_bytes"), ("load_ms", "load_ms")]:
        if max(s[field] for s in samples) > budget[limit]:
            errors.append(f"{field} exceeds {budget[limit]} {'bytes' if field == 'gzip_bytes' else 'ms'}")
    target = report.get("options", {})
    expected_days = int(target.get("days", 0)) if short or probe else budget["days"]
    if len(samples) != expected_days or expected_days < 1:
        errors.append(f"Expected {expected_days} complete daily observations")
    for s in samples:
        if s["orders"] != budget["orders_per_day"] or s["staff"] < budget["staff"]:
            errors.append(f"Day {s['day']}: required 5,000 orders and 50 employees not exercised")
    if not probe:
        coverage = report.get("coverage", {})
        if not set(budget["industries"]) <= set(coverage.get("industries", [])):
            errors.append("Seven required industries were not exercised")
        companies = coverage.get("playable_companies", 0)
        if isinstance(companies, bool) or not isinstance(companies, (int, float)) or not math.isfinite(companies) or companies < budget["playable_companies"]:
            errors.append("Multiple playable companies were not exercised")
    if not short and not probe:
        if report.get("platform") != "Web":
            errors.append("Web runtime performance NOT VERIFIED by native timings")
        texture = report.get("texture_bytes")
        if isinstance(texture, bool) or not isinstance(texture, (int, float)) or not math.isfinite(texture) or texture <= 0:
            errors.append("Rendered texture memory NOT VERIFIED")
        elif texture > budget["texture_bytes"]:
            errors.append("Texture memory exceeds 1.2 GB")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--budget", type=Path, default=DEFAULT_BUDGET)
    parser.add_argument("--short", action="store_true")
    parser.add_argument("--probe", action="store_true")
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.report.read_text(encoding="utf-8")), json.loads(args.budget.read_text(encoding="utf-8")), short=args.short, probe=args.probe)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        errors = [f"Invalid/missing evidence: {exc}"]
    for error in errors:
        print("FAIL:", error)
    print(f"perf_check: {len(errors)} failures; mode={'probe' if args.probe else 'short' if args.short else 'full'}")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
