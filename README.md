# Silent DLC Unlocker

<p align="center">
  <img src="https://img.shields.io/badge/PAYDAY%202-DLC%20Unlocker-c41e3a?style=for-the-badge&logo=steam&logoColor=white" alt="PAYDAY 2" />
</p>

<p align="center">
  <a href="https://superblt.znix.xyz"><img src="https://img.shields.io/badge/SuperBLT-required-0f172a?style=flat-square&labelColor=1e293b" alt="SuperBLT" /></a>
  <img src="https://img.shields.io/badge/Lua-100%25-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
  <img src="https://img.shields.io/badge/version-1.2.1-3b82f6?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/platform-Steam%20%7C%20Epic-111827?style=flat-square" alt="Platform" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="License" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/stargazers"><img src="https://img.shields.io/github/stars/wiktorekdev/silentunlocker-pd2?style=flat-square&color=f59e0b" alt="Stars" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/issues"><img src="https://img.shields.io/github/issues/wiktorekdev/silentunlocker-pd2?style=flat-square&color=ef4444" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/CHEATER%20marks-yes-dc2626?style=flat-square" alt="Cheater marks" />
  <img src="https://img.shields.io/badge/loadout%20spoof-no-64748b?style=flat-square" alt="No spoof" />
</p>

<p align="center">
  Full DLC unlock for PAYDAY 2 with real ownership checks and inventory <b>CHEATER</b> badges.<br/>
  Peers see your real loadout. No dummy AMCAR. No skin changer.
</p>

---

## Features

| | |
|:--|:--|
| **Full unlock** | Hooks `verified`, `is_dlc_unlocked`, `has_dlc`, and package grant (not only `_check_dlc_data`) |
| **Safe inventory** | Red **CHEATER** badge on weapons, mods, masks, melee, colors that would tag you online |
| **Safe mode** | Blocks equipping those items so public lobbies stay clean |
| **Mark mode** | Unlock everything, show risk, you decide what to equip |
| **No spoof** | Others see what you actually run |

### What gets a CHEATER badge (if you do not own the DLC)

- Masks, materials, patterns
- Weapons and weapon modifications
- Weapon colors
- Melee weapons
- Hosting an unowned DLC contract

### What stays clean

- Outfits and gloves
- Characters
- Perk decks
- Equipment (Molotov, injectors, deployables, throwables)
- Some free / `is_a_unlockable` weapon mods

---

## Install

**Requirements:** [SuperBLT](https://superblt.znix.xyz)

1. Download this repo (or clone it)
2. Copy the `SilentDLCUnlocker` folder into `PAYDAY 2/mods/`
3. Remove any other DLC unlocker mods
4. Launch the game once (restart if inventory was half-granted by an old unlocker)

```text
PAYDAY 2/
  mods/
    SilentDLCUnlocker/
      mod.txt
      core.lua
      dlc_unlock.lua
      equip_guard.lua
      gui_mark.lua
      menu.lua
```

---

## Modes

Open **Options → Mod Options → Silent DLC Unlocker**.

| Mode | Unlock | Badge | Equip risky items |
|:-----|:------:|:-----:|:------------------|
| **Safe** (default) | all | yes | blocked |
| **Mark only** | all | yes | allowed (you can get tagged) |
| **All** | all | no | allowed |

---

## Why this exists

Stock unlockers often only do:

```lua
function WINDLCManager:_check_dlc_data(dlc_data)
  return true
end
```

That flips `verified` and still misses packs that use `has_*` unlock paths. Weapon DLCs can show as locked or never enter inventory.

This mod also:

1. Forces all DLC `verified`
2. Makes `is_dlc_unlocked` / `has_dlc` return true
3. Safely re-grants packages (skips broken loot rows so the game does not crash)
4. Marks items using the same ownership idea as peer CHEATER checks (`Steam:is_product_owned`)

CHEATER tag on other players still comes from **Steam ownership of what you equip**, not from “DLC unlocked in the menu”.

---

## Limits

- Steam inventory / marketplace skins are not DLC flags
- Some event cosmetics sit outside DLC tables
- Epic ownership uses the pre-unlock snapshot (no Steam API there)
- Hosting unowned DLC heists can still tag you (prefer not hosting those in Safe)

---

## Project layout

```text
silentunlocker-pd2/
├── LICENSE
├── README.md
└── SilentDLCUnlocker/
    ├── mod.txt
    ├── core.lua           # ownership + risk rules
    ├── dlc_unlock.lua     # full unlock + safe package grant
    ├── equip_guard.lua    # Safe mode equip blocks
    ├── gui_mark.lua       # CHEATER badges in inventory
    └── menu.lua           # SuperBLT options
```

---

## Disclaimer

Unofficial fan mod. Not affiliated with Overkill, Starbreeze, or Valve. Unlocking paid DLC may break the game’s terms of service. You use this at your own risk. Prefer **Safe** mode if you play public lobbies.

---

## Credits

- Inspired by [pd2-stuff/DLC-Unlocker-PD2](https://github.com/pd2-stuff/DLC-Unlocker-PD2)
- Peer verification behavior from PAYDAY 2’s `NetworkPeer` outfit checks
- Built with SuperBLT

---

<p align="center">
  <sub>Made by <a href="https://github.com/wiktorekdev">wiktorekdev</a> · MIT License</sub>
</p>
