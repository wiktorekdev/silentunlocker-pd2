if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local function reward_key(category, id)
	if type(id) == "table" then
		return category .. "/" .. tostring(id[1]) .. "/" .. tostring(id[2])
	end
	return category .. "/" .. tostring(id)
end

local function visit_drops(data, visit)
	for _, row in ipairs(data.content and data.content.loot_drops or {}) do
		if row.type_items then
			visit(row)
		else
			for _, drop in ipairs(row) do
				if drop.type_items then
					visit(drop)
				end
			end
		end
	end
end

-- nil means unknown, never permission to remove an item. In particular,
-- achievement tables contain false awards before the platform fetch completes.
local function package_state(dlc_manager, package_id, seen)
	local data = tweak_data.dlc[package_id]
	if not data then
		return nil
	end
	seen = seen or {}
	if seen[package_id] then
		return nil
	end
	seen[package_id] = true
	local achievement = managers.achievment
	if data.achievement_id and (not achievement or not achievement:get_info(data.achievement_id)) then
		return nil
	end
	if data.milestone_id and (not achievement or not achievement:get_milestone(data.milestone_id)) then
		return nil
	end
	if data.parent_dlc and package_state(dlc_manager, data.parent_dlc, seen) == nil then
		return nil
	end
	local ok, unlocked = pcall(dlc_manager.is_dlc_unlocked, dlc_manager, package_id)
	if ok then
		return unlocked and true or false
	end
	return nil
end

local function progression_package(package_id, seen)
	local data = tweak_data.dlc[package_id]
	if not data then
		return false
	end
	if data.achievement_id or data.milestone_id or data.dlc == "has_stat" then
		return true
	end
	seen = seen or {}
	if seen[package_id] then
		return false
	end
	seen[package_id] = true
	return data.parent_dlc and progression_package(data.parent_dlc, seen) or false
end

local function repair_backup(dlc_manager, blackmarket)
	local backup = { version = 1, created_at = os.time() }
	blackmarket:save(backup)
	dlc_manager:save(backup)
	if managers.multi_profile then
		managers.multi_profile:save(backup)
	end
	if managers.upgrades and managers.upgrades.save then
		managers.upgrades:save(backup)
	end
	local encoded = json.encode(backup)
	local path = SavePath .. "silent_dlc_progression_backup_" .. tostring(backup.created_at) .. ".json"
	local suffix = 0
	while true do
		local existing = io.open(path, "r")
		if not existing then
			break
		end
		existing:close()
		suffix = suffix + 1
		path = SavePath .. "silent_dlc_progression_backup_" .. tostring(backup.created_at) .. "_" .. suffix .. ".json"
	end
	local file, err = io.open(path, "w")
	if not file then
		error("cannot write progression backup: " .. tostring(err))
	end
	local written, write_error = file:write(encoded)
	local closed, close_error = file:close()
	if not written or not closed then
		error("cannot finish progression backup: " .. tostring(write_error or close_error))
	end
	return path
end

local function reward_entry(category, id)
	if category == "armor_skins" then
		return tweak_data.economy and tweak_data.economy.armor_skins[id]
	elseif category == "suit_variations" then
		local style = tweak_data.blackmarket.player_styles[id[1]]
		return style and style.material_variations and style.material_variations[id[2]]
	end
	return tweak_data.blackmarket[category] and tweak_data.blackmarket[category][id]
end

local function contains(list, value)
	for _, entry in ipairs(list or {}) do
		if entry == value then
			return true
		end
	end
	return false
end

local mask_categories = { material = "materials", pattern = "textures", color_a = "materials", color_b = "materials", color_c = "materials" }

local function repair_crafted(blackmarket, targets)
	local crafted = blackmarket._global.crafted_items or {}
	for _, category in ipairs({ "primaries", "secondaries" }) do
		for slot, weapon in pairs(crafted[category] or {}) do
			local skin = weapon.cosmetics and weapon.cosmetics.id
			if skin and targets[reward_key("weapon_skins", skin)] then
				blackmarket:on_remove_weapon_cosmetics(category, slot, true)
			end
			local defaults = managers.weapon_factory:get_default_blueprint_by_factory_id(weapon.factory_id)
			local skin_data = weapon.cosmetics and tweak_data.blackmarket.weapon_skins[weapon.cosmetics.id]
			for _, part in ipairs(deep_clone(weapon.blueprint or {})) do
				local target = targets[reward_key("weapon_mods", part)]
				local global_value = weapon.global_values and weapon.global_values[part] or "normal"
				if target and target.global_values[global_value] and not contains(defaults, part) and not contains(skin_data and skin_data.default_blueprint, part) then
					blackmarket:remove_weapon_part(category, slot, global_value, part, true)
				end
			end
		end
	end

	for slot, mask in pairs(crafted.masks or {}) do
		local target = targets[reward_key("masks", mask.mask_id)]
		if slot ~= 1 and target and target.global_values[mask.global_value or "normal"] then
			-- Return installed materials without crediting money for the mask.
			local defaults = blackmarket:get_mask_default_blueprint(mask.mask_id) or {}
			for name, part in pairs(mask.blueprint or {}) do
				local part_category = mask_categories[name]
				local entry = part_category and reward_entry(part_category, part.id)
				if entry and not entry.unlimited and (not defaults[name] or defaults[name].id ~= part.id) then
					blackmarket:add_to_inventory(part.global_value or "normal", part_category, part.id, true)
				end
			end
			crafted.masks[slot] = nil
		else
			local defaults = blackmarket:get_mask_default_blueprint(mask.mask_id) or {}
			local generic = blackmarket:get_default_mask_blueprint()
			for name, part in pairs(mask.blueprint or {}) do
				local part_category = mask_categories[name]
				local part_target = part_category and targets[reward_key(part_category, part.id)]
				if part_target and part_target.global_values[part.global_value or "normal"] and (not defaults[name] or defaults[name].id ~= part.id) then
					mask.blueprint[name] = deep_clone(defaults[name] or generic[name])
				end
			end
		end
	end
end

local function repair_profiles(blackmarket, targets, removed_masks, upgrades)
	local defaults = blackmarket._defaults
	local function removed(category, id)
		return id and targets[reward_key(category, id)] ~= nil
	end
	local function repair(profile)
		if removed_masks[profile.mask] and not blackmarket._global.crafted_items.masks[profile.mask] then
			profile.mask = 1
		end
		local grenade = blackmarket._global.grenades and blackmarket._global.grenades[profile.throwable]
		if upgrades[profile.throwable] and grenade and not grenade.unlocked then
			profile.throwable = defaults.grenade
		end
		local melee = blackmarket._global.melee_weapons and blackmarket._global.melee_weapons[profile.melee]
		if upgrades[profile.melee] and melee and not melee.unlocked then
			profile.melee = defaults.melee_weapon
		end
		if removed("player_styles", profile.player_style) and not blackmarket:player_style_unlocked(profile.player_style) then
			profile.player_style = defaults.player_style
		end
		if removed("gloves", profile.glove_id) and not blackmarket:glove_id_unlocked(profile.glove_id) then
			profile.glove_id = defaults.glove_id
		end
		if removed("armor_skins", profile.armor_skin) and not blackmarket:armor_skin_unlocked(profile.armor_skin) then
			profile.armor_skin = defaults.armor_skin
		end
		for style, variation in pairs(profile.suit_variations or {}) do
			if (removed("suit_variations", { style, variation }) or removed("player_styles", style)) and not blackmarket:suit_variation_unlocked(style, variation) then
				profile.suit_variations[style] = "default"
			end
		end
		for _, loadout in pairs(profile.henchmen_loadout or {}) do
			if removed_masks[loadout.mask_slot] and not blackmarket._global.crafted_items.masks[loadout.mask_slot] then
				loadout.mask, loadout.mask_slot = nil, nil
			end
			local style = loadout.player_style
			if removed("player_styles", style) and not blackmarket:player_style_unlocked(style) then
				loadout.player_style = defaults.player_style
			end
			if loadout.suit_variation and (removed("suit_variations", { style, loadout.suit_variation }) or removed("player_styles", style)) then
				loadout.suit_variation = "default"
			end
			if removed("gloves", loadout.glove_id) and not blackmarket:glove_id_unlocked(loadout.glove_id) then
				loadout.glove_id = defaults.glove_id
			end
		end
	end
	for _, profile in pairs(Global.multi_profile and Global.multi_profile._profiles or {}) do
		repair(profile)
	end
	blackmarket:_verfify_equipped()
	blackmarket:clean_weapon_equipped_cache()
end

function SilentDLC:repair_earned_rewards(dlc_manager)
	if not managers.achievment or not self._progression_save_loaded or self._achievement_fetch_ready ~= managers.achievment then
		return
	end
	local save = Global.dlc_save
	local blackmarket = managers.blackmarket
	if not save or not save.packages or save.silent_dlc_progression_repair == 1 or not blackmarket or not blackmarket._global then
		return
	end
	local states, sources, locked, blocked, complete = {}, {}, {}, {}, true
	for package_id, data in pairs(tweak_data.dlc) do
		states[package_id] = package_state(dlc_manager, package_id)
		visit_drops(data, function(drop)
			local key = reward_key(drop.type_items, drop.item_entry)
			sources[key] = sources[key] or {}
			sources[key][package_id] = true
		end)
		if save.packages[package_id] and progression_package(package_id) then
			if states[package_id] == false then
				locked[package_id] = true
			elseif states[package_id] == nil then
				complete = false
			end
		end
	end
	if not next(locked) then
		if save.silent_dlc_progression_removed_masks then
			local ok, err = pcall(repair_profiles, blackmarket, {}, save.silent_dlc_progression_removed_masks, {})
			if not ok then
				self:record_grant("skipped", "progression profile repair deferred: " .. tostring(err))
				return
			end
			save.silent_dlc_progression_removed_masks = nil
		end
		if complete then
			save.silent_dlc_progression_repair = 1
		end
		return
	end

	local targets = {}
	for package_id in pairs(locked) do
		local data = tweak_data.dlc[package_id]
		visit_drops(data, function(drop)
			local category, id = drop.type_items, drop.item_entry
			local key = reward_key(category, id)
			local entry = reward_entry(category, id)
			if not entry then
				blocked[package_id] = true
				complete = false
				return
			end
			if entry.unlocked or entry.default or entry.steam_economy or category == "weapon_skins" and not entry.is_a_unlockable then
				return
			end
			for source in pairs(sources[key]) do
				if states[source] ~= false then
					if states[source] == nil then
						complete, blocked[package_id] = false, true
					end
					return -- another valid or unknown source must be preserved
				end
			end
			for _, name in ipairs({ "_skirmish_locked_content", "_crimespree_locked_content", "_infamy_locked_content" }) do
				local content = dlc_manager[name]
				if content and content[category] and content[category][id] then
					return
				end
			end
			targets[key] = targets[key] or { category = category, id = id, global_values = {} }
			targets[key].global_values[drop.global_value or data.content.loot_global_value or package_id] = true
		end)
	end

	local ok, err = pcall(function()
		local backup = repair_backup(dlc_manager, blackmarket)
		log("[SilentDLC] Progression repair backup: " .. backup)
		-- Keep removed slots across a failed attempt or a saved restart so
		-- profile references can still be repaired after the mask is gone.
		save.silent_dlc_progression_removed_masks = save.silent_dlc_progression_removed_masks or {}
		local removed_masks, upgrades = save.silent_dlc_progression_removed_masks, {}
		for slot, mask in pairs(blackmarket._global.crafted_items.masks or {}) do
			local target = targets[reward_key("masks", mask.mask_id)]
			if slot ~= 1 and target and target.global_values[mask.global_value or "normal"] then removed_masks[slot] = true end
		end
		repair_crafted(blackmarket, targets)
		for _, target in pairs(targets) do
			local category, id = target.category, target.id
			local revoke = { armor_skins = "on_unaquired_armor_skin", player_styles = "on_unaquired_player_style", suit_variations = "on_unaquired_suit_variation", gloves = "on_unaquired_glove_id" }
			if revoke[category] then
				if category == "suit_variations" then
					-- The stock revoke function changes the whole style instead
					-- of this variation. Repair the saved variation explicitly.
					local style = blackmarket._global.player_styles[id[1]]
					if style and style.material_variations[id[2]] then
						style.material_variations[id[2]].unlocked = false
						if style.equipped_material_variation == id[2] then style.equipped_material_variation = "default" end
					end
				else
					blackmarket[revoke[category]](blackmarket, id)
				end
			else
				for global_value in pairs(target.global_values) do
					while blackmarket:get_item_amount(global_value, category, id, true) > 0 do
						assert(blackmarket:remove_item(global_value, category, id), "inventory removal failed")
					end
					blackmarket:remove_new_drop(global_value, category, id)
				end
			end
			-- The grant report is reset right after this, so log the removal here.
			log("[SilentDLC] Removed unearned progression reward: " .. reward_key(category, id))
			self:record_grant("repaired", "progression reward: " .. reward_key(category, id))
		end
		for package_id in pairs(locked) do
			local identifier = UpgradesManager.AQUIRE_STRINGS[5] .. tostring(package_id)
			local content = tweak_data.dlc[package_id].content
			for _, upgrade in ipairs(content and content.upgrades or {}) do
				upgrades[upgrade] = true
				if managers.upgrades:aquired(upgrade, identifier) then managers.upgrades:unaquire(upgrade, identifier) end
			end
		end
		repair_profiles(blackmarket, targets, removed_masks, upgrades)
		save.silent_dlc_progression_removed_masks = nil
		blackmarket:refill_track_global_values()
		for package_id in pairs(locked) do
			if not blocked[package_id] then
				save.packages[package_id] = nil
				if save.silent_dlc_pending then save.silent_dlc_pending[package_id] = nil end
			end
		end
		if complete then save.silent_dlc_progression_repair = 1 end
		log("[SilentDLC] Unearned progression rewards repaired; " .. (complete and "migration complete." or "unknown reward data deferred."))
	end)
	if not ok then
		self:record_grant("skipped", "progression repair deferred: " .. tostring(err))
	end
end

function SilentDLC:try_repair_earned_rewards(dlc_manager)
	local ok, err = pcall(self.repair_earned_rewards, self, dlc_manager)
	if not ok then
		log("[SilentDLC] Progression repair deferred: " .. tostring(err))
		self:record_grant("skipped", "progression repair deferred: " .. tostring(err))
	end
end

-- The account's achievements_fetched flag is also set on errors. Require the
-- actual successful callback before interpreting false awards as unearned.
if AchievmentManager and not SilentDLC._progression_fetch_hooked then
	SilentDLC._progression_fetch_hooked = true
	Hooks:PostHook(AchievmentManager, "fetch_achievments", "SilentDLC_ProgressionFetched", function(error_str)
		SilentDLC._achievement_fetch_ready = error_str == "success" and managers.achievment or nil
		if managers.dlc then SilentDLC:try_repair_earned_rewards(managers.dlc) end
	end)
end
