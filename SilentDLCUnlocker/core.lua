SilentDLC = SilentDLC or {}

SilentDLC.MOD_PATH = SilentDLC.MOD_PATH or ModPath
SilentDLC.SAVE_PATH = SavePath .. "silent_dlc_unlocker.json"

-- safe   = hard block risky actions
-- normal = confirm popup, then allow
-- risky  = no blocks, no popups
SilentDLC.MODE = {
	SAFE = "safe",
	NORMAL = "normal",
	RISKY = "risky"
}

SilentDLC.settings = SilentDLC.settings or {
	mode = SilentDLC.MODE.NORMAL,
	hide_risky_heists = false
}

SilentDLC.real_owned = SilentDLC.real_owned or {}
SilentDLC.owned_by_app = SilentDLC.owned_by_app or {}
SilentDLC._ownership_ready = SilentDLC._ownership_ready or false
SilentDLC._pass_guard = false
SilentDLC.last_grant_report = SilentDLC.last_grant_report or nil

function SilentDLC:normalize_mode(mode)
	if mode == self.MODE.SAFE or mode == self.MODE.NORMAL or mode == self.MODE.RISKY then
		return mode
	end

	-- legacy saves
	if mode == "mark" then
		return self.MODE.NORMAL
	end

	if mode == "all" then
		return self.MODE.RISKY
	end

	return self.MODE.NORMAL
end

function SilentDLC:save()
	local file = io.open(self.SAVE_PATH, "w")
	if not file then
		return
	end

	file:write(json.encode({
		mode = self.settings.mode,
		hide_risky_heists = self.settings.hide_risky_heists
	}))
	file:close()
end

function SilentDLC:load()
	local file = io.open(self.SAVE_PATH, "r")
	if not file then
		return
	end

	local raw = file:read("*all")
	file:close()

	if not raw or raw == "" then
		return
	end

	local ok, data = pcall(json.decode, raw)
	if not ok or type(data) ~= "table" then
		return
	end

	if data.mode then
		self.settings.mode = self:normalize_mode(data.mode)
	end

	if data.hide_risky_heists ~= nil then
		self.settings.hide_risky_heists = data.hide_risky_heists and true or false
	end
end

function SilentDLC:set_mode(mode)
	mode = self:normalize_mode(mode)
	self.settings.mode = mode
	self:save()
end

function SilentDLC:is_safe_mode()
	return self.settings.mode == self.MODE.SAFE
end

function SilentDLC:is_normal_mode()
	return self.settings.mode == self.MODE.NORMAL
end

function SilentDLC:is_risky_mode()
	return self.settings.mode == self.MODE.RISKY
end

-- legacy name
function SilentDLC:is_all_mode()
	return self:is_risky_mode()
end

function SilentDLC:should_block_risky()
	return self:is_safe_mode()
end

function SilentDLC:should_confirm_risky()
	return self:is_normal_mode()
end

function SilentDLC:should_mark_risky()
	-- badges in safe + normal; risky mode is unrestricted and unmarked
	return not self:is_risky_mode()
end

function SilentDLC:confirm(title, text, yes_clbk)
	title = title or "Silent DLC Unlocker"
	text = text or "Continue?"

	local function run_yes()
		if yes_clbk then
			yes_clbk()
		end
	end

	if QuickMenu and QuickMenu.new then
		QuickMenu:new(title, text, {
			{
				text = "Yes",
				callback = run_yes
			},
			{
				text = "No",
				is_cancel_button = true
			}
		}, true)

		return
	end

	if managers and managers.system_menu then
		managers.system_menu:show({
			title = title,
			text = text,
			button_list = {
				{
					text = "Yes",
					callback_func = run_yes
				},
				{
					text = "No",
					cancel_button = true
				}
			}
		})

		return
	end

	-- last resort: do not auto-accept risky actions
	self:notify(title .. ": " .. text .. " (no UI to confirm)")
end

-- Gate a CHEATER-risk action by mode.
-- returns: "allow" | "deny" | "pending"
function SilentDLC:gate_risky(message, on_allow)
	if self._pass_guard or self:is_risky_mode() then
		return "allow"
	end

	if self:is_safe_mode() then
		self:notify("Blocked: " .. tostring(message))

		return "deny"
	end

	-- normal: confirm
	self:confirm("CHEATER risk", tostring(message) .. "\n\nContinue anyway?", function()
		self._pass_guard = true
		local ok, err = pcall(on_allow)

		self._pass_guard = false

		if not ok then
			log("[SilentDLC] gate callback error: " .. tostring(err))
		end
	end)

	return "pending"
end

function SilentDLC:record_real_ownership(dlc_name, owned)
	if not dlc_name or dlc_name == "" then
		return
	end

	self.real_owned[dlc_name] = owned and true or false
end

function SilentDLC:is_app_owned(app_id)
	if not app_id then
		return false
	end

	local key = tostring(app_id)
	if self.owned_by_app[key] ~= nil then
		return self.owned_by_app[key]
	end

	local owned = false
	if SystemInfo:distribution() == Idstring("STEAM") and Steam and Steam.is_product_owned then
		owned = Steam:is_product_owned(app_id) and true or false
	end

	self.owned_by_app[key] = owned
	return owned
end

function SilentDLC:refresh_real_ownership()
	if not Global or not Global.dlc_manager or not Global.dlc_manager.all_dlc_data then
		return
	end

	local is_steam = SystemInfo:distribution() == Idstring("STEAM")
	self.owned_by_app = {}

	for dlc_name, dlc_data in pairs(Global.dlc_manager.all_dlc_data) do
		if dlc_data.external then
			self.real_owned[dlc_name] = true
		elseif not dlc_data.app_id then
			-- keep prior snapshot if we had one from _check_dlc_data
			if self.real_owned[dlc_name] == nil then
				self.real_owned[dlc_name] = false
			end
		elseif tostring(dlc_data.app_id) == "218620" then
			self.real_owned[dlc_name] = true
		elseif is_steam and Steam and Steam.is_product_owned then
			self.real_owned[dlc_name] = self:is_app_owned(dlc_data.app_id)
		elseif self.real_owned[dlc_name] == nil then
			self.real_owned[dlc_name] = false
		end
	end

	self._ownership_ready = true
end

function SilentDLC:is_dlc_really_owned(dlc_name)
	if not dlc_name or dlc_name == "" then
		return true
	end

	if not self._ownership_ready then
		self:refresh_real_ownership()
	end

	if self.real_owned[dlc_name] ~= nil then
		return self.real_owned[dlc_name]
	end

	local dlc_data = Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[dlc_name]
	if not dlc_data then
		-- Unknown id: treat as free/safe unless it looks like a global_value pack name
		return true
	end

	if dlc_data.external or not dlc_data.app_id or tostring(dlc_data.app_id) == "218620" then
		return true
	end

	if SystemInfo:distribution() == Idstring("STEAM") and Steam and Steam.is_product_owned then
		local owned = self:is_app_owned(dlc_data.app_id)
		self.real_owned[dlc_name] = owned
		return owned
	end

	return false
end

-- Mirrors NetworkPeer outfit verification categories.
-- TAG: masks, weapons, weapon mods, weapon colors, mask patterns/materials, melee, host DLC job
-- SAFE: outfits, gloves, perk decks, equipment/throwables, SOME unlockable mods
SilentDLC.TAG_CATEGORIES = {
	masks = true,
	materials = true,
	textures = true,
	colors = true,
	mask_colors = true,
	weapon = true,
	weapons = true,
	weapon_mods = true,
	weapon_skins = true,
	weapon_colors = true,
	melee_weapons = true,
	-- blackmarket gui categories
	primaries = true,
	secondaries = true
}

SilentDLC.SAFE_CATEGORIES = {
	player_styles = true,
	suit_variations = true,
	gloves = true,
	armor_skins = true,
	projectiles = true,
	grenades = true,
	armors = true,
	deployables = true
}

function SilentDLC:normalize_category(category)
	if not category then
		return nil
	end

	if category == "primaries" or category == "secondaries" then
		return "weapon"
	end

	if category == "weapon_skins" then
		return "weapon_colors"
	end

	if category == "colors" or category == "mask_colors" then
		return "materials"
	end

	if category == "weapons" then
		return "weapon"
	end

	return category
end

function SilentDLC:get_item_data(category, item_id)
	if not category or not item_id or item_id == "empty" or item_id == "" then
		return nil
	end

	category = self:normalize_category(category)

	if category == "weapon" then
		return tweak_data.weapon and tweak_data.weapon[item_id]
	end

	if category == "weapon_colors" or category == "weapon_skins" then
		return tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins and tweak_data.blackmarket.weapon_skins[item_id]
	end

	if category == "weapon_mods" then
		return tweak_data.blackmarket and tweak_data.blackmarket.weapon_mods and tweak_data.blackmarket.weapon_mods[item_id]
	end

	local bucket = tweak_data.blackmarket and tweak_data.blackmarket[category]
	return bucket and bucket[item_id]
end

-- SOME weapon mods skip ownership in NetworkPeer:_verify_content
function SilentDLC:item_data_skips_ownership(item_data)
	if not item_data then
		return false
	end

	if item_data.unlocked or item_data.is_a_unlockable or item_data.is_an_unlockable or item_data.skip_cheat_verification then
		return true
	end

	return false
end

function SilentDLC:resolve_dlc_from_global_value(global_value)
	if not global_value or global_value == "" or global_value == "normal" or global_value == "infamous" then
		return nil
	end

	if managers.dlc and managers.dlc.global_value_to_dlc then
		local dlc = managers.dlc:global_value_to_dlc(global_value)
		if dlc then
			return dlc
		end
	end

	-- Often global_value name == dlc name
	if Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[global_value] then
		return global_value
	end

	if tweak_data.dlc and tweak_data.dlc[global_value] then
		return global_value
	end

	return nil
end

function SilentDLC:collect_item_dlcs(item_data)
	local found = {}
	local list = {}

	local function add(dlc)
		if dlc and dlc ~= "" and not found[dlc] then
			found[dlc] = true
			table.insert(list, dlc)
		end
	end

	if not item_data then
		return list
	end

	add(item_data.dlc or self:resolve_dlc_from_global_value(item_data.global_value))

	if item_data.dlc_list then
		for _, dlc in pairs(item_data.dlc_list) do
			add(dlc)
		end
	end

	return list
end

function SilentDLC:dlc_is_risky(dlc)
	if not dlc then
		return false
	end

	local dlc_data = Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[dlc]

	-- No steam app / external / free base → not a tag source
	if dlc_data then
		if dlc_data.external or not dlc_data.app_id or tostring(dlc_data.app_id) == "218620" then
			return false
		end
	elseif tweak_data.dlc and tweak_data.dlc[dlc] and tweak_data.dlc[dlc].free then
		return false
	end

	return not self:is_dlc_really_owned(dlc)
end

function SilentDLC:outfit_dlc_is_risky(dlc)
	if SystemInfo:distribution() ~= Idstring("STEAM") then
		return false
	end

	return self:dlc_is_risky(dlc)
end

function SilentDLC:item_data_is_risky(item_data)
	if not item_data then
		return true, nil, "invalid_item"
	end

	if item_data.unatainable then
		return true, nil, "unattainable_item"
	end

	if self:item_data_skips_ownership(item_data) then
		return false
	end

	local dlc_list = self:collect_item_dlcs(item_data)
	if #dlc_list == 0 then
		return false
	end

	for _, dlc in ipairs(dlc_list) do
		if self:outfit_dlc_is_risky(dlc) then
			return true, dlc, "unowned_dlc"
		end
	end

	return false
end

function SilentDLC:verification_result(risky, reason, category, item_id, dlc)
	return {
		risky = risky and true or false,
		reason = reason,
		category = category,
		item_id = item_id,
		dlc = dlc
	}
end

function SilentDLC:verify_item(category, item_id)
	if not category or not item_id or item_id == "empty" or item_id == "" then
		return self:verification_result(false)
	end

	local raw = category
	category = self:normalize_category(category)

	if self.SAFE_CATEGORIES[category] or self.SAFE_CATEGORIES[raw] then
		return self:verification_result(false)
	end

	if not self.TAG_CATEGORIES[category] and not self.TAG_CATEGORIES[raw] then
		return self:verification_result(false)
	end

	local item_data = self:get_item_data(category, item_id)
	if category == "masks" and item_data and item_data.name_id == "bm_msk_cheat_error" then
		return self:verification_result(true, "invalid_item", category, item_id)
	end

	local risky, dlc, reason = self:item_data_is_risky(item_data)
	return self:verification_result(risky, reason, category, item_id, dlc)
end

function SilentDLC:is_item_risky(category, item_id)
	local result = self:verify_item(category, item_id)
	return result.risky, result.dlc, result.reason
end

function SilentDLC:is_item_risky_for_ui(category, item_id)
	if self:is_all_mode() then
		return false
	end

	return self:is_item_risky(category, item_id)
end

function SilentDLC:is_factory_weapon_risky(factory_id)
	if not factory_id or not managers.weapon_factory then
		return false
	end

	local weapon_id = managers.weapon_factory:get_weapon_id_by_factory_id(factory_id)
	return self:is_item_risky("weapon", weapon_id)
end

function SilentDLC:is_weapon_mod_risky(part_id)
	return self:is_item_risky("weapon_mods", part_id)
end

function SilentDLC:is_melee_risky(melee_id)
	return self:is_item_risky("melee_weapons", melee_id)
end

function SilentDLC:is_mask_risky(mask_id)
	return self:is_item_risky("masks", mask_id)
end

function SilentDLC:is_weapon_color_risky(color_id)
	local item_data = self:get_item_data("weapon_colors", color_id)
	if not item_data or not item_data.is_a_color_skin then
		return false
	end

	local result = self:verify_item("weapon_colors", color_id)
	return result.risky, result.dlc, result.reason
end

function SilentDLC:verify_crafted_weapon(crafted)
	if not crafted then
		return self:verification_result(false)
	end

	local weapon_id = crafted.weapon_id
	if not weapon_id and crafted.factory_id and managers.weapon_factory then
		weapon_id = managers.weapon_factory:get_weapon_id_by_factory_id(crafted.factory_id)
	end

	local weapon_result = self:verify_item("weapon", weapon_id)
	if weapon_result.risky then
		return weapon_result
	end

	if crafted.blueprint and managers.weapon_factory then
		local safe_blueprint = {}
		local default_bp = managers.weapon_factory:get_default_blueprint_by_factory_id(crafted.factory_id) or {}
		local cosmetics_id = crafted.cosmetics and crafted.cosmetics.id
		local skin_bp, is_color_skin = managers.weapon_factory:get_cosmetics_blueprint_by_weapon_id(weapon_id, cosmetics_id)

		for _, part_id in ipairs(default_bp) do
			safe_blueprint[part_id] = true
		end

		for _, part_id in ipairs(skin_bp or {}) do
			safe_blueprint[part_id] = true
		end

		for _, part_id in ipairs(crafted.blueprint) do
			if not safe_blueprint[part_id] then
				local part_result = self:verify_item("weapon_mods", part_id)
				if part_result.risky then
					return part_result
				end
			end
		end

		if is_color_skin and cosmetics_id then
			local cosmetics_data = self:get_item_data("weapon_colors", cosmetics_id)
			if cosmetics_data and cosmetics_data.is_a_color_skin then
				local color_result = self:verify_item("weapon_colors", cosmetics_id)
				if color_result.risky then
					return color_result
				end
			end
		end
	end

	return self:verification_result(false)
end

function SilentDLC:crafted_weapon_is_risky(crafted)
	local result = self:verify_crafted_weapon(crafted)
	return result.risky, result.category, result.item_id, result.dlc, result.reason
end

function SilentDLC:verify_crafted_mask(crafted)
	if not crafted then
		return self:verification_result(false)
	end

	local mask_result = self:verify_item("masks", crafted.mask_id)
	if mask_result.risky then
		return mask_result
	end

	if crafted.blueprint then
		local map = {
			material = "materials",
			pattern = "textures",
			color_a = "materials",
			color_b = "materials",
			color_c = "materials"
		}
		local mask_data = self:get_item_data("masks", crafted.mask_id)
		local default_blueprint = mask_data and mask_data.default_blueprint or {}

		for key, cat in pairs(map) do
			local part = crafted.blueprint[key]
			if part and part.id and default_blueprint[cat] ~= part.id then
				local part_result = self:verify_item(cat, part.id)
				if part_result.risky then
					return part_result
				end
			end
		end
	end

	return self:verification_result(false)
end


function SilentDLC:crafted_mask_is_risky(crafted)
	local result = self:verify_crafted_mask(crafted)
	return result.risky, result.category, result.item_id, result.dlc, result.reason
end

function SilentDLC:verify_character(character_id)
	if not character_id or not tweak_data or not tweak_data.blackmarket or not tweak_data.blackmarket.characters then
		return self:verification_result(false)
	end

	local character_data = tweak_data.blackmarket.characters[character_id]
	if not character_data or not character_data.dlc then
		return self:verification_result(false)
	end

	local dlc_data = Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[character_data.dlc]
	if not dlc_data or not dlc_data.app_id then
		return self:verification_result(false)
	end

	local owned = self:is_dlc_really_owned(character_data.dlc)
	if SystemInfo:distribution() == Idstring("STEAM") then
		owned = self:is_app_owned(dlc_data.app_id)
	end

	if not owned then
		return self:verification_result(true, "unowned_dlc", "characters", character_id, character_data.dlc)
	end

	return self:verification_result(false)
end

function SilentDLC:verify_job_to_host(job_id)
	if not job_id or not tweak_data or not tweak_data.narrative then
		return self:verification_result(false)
	end

	local job_tweak = tweak_data.narrative:job_data(job_id)
	if not job_tweak or not job_tweak.dlc then
		return self:verification_result(false)
	end

	if self:dlc_is_risky(job_tweak.dlc) then
		return self:verification_result(true, "unowned_dlc", "heists", job_id, job_tweak.dlc)
	end

	return self:verification_result(false)
end

function SilentDLC:is_job_risky_to_host(job_id)
	local result = self:verify_job_to_host(job_id)
	return result.risky, result.dlc, result.reason
end

function SilentDLC:should_hide_risky_heists()
	return self.settings.hide_risky_heists and true or false
end

function SilentDLC:should_mark_risky_heists()
	return self:should_mark_risky()
end

function SilentDLC:notify(text)
	if managers and managers.chat then
		managers.chat:feed_system_message(ChatManager.GAME, "[SilentDLC] " .. tostring(text))
		return
	end

	log("[SilentDLC] " .. tostring(text))
end

function SilentDLC:risk_label(category, item_id)
	local result = self:verify_item(category, item_id)
	if not result.risky then
		return nil
	end

	if result.dlc then
		return "CHEATER TAG if equipped (" .. tostring(result.dlc) .. ")"
	end

	return "CHEATER TAG if equipped"
end

function SilentDLC:item_display_name(result)
	if not result or not result.item_id then
		return "unknown item"
	end

	local data
	if result.category == "characters" then
		data = tweak_data.blackmarket and tweak_data.blackmarket.characters and tweak_data.blackmarket.characters[result.item_id]
	elseif result.category == "heists" then
		data = tweak_data.narrative and tweak_data.narrative:job_data(result.item_id)
	else
		data = self:get_item_data(result.category, result.item_id)
	end

	if data and data.name_id and managers and managers.localization then
		return managers.localization:text(data.name_id)
	end

	return tostring(result.item_id)
end

function SilentDLC:dlc_display_name(dlc, fallback)
	local global_value = tweak_data and tweak_data.lootdrop and tweak_data.lootdrop.global_values and tweak_data.lootdrop.global_values[dlc]
	local dlc_data = tweak_data and tweak_data.dlc and tweak_data.dlc[dlc]
	local name_id = global_value and global_value.name_id or dlc_data and dlc_data.name_id

	if name_id and managers and managers.localization then
		local name = managers.localization:text(name_id)
		if name and name ~= name_id and not string.find(name, "ERROR:", 1, true) then
			return name
		end
	end

	return fallback or "required DLC"
end

function SilentDLC:add_preflight_risk(risks, label, result)
	if result and result.risky then
		result.label = label
		table.insert(risks, result)
	end
end

function SilentDLC:collect_loadout_risks(include_host_character, job_id)
	local risks = {}
	if not managers or not managers.blackmarket then
		return risks
	end

	if managers.blackmarket.equipped_primary then
		self:add_preflight_risk(risks, "Primary", self:verify_crafted_weapon(managers.blackmarket:equipped_primary()))
	end

	if managers.blackmarket.equipped_secondary then
		self:add_preflight_risk(risks, "Secondary", self:verify_crafted_weapon(managers.blackmarket:equipped_secondary()))
	end

	if managers.blackmarket.equipped_mask then
		self:add_preflight_risk(risks, "Mask", self:verify_crafted_mask(managers.blackmarket:equipped_mask()))
	end

	if managers.blackmarket.equipped_melee_weapon then
		local melee_id = managers.blackmarket:equipped_melee_weapon()
		self:add_preflight_risk(risks, "Melee", self:verify_item("melee_weapons", melee_id))
	end

	if include_host_character and managers.blackmarket.equipped_character then
		self:add_preflight_risk(risks, "Host character", self:verify_character(managers.blackmarket:equipped_character()))
	end

	if job_id then
		self:add_preflight_risk(risks, "Hosted contract", self:verify_job_to_host(job_id))
	end

	return risks
end

function SilentDLC:format_preflight(action, risks)
	if #risks == 1 and risks[1].category == "heists" then
		local contract = risks[1]
		local heist_name = self:item_display_name(contract)
		return table.concat({
			"Hosting this heist without owning its DLC can give you the CHEATER tag:",
			"",
			heist_name,
			"Required DLC: " .. self:dlc_display_name(contract.dlc, heist_name .. " DLC")
		}, "\n")
	end

	local lines = {
		tostring(action) .. " with these risks can give you the CHEATER tag:",
		""
	}

	for _, result in ipairs(risks) do
		local detail = ""
		if result.category == "heists" then
			local heist_name = self:item_display_name(result)
			detail = " (unowned heist DLC: " .. self:dlc_display_name(result.dlc, heist_name .. " DLC") .. ")"
		elseif result.dlc then
			detail = " (unowned DLC: " .. self:dlc_display_name(result.dlc) .. ")"
		elseif result.reason then
			detail = " (" .. tostring(result.reason) .. ")"
		end
		table.insert(lines, "• " .. tostring(result.label or "Item") .. ": " .. self:item_display_name(result) .. detail)
	end

	return table.concat(lines, "\n")
end

function SilentDLC:guard_multiplayer(action, include_host_character, job_id, on_allow)
	if self._pass_guard or self:is_risky_mode() then
		return "allow"
	end

	local risks = self:collect_loadout_risks(include_host_character, job_id)
	if #risks == 0 then
		return "allow"
	end

	return self:gate_risky(self:format_preflight(action, risks), on_allow)
end

function SilentDLC:begin_grant_report()
	self.last_grant_report = {
		added = 0,
		repaired = 0,
		skipped = 0,
		errors = {}
	}
end

function SilentDLC:record_grant(kind, detail)
	self.last_grant_report = self.last_grant_report or {
		added = 0,
		repaired = 0,
		skipped = 0,
		errors = {}
	}

	if kind == "added" or kind == "repaired" or kind == "skipped" then
		self.last_grant_report[kind] = self.last_grant_report[kind] + 1
	end

	if detail and #self.last_grant_report.errors < 20 then
		table.insert(self.last_grant_report.errors, tostring(detail))
	end
end

function SilentDLC:grant_report_text()
	local report = self.last_grant_report
	if not report then
		return "No package grant has run in this session."
	end

	return "Package grant: " .. tostring(report.added) .. " added, " .. tostring(report.repaired) .. " repaired, " .. tostring(report.skipped) .. " skipped. See the SuperBLT log for details."
end

function SilentDLC:finish_grant_report()
	local report = self.last_grant_report
	if not report then
		return
	end

	log("[SilentDLC] " .. self:grant_report_text())
	for _, detail in ipairs(report.errors) do
		log("[SilentDLC] package detail: " .. detail)
	end
end

-- Resolve risk from raw BlackMarketGui slot data
function SilentDLC:slot_data_is_risky(data)
	if not data or self:is_all_mode() then
		return false
	end

	if data.empty_slot or data.locked_slot then
		return false
	end

	local category = data.category
	local name = data.name

	if not category or name == "empty" then
		return false
	end

	-- Safe categories never mark
	if self.SAFE_CATEGORIES[category] then
		return false
	end

	-- Crafted weapons (primary/secondary slots)
	if category == "primaries" or category == "secondaries" then
		if data.slot and managers.blackmarket and managers.blackmarket.get_crafted_category_slot then
			local crafted = managers.blackmarket:get_crafted_category_slot(category, data.slot)
			if crafted then
				return self:crafted_weapon_is_risky(crafted)
			end

			return false
		end

		-- Fallback: name as weapon id
		if name then
			return self:is_item_risky("weapon", name)
		end

		return false
	end

	-- Mask slots (crafted)
	if category == "masks" and data.slot and managers.blackmarket and managers.blackmarket.get_crafted_category_slot then
		local crafted = managers.blackmarket:get_crafted_category_slot("masks", data.slot)
		if crafted and crafted.mask_id then
			return self:crafted_mask_is_risky(crafted)
		end
	end

	if category == "characters" or category == "character" then
		return self:verify_character(name).risky
	end

	if category == "melee_weapons" then
		return self:is_melee_risky(name)
	end

	if category == "weapon_mods" or category == "mod" then
		return self:is_weapon_mod_risky(name)
	end

	if category == "weapon_skins" or category == "weapon_colors" then
		return self:is_weapon_color_risky(name)
	end

	if category == "materials" or category == "textures" or category == "colors" or category == "mask_colors" then
		return self:is_item_risky(category, name)
	end

	if category == "masks" then
		return self:is_mask_risky(name)
	end

	return false
end

SilentDLC:load()
