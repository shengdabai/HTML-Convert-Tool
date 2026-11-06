"""Offline CLI regressions; all conversions run in disposable project copies."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parents[1]
        for name in ("convert.sh", "utils.sh"):
            shutil.copy2(source / name, self.root / name)
        (self.root / "config").mkdir()
        (self.root / "config/config.json").write_text(json.dumps({
            "logging": {"show_progress": True}, "conversion": {"batch_size": 10}
        }))
        (self.root / "input").mkdir()
        (self.root / "bin").mkdir()
        pandoc = self.root / "bin/pandoc"
        pandoc.write_text('#!/bin/bash\ninput="$1"; shift\n'
                          '[[ "$input" == *bad.html ]] && exit 7\n'
                          'while [[ $# -gt 0 ]]; do\n'
                          'if [[ "$1" == "-o" ]]; then cp "$input" "$2"; exit; fi\n'
                          'shift\ndone\nexit 2\n')
        pandoc.chmod(0o755)
        self.env = {"HOME": str(self.root), "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"]}

    def html(self, name):
        (self.root / "input" / name).write_text("<!DOCTYPE html><html><body>sample</body></html>")

    def run_cli(self, *args):
        return subprocess.run(["bash", str(self.root / "convert.sh"), *args],
                              env=self.env, capture_output=True, text=True, timeout=5)

    def test_batch_processes_every_file_with_progress(self):
        for name in ("one.html", "two.html", "three.html"):
            self.html(name)
        result = self.run_cli("--format", "markdown")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.root / "output").glob("*.md"))), 3)
        self.assertIn("成功: 3", result.stdout)

    def test_existing_outputs_are_skipped_without_aborting(self):
        self.html("one.html")
        (self.root / "output").mkdir()
        (self.root / "output/one.md").write_text("keep existing")
        result = self.run_cli("--format", "md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("跳过: 1", result.stdout)
        self.assertEqual((self.root / "output/one.md").read_text(), "keep existing")

    def test_batch_without_progress_does_not_exit_on_first_increment(self):
        (self.root / "config/config.json").write_text('{"logging":{"show_progress":false}}')
        self.html("one.html")
        self.html("two.html")
        result = self.run_cli("--format", "md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("成功: 2", result.stdout)

    def test_dry_run_and_empty_input_produce_no_files(self):
        for has_input in (False, True):
            with self.subTest(has_input=has_input):
                if has_input:
                    self.html("one.html")
                result = self.run_cli("--format", "md", "--dry-run")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(list((self.root / "output").glob("*.md")), [])

    def test_recursive_conversion_preserves_subdirectories(self):
        (self.root / "input/nested folder").mkdir()
        self.html("nested folder/one.html")
        result = self.run_cli("--format", "md", "--recursive")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / "output/nested folder/one.md").exists())

    def test_conversion_failure_continues_and_returns_failure(self):
        self.html("bad.html")
        self.html("good.html")
        result = self.run_cli("--format", "markdown")
        self.assertEqual(result.returncode, 1)
        self.assertTrue((self.root / "output/good.md").exists(), result.stdout + result.stderr)
        self.assertIn("失败: 1", result.stdout)
        self.assertIn("成功: 1", result.stdout)

    def test_missing_option_values_fail_promptly(self):
        for option in ("--format", "--input", "--output", "--single"):
            with self.subTest(option=option):
                result = self.run_cli(option)
                self.assertEqual(result.returncode, 1)
                self.assertIn("缺少参数", result.stderr)

    def test_filename_with_newline_is_one_file(self):
        self.html("line\nbreak.html")
        result = self.run_cli("--format", "md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / "output/line\nbreak.md").exists())


if __name__ == "__main__":
    unittest.main()
