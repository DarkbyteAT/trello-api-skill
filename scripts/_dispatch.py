#!/usr/bin/env python3
"""Internal helper for scripts/launch.cmd.

When the cmd-side launcher has more than 9 arguments to forward, cmd's
positional %1..%9 limit means we can't pass them all directly. The
launcher writes the args to a temp file (one per line), then invokes
this helper which reads them back and re-execs the target.

Not intended for direct user invocation.
"""
from __future__ import annotations

import os
import sys


def main() -> None:
    if len(sys.argv) != 3:
        print("_dispatch.py: usage: _dispatch.py <script-path> <args-file>",
              file=sys.stderr)
        sys.exit(2)

    script_path = sys.argv[1]
    args_file = sys.argv[2]

    try:
        with open(args_file, "r", encoding="utf-8") as fh:
            args = [line.rstrip("\r\n") for line in fh]
    except OSError as exc:
        print(f"_dispatch.py: cannot read args file: {exc}", file=sys.stderr)
        sys.exit(2)

    try:
        os.unlink(args_file)
    except OSError:
        pass  # best-effort cleanup

    os.execv(sys.executable, [sys.executable, script_path] + args)


if __name__ == "__main__":
    main()
