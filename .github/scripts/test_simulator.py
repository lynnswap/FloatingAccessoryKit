import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import simulator


class SimulatorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.state = Path(self.temporary.name) / "state.json"
        self.environment = Path(self.temporary.name) / "environment"
        self.inventory = json.dumps({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {"udid": "existing", "name": "iPhone 17", "deviceTypeIdentifier": "type", "isAvailable": True}
            ]
        }})

    def test_preparation_starts_boot_without_waiting_and_uses_a_new_owned_device(self):
        with patch.object(simulator, "simctl", side_effect=[self.inventory, "owned\n", ""]) as command:
            simulator.prepare(self.state, "platform=iOS Simulator,id=existing,arch=arm64", self.environment)
        self.assertEqual(command.call_args_list[-1].args, ("boot", "owned"))
        self.assertEqual(json.loads(self.state.read_text()), {"udid": "owned"})
        self.assertIn("DESTINATION=platform=iOS Simulator,id=owned,arch=arm64", self.environment.read_text())
        with patch.object(simulator, "simctl") as command:
            simulator.wait(self.state)
            simulator.cleanup(self.state)
        self.assertEqual(command.call_args_list[0].args, ("bootstatus", "owned", "-b"))
        self.assertEqual(command.call_args_list[1].args, ("delete", "owned"))
        self.assertFalse(self.state.exists())

    def test_boot_failure_keeps_the_owned_identifier_for_cleanup(self):
        with patch.object(simulator, "simctl", side_effect=[self.inventory, "owned", subprocess.CalledProcessError(1, "boot")]):
            with self.assertRaises(subprocess.CalledProcessError):
                simulator.prepare(self.state, "platform=iOS Simulator,name=iPhone 17,OS=27.0", self.environment)
        with patch.object(simulator, "simctl") as command:
            simulator.cleanup(self.state)
        command.assert_called_once_with("delete", "owned")

    def test_cleanup_without_preparation_does_not_touch_existing_devices(self):
        with patch.object(simulator, "simctl") as command:
            simulator.cleanup(self.state)
        command.assert_not_called()

    def test_boot_wait_failure_is_not_a_success_and_preserves_cleanup_state(self):
        self.state.write_text(json.dumps({"udid": "owned"}))
        with patch.object(simulator, "simctl", side_effect=subprocess.TimeoutExpired("bootstatus", 300)):
            with self.assertRaises(subprocess.TimeoutExpired):
                simulator.wait(self.state)
        self.assertTrue(self.state.exists())

    def test_cleanup_failure_is_reported_and_keeps_the_owned_identifier(self):
        self.state.write_text(json.dumps({"udid": "owned"}))
        with patch.object(simulator, "simctl", side_effect=subprocess.CalledProcessError(1, "delete")):
            with self.assertRaises(subprocess.CalledProcessError):
                simulator.cleanup(self.state)
        self.assertTrue(self.state.exists())

    def test_action_output_survives_failure(self):
        fake_bin = Path(self.temporary.name) / "bin"
        fake_bin.mkdir()
        fake_xcrun = fake_bin / "xcrun"
        fake_xcrun.write_text("#!/bin/sh\nprintf 'Waiting on DataMigration\\n'\nexit 7\n")
        fake_xcrun.chmod(0o755)
        result = subprocess.run(
            [sys.executable, "-c", "import simulator; simulator.simctl('bootstatus', 'owned', '-b')"],
            cwd=Path(__file__).resolve().parent,
            env=dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ["PATH"]),
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Waiting on DataMigration", result.stdout)
        self.assertIn("CalledProcessError", result.stderr)
