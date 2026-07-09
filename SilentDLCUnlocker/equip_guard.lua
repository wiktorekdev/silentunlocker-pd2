if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local function notify(text)
	if managers and managers.chat then
		managers.chat:feed_system_message(ChatManager.GAME, "[SilentDLC] " .. text)
		return
	end

	log("[SilentDLC] " .. tostring(text))
end

local function should_guard()
	return SilentDLC:should_block_risky()
end

local old_equip_weapon = BlackMarketManager.equip_weapon
function BlackMarketManager:equip_weapon(category, slot, skip_outfit)
	if should_guard() and slot then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items[category] and self._global.crafted_items[category][slot]

		if crafted and SilentDLC:crafted_weapon_is_risky(crafted) then
			notify("Blocked: would give CHEATER TAG (DLC weapon / mod / color)")
			return false
		end
	end

	return old_equip_weapon(self, category, slot, skip_outfit)
end

local old_equip_mask = BlackMarketManager.equip_mask
function BlackMarketManager:equip_mask(slot, skip_outfit)
	if should_guard() and slot and slot ~= 1 then
		local crafted = self._global and self._global.crafted_items and self._global.crafted_items.masks and self._global.crafted_items.masks[slot]

		if crafted and SilentDLC:crafted_mask_is_risky(crafted) then
			notify("Blocked: would give CHEATER TAG (DLC mask / material / pattern)")
			return false
		end
	end

	return old_equip_mask(self, slot, skip_outfit)
end

local old_equip_melee = BlackMarketManager.equip_melee_weapon
function BlackMarketManager:equip_melee_weapon(melee_weapon_id, skip_outfit)
	if should_guard() and SilentDLC:is_melee_risky(melee_weapon_id) then
		notify("Blocked: would give CHEATER TAG (DLC melee)")
		return false
	end

	return old_equip_melee(self, melee_weapon_id, skip_outfit)
end

local old_buy_and_modify = BlackMarketManager.buy_and_modify_weapon
if old_buy_and_modify then
	function BlackMarketManager:buy_and_modify_weapon(category, slot, global_value, part_id, free_of_charge, no_consume)
		if should_guard() and SilentDLC:is_weapon_mod_risky(part_id) then
			notify("Blocked: would give CHEATER TAG (DLC weapon mod)")
			return false
		end

		return old_buy_and_modify(self, category, slot, global_value, part_id, free_of_charge, no_consume)
	end
end
