if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local old_equip_weapon = BlackMarketManager.equip_weapon
function BlackMarketManager:equip_weapon(category, slot, skip_outfit)
	if SilentDLC._pass_guard then
		return old_equip_weapon(self, category, slot, skip_outfit)
	end

	if slot then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items[category] and self._global.crafted_items[category][slot]

		if crafted and SilentDLC:crafted_weapon_is_risky(crafted) then
			local result = SilentDLC:gate_risky("Equipping this would give CHEATER TAG (DLC weapon / mod / color).", function()
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
	if SilentDLC._pass_guard then
		return old_equip_mask(self, slot, skip_outfit)
	end

	if slot and slot ~= 1 then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items.masks and self._global.crafted_items.masks[slot]

		if crafted and SilentDLC:crafted_mask_is_risky(crafted) then
			local result = SilentDLC:gate_risky("Equipping this would give CHEATER TAG (DLC mask / material / pattern).", function()
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
	if SilentDLC._pass_guard then
		return old_equip_melee(self, melee_weapon_id, skip_outfit)
	end

	if SilentDLC:is_melee_risky(melee_weapon_id) then
		local result = SilentDLC:gate_risky("Equipping this would give CHEATER TAG (DLC melee).", function()
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
		if SilentDLC._pass_guard then
			return old_equip_character(self, character_name)
		end

		local is_hosting = managers.network and managers.network:session() and Network:is_server()
		local result = SilentDLC:verify_character(character_name)
		if is_hosting and result.risky then
			local gate = SilentDLC:gate_risky("Changing to this unowned DLC character while hosting can give you the CHEATER tag.", function()
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
		if SilentDLC._pass_guard then
			return old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
		end

		if SilentDLC:is_weapon_mod_risky(part_id) then
			local result = SilentDLC:gate_risky("Attaching this would give CHEATER TAG (DLC weapon mod).", function()
				old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
			end)

			if result ~= "allow" then
				return false
			end
		end

		return old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume, loading)
	end
end
