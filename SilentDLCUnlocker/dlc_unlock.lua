if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

-- ============================================================================
-- Why stock unlockers miss content
-- ----------------------------------------------------------------------------
-- Upstream only hooks _check_dlc_data → sets all_dlc_data.verified.
-- Many packs use tweak_data.dlc[x].dlc = "has_xxx" and stay locked otherwise.
-- Package re-grant must skip loot drops whose blackmarket entry is missing
-- (causes: attempt to index local 'entry' (a nil value) @ dlcmanager.lua:491).
-- ============================================================================

local function dlc_name_from_data(check_data)
	if not Global or not Global.dlc_manager or not Global.dlc_manager.all_dlc_data then
		return nil
	end

	for dlc_name, dlc_data in pairs(Global.dlc_manager.all_dlc_data) do
		if dlc_data == check_data then
			return dlc_name
		end
	end

	return nil
end

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
		local really_owned = false

		if old_check then
			local ok, result = pcall(old_check, self, dlc_data)
			really_owned = ok and result and true or false
		end

		local dlc_name = dlc_name_from_data(dlc_data)
		if dlc_name then
			SilentDLC:record_real_ownership(dlc_name, really_owned)
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

	for dlc_name, dlc_data in pairs(Global.dlc_manager.all_dlc_data) do
		if dlc_data.external or not dlc_data.app_id or tostring(dlc_data.app_id) == "218620" then
			SilentDLC:record_real_ownership(dlc_name, true)
		elseif SystemInfo:distribution() == Idstring("STEAM") and Steam and Steam.is_product_owned and dlc_data.app_id then
			SilentDLC:record_real_ownership(dlc_name, SilentDLC:is_app_owned(dlc_data.app_id))
		elseif SilentDLC.real_owned[dlc_name] == nil then
			SilentDLC:record_real_ownership(dlc_name, false)
		end

		dlc_data.verified = true
	end
end

local function force_unlock_api()
	if SilentDLC._unlock_api_hooked then
		return
	end

	SilentDLC._unlock_api_hooked = true

	function GenericDLCManager:is_dlc_unlocked(dlc)
		return true
	end

	function GenericDLCManager:has_dlc(dlc)
		return true
	end

	function GenericDLCManager:is_global_value_unlocked(global_value)
		return true
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

local function safe_add_inventory(global_value, type_items, item_entry, amount, kind)
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
	end

	return true
end

-- Safe replace: stock give_dlc_package crashes / misbehaves on bad loot rows
function GenericDLCManager:give_dlc_package()
	if not Global.dlc_save then
		Global.dlc_save = { packages = {} }
	end
	if not Global.dlc_save.packages then
		Global.dlc_save.packages = {}
	end

	if not tweak_data or not tweak_data.dlc then
		return
	end

	for package_id, data in pairs(tweak_data.dlc) do
		if self:is_dlc_unlocked(package_id) then
			if not Global.dlc_save.packages[package_id] then
				Global.dlc_save.packages[package_id] = true

				local content = data and data.content
				local loot_drops = content and content.loot_drops or {}

				for _, loot_drop in ipairs(loot_drops) do
					local ok, err = pcall(function()
						local drop = loot_drop
						if type(drop) == "table" and #drop > 0 then
							drop = drop[math.random(#drop)]
						end

						if type(drop) ~= "table" or not drop.type_items then
							return
						end

						local type_items = drop.type_items
						local item_entry = drop.item_entry

						if type_items == "armor_skins" then
							if managers.blackmarket.on_aquired_armor_skin then
								managers.blackmarket:on_aquired_armor_skin(item_entry)
								SilentDLC:record_grant("added")
							end
							return
						end

						if type_items == "player_styles" then
							if managers.blackmarket.on_aquired_player_style then
								managers.blackmarket:on_aquired_player_style(item_entry)
								SilentDLC:record_grant("added")
							end
							return
						end

						if type_items == "suit_variations" then
							if type(item_entry) == "table" and managers.blackmarket.on_aquired_suit_variation then
								managers.blackmarket:on_aquired_suit_variation(item_entry[1], item_entry[2])
								SilentDLC:record_grant("added")
							end
							return
						end

						if type_items == "gloves" then
							if managers.blackmarket.on_aquired_glove_id then
								managers.blackmarket:on_aquired_glove_id(item_entry)
								SilentDLC:record_grant("added")
							end
							return
						end

						local global_value = drop.global_value or (content and content.loot_global_value) or package_id
						safe_add_inventory(global_value, type_items, item_entry, drop.amount or 1)
					end)

					if not ok then
						SilentDLC:record_grant("skipped", tostring(package_id) .. " - " .. tostring(err))
					end
				end
			end

			local identifier = UpgradesManager.AQUIRE_STRINGS[5] .. tostring(package_id)
			for _, upgrade in ipairs(data.content and data.content.upgrades or {}) do
				if managers.upgrades and not managers.upgrades:aquired(upgrade, identifier) then
					managers.upgrades:aquire_default(upgrade, identifier)
				end
			end
		else
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

			for _, loot_drop in ipairs(loot_drops) do
				local ok, err = pcall(function()
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
