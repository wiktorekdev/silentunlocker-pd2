"""Local dev helper: syntax-check mod Lua files and run the verifier spec.

Mirrors the CI steps that need Lua (luac -p and lua5.1 tests/verifier_spec.lua)
using the lupa package (LuaJIT, Lua 5.1 compatible) on any platform.
"""

import sys
from pathlib import Path

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    lua = LuaRuntime(unpack_returned_tuples=True)

    failed = False
    for source in sorted((ROOT / "SilentDLCUnlocker").glob("*.lua")) + sorted((ROOT / "tests").glob("*.lua")):
        code = source.read_text(encoding="utf-8")
        try:
            lua.compile(code, source.name)
            print(f"OK   {source.relative_to(ROOT)}")
        except Exception as exc:  # noqa: BLE001
            failed = True
            print(f"FAIL {source.relative_to(ROOT)}: {exc}")

    if failed:
        return 1

    import os

    os.chdir(ROOT)
    spec = (ROOT / "tests" / "verifier_spec.lua").read_text(encoding="utf-8")
    try:
        lua.execute(spec)
    except Exception as exc:  # noqa: BLE001
        print(f"TEST FAILED: {exc}")
        return 1

    print("All Lua checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
