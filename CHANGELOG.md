# Changelog

Notable changes to Silent DLC Unlocker are documented here. The project follows [Semantic Versioning](https://semver.org/) where practical.

## Unreleased

- Added a deterministic SuperBLT-compatible release builder and CI archive validation.

## 1.5.0 - 2026-07-15

- Added a new shushing-dog project logo.
- Reworded heist warnings to explain the hosting risk and show localized DLC names instead of internal identifiers.
- Added a heist-name fallback when PAYDAY is missing a DLC localization string.
- Fixed empty and locked weapon slots being incorrectly marked as `CHEATER`.
- Added persistent `CHEATER` badges to risky Contract Broker heist rows before selection.

### Fixed

- Clear stale CHEATER badges and red tints when PAYDAY 2 reuses an inventory slot for safe content.
- Match PAYDAY 2's verifier handling for `skip_cheat_verification`, invalid items, DLC lists, global values, default mask parts, skin-supplied weapon parts, and color skins.
- Verify all three mask color channels through the same category mapping used by the game.
- Preserve the `loading` argument when guarding weapon modifications.
- Stop clearing DLC package state every session, which could grant duplicate inventory quantities.
- Load the Crime.Net marker hook from the exact `crimenetgui` script.

### Added

- Full equipped-loadout preflight before joining or hosting multiplayer.
- Host-only checks and equip protection for unowned DLC characters.
- Steam ownership queries cached by application ID.
- Package grant and repair reporting in Mod Options and the SuperBLT log.
- Verifier parity tests covering DLC precedence, ignored global values, skip flags, invalid items, skin blueprints, color skins, mask defaults, `color_c`, characters, contracts, and Epic outfit behavior.

### Changed

- Removed the full inventory-grid rescan that previously ran on every slot selection.

### Documentation

- Reworked installation, configuration, warning, limitation, and troubleshooting guidance.
- Added contribution guidance, issue forms, and automated repository validation.

## 1.4.1 - 2026-07-15

- Made Normal mode the default.
- Added the in-game preview image and expanded usage documentation.

## 1.4.0 - 2026-07-15

- Replaced the previous modes with Safe, Normal, and Risky behavior.
- Added confirmation prompts in Normal mode.

## 1.3.0 - 2026-07-15

- Added risky-heist markers, host guards, and the Crime.Net hide filter.
- Added SuperBLT update metadata.

## 1.2.1 - 2026-07-15

- Published the initial Silent DLC Unlocker implementation.
