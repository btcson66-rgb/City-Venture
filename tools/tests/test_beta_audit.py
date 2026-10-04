import sys
import unittest
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from beta_audit import audit, hits, visible_text, ALLOW


class BetaAuditTests(unittest.TestCase):
    def test_autoload_and_multiline_ui_calls_are_scanned(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "game/data").mkdir(parents=True)
            (root / "game/autoload").mkdir()
            (root / "game/tests").mkdir()
            (root / "game/autoload/ui.gd").write_text('UIK.wrap(\n  "Coming soon", 8)\nI18n.t("Planned")\n', encoding="utf-8")
            (root / "game/tests/fixture.gd").write_text('I18n.t("Planned")', encoding="utf-8")
            self.assertEqual(len(audit(root)), 2)

    def test_inactive_status_hides_future_text_until_activated(self):
        data = {"status": "planned", "name": "Coming soon", "interior": {"text": "not in this build"}}
        self.assertEqual(list(visible_text(data)), [])
        data["status"] = "active"
        self.assertEqual(sum(hits(t) for _, t in visible_text(data)), 2)

    def test_explicit_scenery_hides_interior_but_not_public_name(self):
        text = list(visible_text({"enterable": False, "name": "Open cafe", "interior": {"text": "planned"}}))
        self.assertEqual(text, [("/name", "Open cafe")])

    def test_whitelist_is_exact_and_every_exception_has_reason(self):
        for text, reason in ALLOW.items():
            self.assertTrue(reason)
            self.assertFalse(hits(text))
            self.assertTrue(hits(text + " Coming soon"))

    def test_all_forbidden_variants_are_rejected(self):
        for text in ["Planned", "P1", "P2", "P3", "not in this build", "later build", "coming soon", "placeholder", "not part of this build"]:
            self.assertTrue(hits(text))


if __name__ == "__main__":
    unittest.main()
