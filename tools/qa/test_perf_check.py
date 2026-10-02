"""Regression tests for evidence validation; no fabricated report is acceptance evidence."""
import copy
import json
import unittest

from perf_check import DEFAULT_BUDGET, validate


class PerfCheckTests(unittest.TestCase):
    def setUp(self):
        self.budget = json.loads(DEFAULT_BUDGET.read_text())
        self.budget["days"] = 2
        sample = {"day": 1, "orders": 5000, "staff": 50, "simulation_ms": 7.5,
                  "load_ms": 500, "gzip_bytes": 4000000, "memory_bytes": 90000000,
                  "loaded": True, "balanced": True}
        self.report = {"completed": True, "options": {"days": 2}, "errors": [], "platform": "Web",
                       "texture_bytes": 1000000000, "coverage": {"industries": self.budget["industries"], "playable_companies": 2},
                       "samples": [sample, dict(sample, day=2)]}

    def test_complete_observations_pass(self):
        self.assertEqual(validate(self.report, self.budget), [])

    def test_exact_boundaries_pass(self):
        for s in self.report["samples"]:
            s.update(simulation_ms=8, load_ms=2000, gzip_bytes=5000000)
        self.report["texture_bytes"] = 1200000000
        self.assertEqual(validate(self.report, self.budget), [])

    def test_each_budget_fails(self):
        for field, value in [("simulation_ms", 31), ("load_ms", 2001), ("gzip_bytes", 5000001)]:
            r = copy.deepcopy(self.report)
            r["samples"][0][field] = value
            self.assertTrue(validate(r, self.budget), field)

    def test_p99_is_nearest_rank_not_interpolated(self):
        s = self.report["samples"][0]
        self.report["samples"] = [dict(s, day=i + 1, simulation_ms=1 if i < 98 else 31) for i in range(100)]
        self.budget["days"] = 100
        self.assertTrue(any("p99" in e for e in validate(self.report, self.budget)))

    def test_missing_native_texture_never_counts_as_zero(self):
        for value in [None, 0, float("nan"), -1]:
            self.report["texture_bytes"] = value
            self.assertTrue(validate(self.report, self.budget))

    def test_native_short_run_does_not_certify_web(self):
        self.report["platform"] = "Windows"
        self.assertTrue(validate(self.report, self.budget))
        self.assertEqual(validate(self.report, self.budget, short=True), [])

    def test_short_still_requires_content_workload_and_budget(self):
        for section, field, value in [("coverage", "industries", []), ("coverage", "playable_companies", 1)]:
            r = copy.deepcopy(self.report)
            r[section][field] = value
            self.assertTrue(validate(r, self.budget, short=True))

    def test_truncation_missing_days_unbalanced_load_and_workload_fail(self):
        for field, value in [("balanced", False), ("loaded", False), ("staff", 49), ("orders", 4999), ("day", 2)]:
            r = copy.deepcopy(self.report)
            r["samples"][0][field] = value
            self.assertTrue(validate(r, self.budget), field)
        self.report["samples"].pop()
        self.assertTrue(validate(self.report, self.budget))

    def test_invalid_numbers_fail(self):
        for value in [None, "7", True, -1, float("nan"), float("inf")]:
            self.report["samples"][0]["simulation_ms"] = value
            self.assertTrue(validate(self.report, self.budget))

    def test_no_samples_or_incomplete_or_missing_metric_fails(self):
        r = copy.deepcopy(self.report)
        r["samples"] = []
        self.assertTrue(validate(r, self.budget))
        self.report["completed"] = False
        self.assertTrue(validate(self.report, self.budget))
        self.report["completed"] = True
        del self.report["samples"][0]["gzip_bytes"]
        self.assertTrue(validate(self.report, self.budget))

    def test_probe_does_not_relax_numeric_budgets(self):
        self.report["coverage"] = {}
        self.report["platform"] = "Linux"
        self.report["texture_bytes"] = None
        self.assertEqual(validate(self.report, self.budget, probe=True), [])
        self.report["samples"][0]["simulation_ms"] = 31
        self.assertTrue(validate(self.report, self.budget, probe=True))

    def test_malformed_root_sections_and_boolean_metrics_fail(self):
        self.assertTrue(validate([], self.budget))
        for key, value in [("samples", [None]), ("errors", "failure"), ("options", None), ("coverage", None)]:
            r = copy.deepcopy(self.report)
            r[key] = value
            self.assertTrue(validate(r, self.budget))
        self.report["coverage"]["playable_companies"] = float("nan")
        self.assertTrue(validate(self.report, self.budget))


if __name__ == "__main__":
    unittest.main()
