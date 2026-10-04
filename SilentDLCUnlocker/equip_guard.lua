if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local old_equip_weapon = BlackMarketManager.equip_weapon
function BlackMarketManager:equip_weapon(category, slot, skip_outfit)
	if SilentDLC._pass_guard or not SilentDLC:is_multiplayer_active() then
		return old_equip_weapon(self, category, slot, skip_outfit)
	end

	if slot then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items[category] and self._global.crafted_items[category][slot]

		local risk = crafted and SilentDLC:verify_crafted_weapon(crafted)
		if risk and risk.risky then
			local result = SilentDLC:gate_risky(SilentDLC:format_preflight("Equipping this weapon online", { risk }), function()
				old_equip_weapon(self, category, slot, skip_outfit)
			end)

			if result ~= "allow" then
				return false
			end
		end
	end

	return old_equip_weapon(self, category, slot, skip_outfit)
end

local old_equip_mask = BlackMarketManager.equip_mask
function BlackMarketManager:equip_mask(slot, skip_outfit)
	if SilentDLC._pass_guard or not SilentDLC:is_multiplayer_active() then
		return old_equip_mask(self, slot, skip_outfit)
	end

	if slot and slot ~= 1 then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items.masks and self._global.crafted_items.masks[slot]

		local risk = crafted and SilentDLC:verify_crafted_mask(crafted)
		if risk and risk.risky then
			local result = SilentDLC:gate_risky(SilentDLC:format_preflight("Equipping this mask online", { risk }), function()
				old_equip_mask(self, slot, skip_outfit)
			end)

			if result ~= "allow" then
				return false
			end
		end
	end

	return old_equip_mask(self, slot, skip_outfit)
end

local old_equip_melee = BlackMarketManager.equip_melee_weapon
function BlackMarketManager:equip_melee_weapon(melee_weapon_id, skip_outfit)
	if SilentDLC._pass_guard or not SilentDLC:is_multiplayer_active() then
		return old_equip_melee(self, melee_weapon_id, skip_outfit)
	end

	local risk = SilentDLC:verify_item("melee_weapons", melee_weapon_id)
	if risk.risky then
		local result = SilentDLC:gate_risky(SilentDLC:format_preflight("Equipping this melee weapon online", { risk }), function()
			old_equip_melee(self, melee_weapon_id, skip_outfit)
		end)

		if result ~= "allow" then
			return false
		end
	end

	return old_equip_melee(self, melee_weapon_id, skip_outfit)
end

local old_equip_character = BlackMarketManager.equip_character
if old_equip_character then
	function BlackMarketManager:equip_character(character_name)
		if SilentDLC._pass_guard or not SilentDLC:is_multiplayer_active() then
			return old_equip_character(self, character_name)
		end

		local is_hosting = Network:is_server()
		local result = SilentDLC:verify_character(character_name)
		if is_hosting and result.risky then
			local gate = SilentDLC:gate_risky(SilentDLC:format_preflight("Changing character while hosting", { result }), function()
				old_equip_character(self, character_name)
			end)

			if gate ~= "allow" then
				return false
			end
		end

		return old_equip_character(self, character_name)
	end
end

local old_buy_and_modify = BlackMarketManager.buy_and_modify_weapon
if old_buy_and_modify then
	function BlackMarketManager:buy_and_modify_weapon(category, slot, global_value, part_id, free_of_charge, no_consume, loading)
		if SilentDLC._pass_guard or not SilentDLC:is_multiplayer_active() then
			return old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
		end

		local risk = SilentDLC:verify_item("weapon_mods", part_id)
		if risk.risky then
			local result = SilentDLC:gate_risky(SilentDLC:format_preflight("Attaching this component online", { risk }), function()
				old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
			end)

			if result ~= "allow" then
				return false
			end
		end

		return old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
	end
end
