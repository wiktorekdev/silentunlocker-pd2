# Silent DLC Unlocker

<p align="center">
  <img src="https://img.shields.io/badge/version-1.4.0-3b82f6?style=flat-square" alt="Version" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square" alt="License" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/stargazers"><img src="https://img.shields.io/github/stars/wiktorekdev/silentunlocker-pd2?style=flat-square&color=f59e0b" alt="Stars" /></a>
  <a href="https://github.com/wiktorekdev/silentunlocker-pd2/issues"><img src="https://img.shields.io/github/issues/wiktorekdev/silentunlocker-pd2?style=flat-square&color=ef4444" alt="Issues" /></a>
</p>

PAYDAY 2 SuperBLT mod. Unlocks **all** DLCs (including packs stock unlockers often miss), shows what can give a **CHEATER** tag, and lets you choose how strict that is.

Peers always see your real loadout. No dummy weapons. No skin changer.

## Features

| Feature | What it does |
|---------|----------------|
| **Full unlock** | Forces DLC verified + `is_dlc_unlocked` / `has_dlc`, not only `_check_dlc_data` |
| **Package grant** | Puts weapons/mods/masks into inventory; skips broken loot rows so the game does not crash |
| **CHEATER badges** | Red labels in inventory on unowned DLC gear that peers would flag |
| **Crime.Net heists** | Marks host-risk DLC contracts; optional hide filter for those pins |
| **Three modes** | Safe blocks, Normal confirms, Risky free |
| **Auto-update** | SuperBLT checks GitHub releases via `updates/meta.json` |

### Why not just the old unlocker?

Most unlockers only do:

```lua
function WINDLCManager:_check_dlc_data(dlc_data)
  return true
end
```

That is not enough for many packs (weapon DLCs, `has_*` checks). Items can stay locked or never enter the inventory. This mod also re-grants packages safely and tracks **real** Steam ownership for badges/gating.

## Install

1. Install [SuperBLT](https://superblt.znix.xyz)
2. Copy `SilentDLCUnlocker` into `PAYDAY 2/mods/`
3. Remove any other DLC unlocker
4. Launch once (restart if an old unlocker left a half-broken inventory)

[Latest release](https://github.com/wiktorekdev/silentunlocker-pd2/releases/latest)

```text
PAYDAY 2/mods/SilentDLCUnlocker/
```

## Modes

**Options → Mod Options → Silent DLC Unlocker**

| Mode | Badges | Risky equip | Host unowned DLC heist |
|------|:------:|:-----------:|:-----------------------|
| **Safe** (default) | yes | blocked | blocked |
| **Normal** | yes | Yes/No popup | Yes/No popup |
| **Risky** | no | free | free |

Extra toggle: **Hide risky heists on Crime.Net** (default off). Removes unowned DLC host pins from the map pool.

Joining someone else's lobby is not treated as hosting. Only **you** hosting an unowned DLC contract is the heist risk.

## What can give CHEATER tag

If you do **not** own the DLC and you equip / host it:

- Weapons, weapon mods, weapon colors  
- Masks, materials, patterns  
- Melee  
- Hosting that DLC heist  

Usually fine even when unlocked:

- Outfits, gloves  
- Characters  
- Perk decks  
- Equipment / throwables / deployables  
- Some free or `is_a_unlockable` weapon mods  

Other players check **Steam ownership** of what you use (`Steam:is_user_product_owned`). Unlocking content in your menu does not make Steam report you as owning it.

## Limits

- Steam marketplace / inventory skins are separate from DLC unlock  
- Some event cosmetics live outside DLC tables  
- Epic uses a ownership snapshot at unlock (no Steam API)  
- In **Normal** / **Risky** you can still get tagged if you accept the risk  

## Disclaimer

Unofficial fan mod. Not affiliated with Overkill, Starbreeze, or Valve. Unlocking paid DLC may break the game's terms of service. Use at your own risk. Prefer **Safe** for public lobbies.

## Credits

Inspired by [pd2-stuff/DLC-Unlocker-PD2](https://github.com/pd2-stuff/DLC-Unlocker-PD2).  
Made by [wiktorekdev](https://github.com/wiktorekdev) · MIT
