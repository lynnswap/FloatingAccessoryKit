#!/usr/bin/env python3
"""Own one CI simulator across preparation, build, test, and cleanup steps."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shlex
import subprocess


def simctl(*arguments, timeout=60, capture=False):
    command = ["xcrun", "simctl", *arguments]
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(), shlex.join(command), flush=True)
    if capture:
        return subprocess.check_output(command, text=True, timeout=timeout)
    subprocess.run(command, check=True, timeout=timeout)


def prepare(state_path, destination, environment_path):
    fields = dict(component.split("=", 1) for component in destination.split(","))
    devices = json.loads(simctl("list", "devices", "available", "--json", capture=True))["devices"]
    matches = []
    for runtime, entries in devices.items():
        if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
            continue
        version = runtime.split(".iOS-", 1)[1].replace("-", ".")
        for device in entries:
            if not device.get("isAvailable", True):
                continue
            if fields.get("id") and device["udid"] != fields["id"]:
                continue
            if fields.get("name") and device["name"] != fields["name"]:
                continue
            if fields.get("OS", "latest") not in ("latest", version):
                continue
            matches.append((tuple(map(int, version.split("."))), runtime, device))
    _, runtime, device = max(matches, key=lambda match: match[0])
    udid = simctl("create", "CI test simulator", device["deviceTypeIdentifier"], runtime, capture=True).strip()
    # Save ownership before boot so failed builds and cancellation can still clean up.
    state_path.write_text(json.dumps({"udid": udid}) + "\n")
    selected = "platform=iOS Simulator,id=" + udid
    if "arch" in fields:
        selected += ",arch=" + fields["arch"]
    with environment_path.open("a") as environment:
        environment.write(f"DESTINATION={selected}\nSIMULATOR_UDID={udid}\n")
    simctl("boot", udid)


def wait(state_path):
    state = json.loads(state_path.read_text())
    simctl("bootstatus", state["udid"], "-b", timeout=300)


def cleanup(state_path):
    if state_path.exists():
        state = json.loads(state_path.read_text())
        simctl("delete", state["udid"])
        state_path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("prepare", "wait", "cleanup"))
    operation = parser.parse_args().operation
    state_path = Path(os.environ["RUNNER_TEMP"]) / "ci-simulator.json"
    if operation == "prepare":
        prepare(state_path, os.environ["DESTINATION"], Path(os.environ["GITHUB_ENV"]))
    elif operation == "wait":
        wait(state_path)
    else:
        cleanup(state_path)


if __name__ == "__main__":
    main()
