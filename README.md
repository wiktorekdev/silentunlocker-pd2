# Silent DLC Unlocker

<p align="center">
  <img src="https://img.shields.io/badge/version-1.4.0-3b82f6?style=flat-square" alt="Version" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="License" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/stargazers"><img src="https://img.shields.io/github/stars/wiktorekdev/silentunlocker-pd2?style=flat-square&color=f59e0b" alt="Stars" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/issues"><img src="https://img.shields.io/github/issues/wiktorekdev/silentunlocker-pd2?style=flat-square&color=ef4444" alt="Issues" /></a>
</p>

PAYDAY 2 SuperBLT mod. Unlocks all DLCs, marks what can give a **CHEATER** tag, and gates risky actions by mode. No loadout spoof.

## Install

1. [SuperBLT](https://superblt.znix.xyz)
2. Drop `SilentDLCUnlocker` into `PAYDAY 2/mods/`
3. Remove other DLC unlockers
4. Launch (restart once if inventory was half-broken by an old unlocker)

[Latest release](https://github.com/wiktorekdev/silentunlocker-pd2/releases/latest) · SuperBLT auto-updates via `updates/meta.json`

## Modes

**Options → Mod Options → Silent DLC Unlocker**

| Mode | CHEATER badges | Risky equip / host DLC heist |
|------|----------------|------------------------------|
| **Safe** (default) | yes | blocked |
| **Normal** | yes | confirm popup |
| **Risky** | no | free |

Optional: **Hide risky heists on Crime.Net** (unowned DLC host pins).

## CHEATER risk

**Can tag you (if unowned):** weapons, weapon mods, masks, materials/patterns, weapon colors, melee, hosting that DLC heist

**Usually fine:** outfits, gloves, characters, perk decks, throwables, deployables, many free/`is_a_unlockable` mods

Tags come from peers checking **Steam ownership** of what you equip. Unlocking in the menu does not fake ownership.

## Notes

- Steam inventory skins are not DLC unlocks
- Prefer **Safe** for public lobbies
- Unofficial fan mod. Not affiliated with Overkill / Starbreeze / Valve. Use at your own risk.

Inspired by [pd2-stuff/DLC-Unlocker-PD2](https://github.com/pd2-stuff/DLC-Unlocker-PD2) · by [wiktorekdev](https://github.com/wiktorekdev)
