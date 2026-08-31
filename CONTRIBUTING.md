# Contributing

Small fixes are welcome. Keep behavior changes and refactors separate.

## Before opening an issue

Include the game platform, mod and SuperBLT versions, selected mode, affected item or contract, reproduction steps, and relevant lines from `mods/logs/`. Do not post account or session data.

## Pull requests

- Keep Lua 5.1 compatible and guard optional hooks.
- Mirror the game verifier where possible; label uncertain Epic behavior as uncertain.
- Update the README for visible changes and add an Unreleased changelog entry.
- Test the mod loading, Mod Options, persisted settings, and one known risky item in all three modes.

Run before submitting:

```sh
find SilentDLCUnlocker -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 tests/verifier_spec.lua
python scripts/validate_release.py
python scripts/build_release.py
```

Use the ZIP from `build_release.py`; PowerShell's `Compress-Archive` is not compatible with SuperBLT's extractor.
