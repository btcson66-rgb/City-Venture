"""Plot real monthly ledgers and report uncensored and censored objective durations."""
from __future__ import annotations
import argparse
import csv
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    datasets = {name: [json.loads(p.read_text(encoding="utf-8")) for p in folder.glob("*.json")]
                for name, folder in [("before", args.before), ("after", args.after)]}
    for name, runs in datasets.items():
        if len(runs) != 9 or any(len(r["months"]) != 18 or not r["balanced"] for r in runs):
            raise ValueError(f"{name}: expected nine balanced 18-month runs")
    metrics = [("revenue", "Revenue ($/month)"), ("gross_profit", "Gross profit ($/month)"),
               ("opex", "Operating expenses ($/month)"), ("net_profit", "Net profit ($/month)"), ("cash", "Cash ($)")]
    for policy in ["cautious", "aggressive", "casual"]:
        fig, axes = plt.subplots(5, 1, figsize=(10, 12), sharex=True)
        for phase, color in [("before", "#bd4a4a"), ("after", "#21825a")]:
            runs = [r for r in datasets[phase] if r["strategy"] == policy]
            for ax, (metric, title) in zip(axes, metrics):
                values = np.array([[row[metric] for row in r["months"]] for r in runs])
                ax.plot(range(1, 19), np.median(values, axis=0), color=color, label=phase)
                ax.fill_between(range(1, 19), values.min(axis=0), values.max(axis=0), color=color, alpha=.15)
                ax.set_ylabel(title)
                ax.axhline(0, color="#888", linewidth=.5)
                ax.grid(alpha=.2)
        axes[0].legend()
        axes[-1].set_xlabel("Game calendar month (June 2031 onward)")
        axes[-1].set_xticks(range(1, 19))
        fig.suptitle(f"{policy.title()} policy: 3 seeds, median and min/max")
        fig.tight_layout()
        fig.savefig(args.out / f"{policy}_before_after.jpg", dpi=140)
        plt.close(fig)
    chapters = json.loads(Path("game/data/story/chapters.json").read_text(encoding="utf-8"))["chapters"]
    with (args.out / "objective_day_distribution.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["phase", "strategy", "chapter", "objective", "achieved_n", "censored_n", "min_day", "p10_day", "median_day", "p90_day", "max_day",
                         "chapter_elapsed_min_days", "chapter_elapsed_median_days", "chapter_elapsed_max_days"])
        for phase, runs in datasets.items():
            for policy in ["cautious", "aggressive", "casual"]:
                selected = [r for r in runs if r["strategy"] == policy]
                for index, ch in enumerate(chapters):
                    for obj in ch["objectives"]:
                        values = [r["objective_days"][obj["id"]] for r in selected if obj["id"] in r["objective_days"]]
                        quantiles = list(np.percentile(values, [0, 10, 50, 90, 100])) if values else ["NOT ACHIEVED"] * 5
                        elapsed = [r["objective_days"][obj["id"]] - (r["chapter_days"][chapters[index-1]["id"]] if index else 1)
                                   for r in selected if obj["id"] in r["objective_days"]]
                        durations = list(np.percentile(elapsed, [0, 50, 100])) if elapsed else ["NOT ACHIEVED"] * 3
                        writer.writerow([phase, policy, ch["id"], obj["id"], len(values), len(selected)-len(values), *quantiles, *durations])
    failures = []
    for run in datasets["after"]:
        if run["strategy"] == "cautious" and (run["ch7_profit"] is None or run["ch7_profit"] <= 0):
            failures.append(f"cautious seed {run['seed']}: no positive Chapter 7 close")
        if run["strategy"] == "casual" and max(run["bankruptcies"], run["insolvencies"]) > 1:
            failures.append(f"casual seed {run['seed']}: more than one real insolvency/closure")
        if run["strategy"] == "aggressive":
            previous = 1
            for ch in chapters:
                finish = run["chapter_days"].get(ch["id"])
                if finish is None or finish - previous > 62:
                    failures.append(f"aggressive seed {run['seed']}: {ch['id']} exceeds two calendar months")
                if finish is not None: previous = finish
    report = {"runs_per_phase": 9, "seeds": [101, 202, 303], "months_per_run": 18, "failures": failures,
              "notes": ["Bands show min/max across three fixed seeds, not population confidence intervals.",
                        "Objective days are elapsed game days from arrival; NOT ACHIEVED denotes right-censoring at 18 months.",
                        "Casual fixed-price policy intentionally stalls at the repricing objective; no completion flag is fabricated."]}
    (args.out / "balance_acceptance.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
