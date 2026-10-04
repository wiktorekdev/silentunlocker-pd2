if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

if not SilentDLC.repair_earned_rewards then
	dofile(ModPath .. "progression_repair.lua")
end

-- ============================================================================
-- Why stock unlockers miss content
-- ----------------------------------------------------------------------------
-- Upstream only hooks _check_dlc_data → sets all_dlc_data.verified.
-- Many packs use tweak_data.dlc[x].dlc = "has_xxx" and stay locked otherwise.
-- Package re-grant must skip loot drops whose blackmarket entry is missing
-- (causes: attempt to index local 'entry' (a nil value) @ dlcmanager.lua:491).
-- ============================================================================

local function wrap_check(class_name)
	local class_table = _G[class_name]
	if not class_table or not class_table._check_dlc_data then
		return
	end

	local key = class_name .. "_check"
	if SilentDLC["_wrapped_" .. key] then
		return
	end

	SilentDLC["_wrapped_" .. key] = true
	local old_check = class_table._check_dlc_data

	class_table._check_dlc_data = function(self, dlc_data)
		if old_check then
			-- Preserve any platform-check side effects; its return value does
			-- not represent real ownership after other unlocker hooks run.
			pcall(old_check, self, dlc_data)
		end

		return true
	end
end

wrap_check("WINDLCManager")
wrap_check("WinSteamDLCManager")
wrap_check("WinEpicDLCManager")

local function force_all_verified()
	if not Global or not Global.dlc_manager or not Global.dlc_manager.all_dlc_data then
		return
	end

	for _, dlc_data in pairs(Global.dlc_manager.all_dlc_data) do
		dlc_data.verified = true
	end
end

local function force_unlock_api()
	if SilentDLC._unlock_api_hooked then
		return
	end

	SilentDLC._unlock_api_hooked = true
	local old_has_dlc = GenericDLCManager.has_dlc

	function GenericDLCManager:is_dlc_unlocked(dlc)
		local data = tweak_data and tweak_data.dlc and tweak_data.dlc[dlc]
		return data and data.free or self:has_dlc(dlc)
	end

	function GenericDLCManager:has_dlc(dlc)
		local data = tweak_data and tweak_data.dlc and tweak_data.dlc[dlc]
		-- DLC packages also contain earned rewards. Keep the stock predicates
		-- (including DLC-and-achievement / DLC-or-achievement combinations).
		if data and (data.achievement_id or data.milestone_id or data.parent_dlc or data.dlc == "has_stat") then
			return old_has_dlc(self, dlc)
		end

		return true
	end

	function GenericDLCManager:is_global_value_unlocked(global_value)
		local dlc = self:global_value_to_dlc(global_value)
		return not dlc or self:is_dlc_unlocked(dlc)
	end

	if GenericDLCManager.has_all_dlcs then
		function GenericDLCManager:has_all_dlcs()
			return true
		end
	end

	if GenericDLCManager.has_goty_weapon_bundle_2014 then
		function GenericDLCManager:has_goty_weapon_bundle_2014()
			return true
		end
	end

	if GenericDLCManager.has_goty_heist_bundle_2014 then
		function GenericDLCManager:has_goty_heist_bundle_2014()
			return true
		end
	end

	if GenericDLCManager.has_goty_all_dlc_bundle_2014 then
		function GenericDLCManager:has_goty_all_dlc_bundle_2014()
			return true
		end
	end
end

local function blackmarket_entry(type_items, item_entry)
	if not type_items or not item_entry or not tweak_data or not tweak_data.blackmarket then
		return nil
	end

	local bucket = tweak_data.blackmarket[type_items]
	if not bucket then
		return nil
	end

	return bucket[item_entry]
end

local function safe_add_inventory(global_value, type_items, item_entry, amount, kind, progress)
	local item_path = tostring(type_items) .. "/" .. tostring(item_entry)
	if not managers.blackmarket then
		SilentDLC:record_grant("skipped", item_path .. " - BlackMarketManager unavailable")
		return false
	end

	if not blackmarket_entry(type_items, item_entry) then
		SilentDLC:record_grant("skipped", item_path .. " - missing tweak data")
		return false
	end

	amount = amount or 1
	for _ = 1, amount do
		local ok, err = pcall(function()
			managers.blackmarket:add_to_inventory(global_value, type_items, item_entry)
		end)
		if not ok then
			SilentDLC:record_grant("skipped", item_path .. " - " .. tostring(err))
			return false
		end

		SilentDLC:record_grant(kind or "added")
		if progress then
			progress.remaining = progress.remaining - 1
		end
	end

	return true
end

local function grant_pending_drop(drop)
	local type_items, item_entry = drop.type_items, drop.item_entry
	local methods = {
		armor_skins = "on_aquired_armor_skin",
		player_styles = "on_aquired_player_style",
		suit_variations = "on_aquired_suit_variation",
		gloves = "on_aquired_glove_id"
	}
	local method = methods[type_items]
	if method then
		if not managers.blackmarket or not managers.blackmarket[method] then
			SilentDLC:record_grant("skipped", tostring(type_items) .. " - acquisition API unavailable")
			return false
		end

		if type_items == "suit_variations" then
			if type(item_entry) ~= "table" then
				SilentDLC:record_grant("skipped", "suit_variations - invalid item")
				return false
			end
			managers.blackmarket[method](managers.blackmarket, item_entry[1], item_entry[2])
		else
			managers.blackmarket[method](managers.blackmarket, item_entry)
		end

		drop.remaining = 0
		SilentDLC:record_grant("added")
		return true
	end

	return safe_add_inventory(drop.global_value, type_items, item_entry, drop.remaining, "added", drop)
end

local function upgrade_level_unlocked(upgrade)
	local level = managers.upgrades.find_in_level_tree and managers.upgrades:find_in_level_tree(upgrade)
	if not level then
		return true
	end

	return managers.experience and managers.experience:current_level() >= level or false
end

-- Safe replace: stock give_dlc_package crashes / misbehaves on bad loot rows
function GenericDLCManager:give_dlc_package()
	if not Global.dlc_save then
		Global.dlc_save = { packages = {} }
	end
	if not Global.dlc_save.packages then
		Global.dlc_save.packages = {}
	end
	-- Persist only unfinished drops. Completed rows must not be granted again
	-- when another row fails, even after saving and restarting the game.
	Global.dlc_save.silent_dlc_pending = Global.dlc_save.silent_dlc_pending or {}
	local pending = Global.dlc_save.silent_dlc_pending

	if not tweak_data or not tweak_data.dlc then
		return
	end

	for package_id, data in pairs(tweak_data.dlc) do
		if self:is_dlc_unlocked(package_id) then
			if not Global.dlc_save.packages[package_id] then
				local content = data and data.content
				local loot_drops = content and content.loot_drops or {}
				local rows = {}
				for index, loot_drop in ipairs(loot_drops) do
					local ok, row = pcall(function()
						local drop = loot_drop
						if type(drop) == "table" and #drop > 0 then
							drop = drop[math.random(#drop)]
						end

						if type(drop) ~= "table" or not drop.type_items then
							error("invalid loot row")
						end
						return {
							type_items = drop.type_items,
							item_entry = drop.item_entry,
							global_value = drop.global_value or (content and content.loot_global_value) or package_id,
							remaining = drop.amount or 1
						}
					end)
					if ok then
						rows[index] = row
					else
						SilentDLC:record_grant("skipped", tostring(package_id) .. " - " .. tostring(row))
					end
				end
				pending[package_id] = rows
				Global.dlc_save.packages[package_id] = true
			end

			local rows = pending[package_id]
			for index, drop in pairs(rows or {}) do
				local ok, complete = pcall(grant_pending_drop, drop)
				if ok and complete then
					rows[index] = nil
				elseif not ok then
					SilentDLC:record_grant("skipped", tostring(package_id) .. " - " .. tostring(complete))
				end
			end
			if rows and not next(rows) then
				pending[package_id] = nil
			end

			local identifier = UpgradesManager.AQUIRE_STRINGS[5] .. tostring(package_id)
			for _, upgrade in ipairs(data.content and data.content.upgrades or {}) do
				if managers.upgrades then
					if upgrade_level_unlocked(upgrade) then
						if not managers.upgrades:aquired(upgrade, identifier) then
							managers.upgrades:aquire_default(upgrade, identifier)
						end
					elseif managers.upgrades:aquired(upgrade, identifier) then
						-- Remove only this package's grant, preserving other sources.
						managers.upgrades:unaquire(upgrade, identifier)
					end
				end
			end
		elseif managers.achievment and SilentDLC._achievement_fetch_ready == managers.achievment and Global.dlc_save.silent_dlc_progression_repair == 1 then
			-- Do not revoke saved rewards from transient false achievement
			-- flags during startup, or bypass a deferred recovery backup.
			local identifier = UpgradesManager.AQUIRE_STRINGS[5] .. tostring(package_id)
			for _, upgrade in ipairs(data.content and data.content.upgrades or {}) do
				if managers.upgrades and managers.upgrades:aquired(upgrade, identifier) then
					managers.upgrades:unaquire(upgrade, identifier)
				end
			end
		end
	end
end

-- Safe replace: stock crashes on entry.is_a_unlockable when entry is nil
function GenericDLCManager:give_missing_package()
	if not Global.dlc_save or not Global.dlc_save.packages then
		return
	end

	if not tweak_data or not tweak_data.dlc or not managers.blackmarket then
		return
	end

	local name_converter = {
		colors = "color",
		materials = "material",
		textures = "pattern"
	}

	for package_id, data in pairs(tweak_data.dlc) do
		if Global.dlc_save.packages[package_id] and self:is_dlc_unlocked(package_id) then
			local content = data and data.content
			local loot_drops = content and content.loot_drops or {}

			for index, loot_drop in ipairs(loot_drops) do
				local ok, err = pcall(function()
					local pending = Global.dlc_save.silent_dlc_pending
					if pending and pending[package_id] and pending[package_id][index] then
						return -- give_dlc_package retries this row, including partial amounts
					end
					-- stock only processes non-array loot rows here
					if type(loot_drop) ~= "table" or #loot_drop > 0 or not loot_drop.type_items then
						return
					end

					local type_items = loot_drop.type_items
					local item_entry = loot_drop.item_entry

					if type_items == "armor_skins" then
						local entry = tweak_data.economy and tweak_data.economy.armor_skins and tweak_data.economy.armor_skins[item_entry]
						local has_item = managers.blackmarket:armor_skin_unlocked(item_entry)
						if entry and not entry.steam_economy and not has_item then
							managers.blackmarket:on_aquired_armor_skin(item_entry)
							SilentDLC:record_grant("repaired")
						end
						return
					end

					if type_items == "player_styles" then
						if not managers.blackmarket:player_style_unlocked(item_entry) then
							managers.blackmarket:on_aquired_player_style(item_entry)
							SilentDLC:record_grant("repaired")
						end
						return
					end

					if type_items == "suit_variations" and type(item_entry) == "table" then
						if not managers.blackmarket:suit_variation_unlocked(item_entry[1], item_entry[2]) then
							managers.blackmarket:on_aquired_suit_variation(item_entry[1], item_entry[2])
							SilentDLC:record_grant("repaired")
						end
						return
					end

					if type_items == "gloves" then
						if not managers.blackmarket:glove_id_unlocked(item_entry) then
							managers.blackmarket:on_aquired_glove_id(item_entry)
							SilentDLC:record_grant("repaired")
						end
						return
					end

					local entry = blackmarket_entry(type_items, item_entry)
					if not entry then
						SilentDLC:record_grant("skipped", tostring(package_id) .. ": " .. tostring(type_items) .. "/" .. tostring(item_entry) .. " - missing tweak data")
						return
					end

					local global_value = loot_drop.global_value or (content and content.loot_global_value) or package_id
					local passed = false
					local has_item = false

					if (type_items == "weapon_mods" or type_items == "weapon_skins") and entry.is_a_unlockable then
						has_item = managers.blackmarket:get_item_amount(global_value, type_items, item_entry, true) > 0
						passed = not has_item
					elseif type_items ~= "weapon_mods" and entry.value == 0 then
						has_item = managers.blackmarket:get_item_amount(global_value, type_items, item_entry, true) > 0

						if not has_item and Global.blackmarket_manager and Global.blackmarket_manager.crafted_items then
							if type_items == "masks" and Global.blackmarket_manager.crafted_items.masks then
								for slot, crafted in pairs(Global.blackmarket_manager.crafted_items.masks) do
									if slot ~= 1 and crafted.mask_id == item_entry and crafted.global_value == global_value then
										has_item = true
										break
									end
								end
							elseif (type_items == "materials" or type_items == "textures" or type_items == "colors") and Global.blackmarket_manager.crafted_items.masks then
								local bp_name = name_converter[type_items]
								for slot, crafted in pairs(Global.blackmarket_manager.crafted_items.masks) do
									if slot ~= 1 and crafted.blueprint and crafted.blueprint[bp_name] then
										if crafted.blueprint[bp_name].id == item_entry and crafted.blueprint[bp_name].global_value == global_value then
											has_item = true
											break
										end
									end
								end
							end

							passed = not has_item
						end
					end

					if passed then
						safe_add_inventory(global_value, type_items, item_entry, loot_drop.amount or 1, "repaired")
					end
				end)

				if not ok then
					SilentDLC:record_grant("skipped", tostring(package_id) .. " - " .. tostring(err))
				end
			end
		end
	end
end

local function grant_packages(dlc_manager)
	if not Global.dlc_save then
		Global.dlc_save = { packages = {} }
	end
	if not Global.dlc_save.packages then
		Global.dlc_save.packages = {}
	end

	SilentDLC:begin_grant_report()

	local ok1, err1 = pcall(function()
		dlc_manager:give_dlc_package()
	end)
	if not ok1 then
		SilentDLC:record_grant("skipped", "give_dlc_package - " .. tostring(err1))
	end

	local ok2, err2 = pcall(function()
		dlc_manager:give_missing_package()
	end)
	if not ok2 then
		SilentDLC:record_grant("skipped", "give_missing_package - " .. tostring(err2))
	end

	SilentDLC:finish_grant_report()
end

force_unlock_api()

Hooks:PreHook(GenericDLCManager, "give_dlc_and_verify_blackmarket", "SilentDLC_ProgressionRepair", function(self)
	SilentDLC._progression_save_loaded = true
	SilentDLC:try_repair_earned_rewards(self)
end)

Hooks:PostHook(WINDLCManager, "init", "SilentDLC_WinInit", function(self)
	force_all_verified()
	SilentDLC:refresh_real_ownership()
end)

if WinSteamDLCManager then
	Hooks:PostHook(WinSteamDLCManager, "init", "SilentDLC_SteamInit", function(self)
		force_all_verified()
		SilentDLC:refresh_real_ownership()
	end)
end

if WinEpicDLCManager then
	Hooks:PostHook(WinEpicDLCManager, "init", "SilentDLC_EpicInit", function(self)
		force_all_verified()
		SilentDLC:refresh_real_ownership()
	end)
end

Hooks:PostHook(GenericDLCManager, "init_finalize", "SilentDLC_InitFinalize", function(self)
	force_all_verified()
	SilentDLC:refresh_real_ownership()
end)

Hooks:PostHook(GenericDLCManager, "give_dlc_and_verify_blackmarket", "SilentDLC_GiveAndVerify", function(self)
	force_all_verified()
	grant_packages(self)
	SilentDLC:refresh_real_ownership()
end)

Hooks:PostHook(GenericDLCManager, "setup", "SilentDLC_Setup", function(self)
	force_all_verified()
end)
