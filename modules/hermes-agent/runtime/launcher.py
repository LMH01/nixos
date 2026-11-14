#!/usr/bin/env python3
"""Inject the routing adapter into Hermes' own managed isolated launcher."""

from __future__ import annotations

import json
import os
import subprocess
import sys


NATIVE_LAUNCHER = "/home/hermes/.local/bin/hermes"
RUNTIME_ROOT = "/opt/hermes-container"
BOOTSTRAP_MARKER = "import hermes_bootstrap;"
MAIN_ENTRY = "runpy.run_module('hermes_cli.main', run_name='__main__', alter_sys=True)"
INJECTION = (
    "import hermes_bootstrap; "
    "sys.path.insert(0, '/opt/hermes-container'); "
    "from hermes_agent_runtime import install; install();"
)


def main() -> int:
    if not os.path.isfile(NATIVE_LAUNCHER):
        print("Hermes routing wrapper: native Hermes launcher is missing", file=sys.stderr)
        return 127
    configure_only = sys.argv[1:2] == ["--container-configure"]
    command_args = [] if configure_only else sys.argv[1:]
    try:
        result = subprocess.run(
            [NATIVE_LAUNCHER, "--print-runtime-command", "--module", "hermes_cli.main",
             "--", *command_args],
            check=True,
            capture_output=True,
            text=True,
        )
        argv = json.loads(result.stdout)
    except (OSError, subprocess.CalledProcessError, ValueError, TypeError):
        print("Hermes routing wrapper: could not resolve Hermes managed runtime command", file=sys.stderr)
        return 126
    if not isinstance(argv, list) or len(argv) < 4 or not all(isinstance(part, str) for part in argv):
        print("Hermes routing wrapper: unsupported Hermes runtime command format", file=sys.stderr)
        return 126
    code = argv[3]
    if not isinstance(code, str) or code.count(BOOTSTRAP_MARKER) != 1:
        print("Hermes routing wrapper: unsupported Hermes bootstrap; refusing unguarded startup", file=sys.stderr)
        return 126
    argv[3] = code.replace(BOOTSTRAP_MARKER, INJECTION, 1)
    if configure_only:
        if argv[3].count(MAIN_ENTRY) != 1:
            print("Hermes routing wrapper: unsupported config command entrypoint", file=sys.stderr)
            return 126
        argv[3] = argv[3].replace(
            MAIN_ENTRY,
            "from hermes_agent_runtime import configure_defaults; configure_defaults()",
            1,
        )
    os.execv(argv[0], argv)
    return 127


if __name__ == "__main__":
    raise SystemExit(main())
