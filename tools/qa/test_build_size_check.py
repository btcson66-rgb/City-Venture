"""Exercise the release gate's exact boundaries and missing/ambiguous artifact failures."""
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest

CHECK = Path(__file__).with_name('build_size_check.py')


class BuildSizeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.web = self.root / 'build/web/index.pck'
        self.zip = self.root / 'dist/CityVenture-test-Windows.zip'
        for path, size in [(self.web, 160_000_000), (self.zip, 180_000_000)]:
            path.parent.mkdir(parents=True)
            with path.open('wb') as file:
                file.truncate(size)

    def tearDown(self):
        self.temp.cleanup()

    def run_check(self):
        return subprocess.run([sys.executable, str(CHECK), '--root', str(self.root)],
                              capture_output=True, text=True)

    def test_exact_limits_pass(self):
        self.assertEqual(self.run_check().returncode, 0)

    def test_one_byte_over_fails_for_each_artifact(self):
        for path, size in [(self.web, 160_000_000), (self.zip, 180_000_000)]:
            with path.open('r+b') as file:
                file.truncate(size + 1)
            self.assertEqual(self.run_check().returncode, 1)
            with path.open('r+b') as file:
                file.truncate(size)

    def test_missing_artifacts_fail(self):
        self.web.unlink()
        self.assertEqual(self.run_check().returncode, 1)
        self.zip.unlink()
        self.assertEqual(self.run_check().returncode, 1)

    def test_multiple_windows_versions_fail(self):
        (self.zip.parent / 'CityVenture-stale-Windows.zip').touch()
        self.assertEqual(self.run_check().returncode, 1)


if __name__ == '__main__':
    unittest.main()
