# Contributing

Thanks for helping improve Silent DLC Unlocker. Small, focused changes are easiest to review and safest for players' inventories.

## Reporting bugs

Search existing issues first. When opening a new report, include:

- PAYDAY 2 platform (Steam or Epic);
- mod version and SuperBLT version;
- selected mode and relevant setting values;
- the exact item, DLC, or contract involved;
- steps to reproduce the behavior;
- relevant lines from `PAYDAY 2/mods/logs/` or the SuperBLT log;
- other installed unlockers or mods that alter the same menu or manager.

Never post account credentials, Steam session data, or other secrets.

## Making changes

1. Fork and clone the repository.
2. Create a branch from `master`.
3. Keep hooks guarded when their target class or method is optional.
4. Preserve PAYDAY 2's Lua 5.1 compatibility.
5. Update `README.md` when user-facing behavior changes.
6. Add an entry under **Unreleased** in `CHANGELOG.md`.
7. Run the validation commands below before opening a pull request.

Avoid combining refactors with behavior changes unless the refactor is required for the fix. Do not include generated archives such as `SilentDLCUnlocker.zip` in commits.

## Validation

The repository's GitHub Actions workflow compiles every Lua file and checks the JSON metadata. Locally, with Lua 5.1 and Python installed, run:

```sh
find SilentDLCUnlocker -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 tests/verifier_spec.lua
python scripts/validate_release.py
python scripts/build_release.py
```

Always publish the ZIP produced by `scripts/build_release.py`. SuperBLT reads raw ZIP local headers and requires forward-slash entry paths; archives produced by PowerShell `Compress-Archive` can download successfully but fail during extraction.

PAYDAY 2 APIs are only available inside the game, so syntax checks cannot replace a manual smoke test. At minimum, verify that the mod loads, its options menu opens, settings persist after restart, and the three modes handle one known risky item correctly.

## Pull requests

Explain what changed, why it was needed, and how you tested it. Include screenshots for visible menu changes and link any related issue.
