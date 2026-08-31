# Silent DLC Unlocker

<p align="center"><img src="SilentDLCUnlocker/logo.png" alt="Silent DLC Unlocker" width="260" /></p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.5.2-3b82f6?style=flat-square" alt="Version 1.5.2" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="MIT license" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/releases/latest"><img src="https://img.shields.io/github/downloads/wiktorekdev/silentunlocker-pd2/total?style=flat-square&color=0ea5e9" alt="Downloads" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/stargazers"><img src="https://img.shields.io/github/stars/wiktorekdev/silentunlocker-pd2?style=flat-square&color=f59e0b" alt="Stars" /></a>
</p>

Silent DLC Unlocker unlocks PAYDAY 2 content locally and helps you avoid loadouts or contracts that the game may flag in multiplayer.

## What it does

- Unlocks DLC locally.
- Marks and scans equipment with a CHEATER-tag risk.
- Checks before joining or hosting, with Safe, Normal, and Risky modes.
- Tracks real ownership separately from unlocked content.
- Warns about risky contracts and can hide them from Crime.Net.

It cannot make another player's game believe you own DLC. Steam results are checked against the game's ownership APIs. Epic results depend on TDVS being available and need in-game verification.

## Install

1. Install the 64-bit [SuperBLT](https://modworkshop.net/mod/58342) release for current PAYDAY 2.
2. Extract the release so `mod.txt` is at `PAYDAY 2/mods/SilentDLCUnlocker/mod.txt`.
3. Remove other DLC unlockers, then start the game.

## Modes

| Mode | Behaviour |
| --- | --- |
| Safe | Blocks risky equipment and contracts. |
| Normal | Shows the risk and asks before continuing. |
| Risky | Allows everything without warnings. |

Normal is the default. Use Safe when joining public lobbies.

## If something goes wrong

- If the mod is missing from Mod Options, check that SuperBLT loaded and there is no extra folder level.
- If an item is marked incorrectly, open an issue with the platform, item, DLC, selected mode, and relevant SuperBLT log lines.
- A kick is not proof that this mod caused it: hosts can kick manually and authentication failures use separate messages.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). Release history is in [CHANGELOG.md](CHANGELOG.md).

MIT licensed. Inspired by [DLC-Unlocker-PD2](https://github.com/pd2-stuff/DLC-Unlocker-PD2).
