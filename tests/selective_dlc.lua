-- Run with LuaJIT from the repository root.
local root = "SilentDLCUnlocker/"
ModPath = root
SavePath = arg[1] or error("Pass a temporary directory ending in /")
local messages = {}
function log(message) messages[#messages + 1] = message end
json = { decode = function() return {} end }
local function list(contents)
 local file = assert(io.open(SavePath .. "silent_dlc_unlocker_dlcs.txt", "w"))
 file:write(contents); file:close()
end
list(" # comment\n 111 \n111\ninvalid\n")
dofile(root .. "core.lua")
assert(SilentDLC.selected_apps["111"] and not SilentDLC.selected_apps["222"])
assert(#messages == 1 and messages[1]:find("Invalid DLC ID", 1, true))
list("# comment\n ")
assert(SilentDLC:load_dlc_selection() == nil)
list("invalid\n")
assert(type(SilentDLC:load_dlc_selection()) == "table")
list("111\n")
SilentDLC.selected_apps = SilentDLC:load_dlc_selection()
SilentDLC.repair_earned_rewards = function() end
SilentDLC.try_repair_earned_rewards = function() end
SilentDLC.refresh_real_ownership = function() end
Global = { dlc_manager = { all_dlc_data = {
 selected = { app_id = "111" }, other = { app_id = "222" },
 owned = { app_id = "333", verified = true }
} }, dlc_save = { packages = { other = true }, silent_dlc_progression_repair = 1 } }
tweak_data = { dlc = { selected = {}, other = { content = { upgrades = { "keep" } } }, owned = {},
 achievement = { achievement_id = "award" }, free = { free = true } } }
managers = { achievment = {}, upgrades = { aquired = function() return true end,
 unaquire = function() error("paid DLC upgrade was removed") end } }
SilentDLC._achievement_fetch_ready = managers.achievment
UpgradesManager = { AQUIRE_STRINGS = { [5] = "dlc_" } }
GenericDLCManager = {
 has_dlc = function(self, dlc)
  if dlc == "achievement" then return false end
  local data = Global.dlc_manager.all_dlc_data[dlc]
  return data and data.verified or false
 end,
 has_all_dlcs = function(self) return self:has_dlc("selected") and self:has_dlc("other") end
}
WINDLCManager = { _check_dlc_data = function(_, data) return data.app_id == "333" end }
Hooks = { PreHook = function() end, PostHook = function() end }
dofile(root .. "dlc_unlock.lua")
local manager = GenericDLCManager
assert(manager:is_dlc_unlocked("selected"))
assert(not manager:is_dlc_unlocked("other"))
assert(manager:is_dlc_unlocked("owned"))
assert(manager:is_dlc_unlocked("free"))
assert(not manager:is_dlc_unlocked("achievement"))
assert(not manager:has_all_dlcs())
assert(WINDLCManager:_check_dlc_data(Global.dlc_manager.all_dlc_data.selected))
assert(not WINDLCManager:_check_dlc_data(Global.dlc_manager.all_dlc_data.other))
assert(WINDLCManager:_check_dlc_data(Global.dlc_manager.all_dlc_data.owned))
manager:give_dlc_package()
assert(Global.dlc_save.packages.other)
BlackMarketManager = { _verify_dlc_items = function()
 assert(manager:is_dlc_unlocked("other")); error("verifier error")
end, equip_weapon = function() end, equip_mask = function() end }
dofile(root .. "equip_guard.lua")
assert(not pcall(BlackMarketManager._verify_dlc_items, BlackMarketManager))
assert(not SilentDLC._preserve_dlc_items and not manager:is_dlc_unlocked("other"))
SilentDLC.selected_apps = nil
assert(manager:is_dlc_unlocked("other") and manager:has_all_dlcs())
print("selective DLC checks passed")
