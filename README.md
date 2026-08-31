# Silent DLC Unlocker

<p align="center">
  <img src="SilentDLCUnlocker/logo.png" alt="Silent DLC Unlocker" width="360" />
</p>

<p align="center">A PAYDAY 2 SuperBLT mod for unlocking DLC locally, with multiplayer warnings and safety controls.</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.5.2-3b82f6?style=flat-square" alt="Version 1.5.2" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="MIT license" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/releases/latest"><img src="https://img.shields.io/github/downloads/wiktorekdev/silentunlocker-pd2/total?style=flat-square&color=0ea5e9" alt="Downloads" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/stargazers"><img src="https://img.shields.io/github/stars/wiktorekdev/silentunlocker-pd2?style=flat-square&color=f59e0b" alt="Stars" /></a>
</p>

<p align="center"><img src="preview.png" alt="Silent DLC Unlocker preview" width="900" /></p>

## Features

- Unlocks PAYDAY 2 DLC locally.
- Separates unlocked content from real platform ownership.
- Warns about equipment and contracts that may trigger the in-game **CHEATER** tag.
- Checks before joining or hosting, with Safe, Normal, and Risky modes.
- Marks risky contracts and can hide them from Crime.Net.

> [!WARNING]
> Unlocking content locally does not make Steam or Epic report that you own it. Other players may still flag unowned DLC. Use it at your own risk.

## Installation

Requires [SuperBLT](https://modworkshop.net/mod/58342).

1. Download `SilentDLCUnlocker.zip` from the [latest release](https://github.com/wiktorekdev/silentunlocker-pd2/releases/latest).
2. Extract it into `PAYDAY 2/mods/` so `mod.txt` is at `mods/SilentDLCUnlocker/mod.txt`.
3. Remove other DLC unlockers, then start the game.

## Modes

Open **Options → Mod Options → Silent DLC Unlocker**.

| Mode | Risky equipment and contracts |
| --- | --- |
| **Safe** | Blocked |
| **Normal** | Confirm before continuing |
| **Risky** | Allowed without warnings |

Normal is the default. Safe is the sensible choice for public lobbies.

## Multiplayer

The mod cannot change what another player's game sees. It can only warn or stop you before you take a risky loadout or contract online. Steam ownership is checked against the game's APIs; Epic/TDVS behavior is not tested in-game.

If something is marked incorrectly, [open an issue](https://github.com/wiktorekdev/silentunlocker-pd2/issues) with the item, DLC, platform, selected mode, and relevant SuperBLT log lines.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Release history is in [CHANGELOG.md](CHANGELOG.md).

Inspired by [DLC-Unlocker-PD2](https://github.com/pd2-stuff/DLC-Unlocker-PD2). Released under the [MIT License](LICENSE).
