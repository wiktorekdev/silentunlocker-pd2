local distribution = "STEAM"
local owned_apps = {
	[100] = true,
	[200] = false
}
local steam_queries = 0

ModPath = ""
SavePath = ""
json = {
	encode = function()
		return "{}"
	end,
	decode = function()
		return {}
	end
}
log = function()
end
Idstring = function(value)
	return value
end
SystemInfo = {
	distribution = function()
		return distribution
	end
}
Steam = {
	is_product_owned = function(self, app_id)
		steam_queries = steam_queries + 1
		return owned_apps[tonumber(app_id)] or false
	end
}

local original_open = io.open
io.open = function()
	return nil
end

Global = {
	dlc_manager = {
		all_dlc_data = {
			owned = { app_id = 100 },
			unowned = { app_id = 200 },
			base = { app_id = 218620 },
			external = { app_id = 200, external = true }
		}
	}
}

tweak_data = {
	dlc = {},
	weapon = {
		weapon_owned = { dlc = "owned" }
	},
	blackmarket = {
		weapon_mods = {
			owned_part = { dlc = "owned" },
			unowned_part = { dlc = "unowned" },
			skipped_part = { dlc = "unowned", skip_cheat_verification = true },
			primary_wins = { dlc = "owned", global_value = "unowned" },
			ignored_global_values = { global_values = { "unowned" } },
			multi_dlc = { dlc = "owned", dlc_list = { "unowned" } }
		},
		weapon_skins = {
			regular_skin = { dlc = "unowned" },
			color_skin = { dlc = "unowned", is_a_color_skin = true }
		},
		masks = {
			mask_owned = {
				dlc = "owned",
				default_blueprint = {
					materials = "default_material",
					textures = "default_pattern"
				}
			}
		},
		materials = {
			default_material = { dlc = "unowned" },
			unowned_color = { dlc = "unowned" }
		},
		textures = {
			default_pattern = { dlc = "unowned" }
		},
		melee_weapons = {
			melee_owned = { dlc = "owned" }
		},
		characters = {
			character_unowned = { dlc = "unowned", name_id = "character_unowned" }
		}
	},
	lootdrop = {
		global_values = {
			unowned = { name_id = "dlc_unowned_name" },
			missing_name = { name_id = "bm_global_value_missing" }
		}
	},
	narrative = {
		job_data = function(self, job_id)
			if job_id == "job_unowned" then
				return { dlc = "unowned", name_id = "job_unowned" }
			end
			return {}
		end
	}
}

managers = {
	dlc = {
		global_value_to_dlc = function(self, value)
			return value
		end
	},
	weapon_factory = {
		get_weapon_id_by_factory_id = function()
			return "weapon_owned"
		end,
		get_default_blueprint_by_factory_id = function()
			return { "default_part" }
		end,
		get_cosmetics_blueprint_by_weapon_id = function(self, weapon_id, cosmetic_id)
			if cosmetic_id == "regular_skin" then
				return { "unowned_part" }, false
			end
			if cosmetic_id == "color_skin" then
				return {}, true
			end
			return {}, false
		end
	},
	localization = {
		text = function(self, value)
			if value == "job_unowned" then
				return "The Test Heist"
			end
			if value == "dlc_unowned_name" then
				return "The Test Heist DLC"
			end
			return value
		end
	}
}

dofile("SilentDLCUnlocker/core.lua")
io.open = original_open

local function expect(value, message)
	if not value then
		error(message or "expectation failed", 2)
	end
end

local function expect_safe(result, message)
	expect(not result.risky, message or "expected safe result")
end

local function expect_risky(result, reason)
	expect(result.risky, "expected risky result")
	if reason then
		expect(result.reason == reason, "expected reason " .. reason .. ", got " .. tostring(result.reason))
	end
end

SilentDLC:refresh_real_ownership()
expect(steam_queries == 2, "ownership queries should be cached by app id")

expect_safe(SilentDLC:verify_item("weapon_mods", "skipped_part"), "skip_cheat_verification should be safe")
expect_safe(SilentDLC:verify_item("weapon_mods", "primary_wins"), "dlc should take precedence over global_value")
expect_safe(SilentDLC:verify_item("weapon_mods", "ignored_global_values"), "global_values should not be verified")
expect_risky(SilentDLC:verify_item("weapon_mods", "multi_dlc"), "unowned_dlc")
expect_risky(SilentDLC:verify_item("weapon_mods", "missing_part"), "invalid_item")

expect_safe(SilentDLC:verify_crafted_weapon({
	weapon_id = "weapon_owned",
	factory_id = "factory",
	blueprint = { "default_part", "unowned_part" },
	cosmetics = { id = "regular_skin" }
}), "skin-supplied parts and regular skins should be safe")

expect_risky(SilentDLC:verify_crafted_weapon({
	weapon_id = "weapon_owned",
	factory_id = "factory",
	blueprint = { "default_part" },
	cosmetics = { id = "color_skin" }
}), "unowned_dlc")

expect_safe(SilentDLC:verify_crafted_mask({
	mask_id = "mask_owned",
	blueprint = {
		material = { id = "default_material" },
		pattern = { id = "default_pattern" }
	}
}), "default mask blueprint parts should be safe")

expect_risky(SilentDLC:verify_crafted_mask({
	mask_id = "mask_owned",
	blueprint = {
		color_c = { id = "unowned_color" }
	}
}), "unowned_dlc")

expect_risky(SilentDLC:verify_crafted_mask({
	mask_id = "mask_owned",
	blueprint = {
		color = { id = "legacy_color" }
	}
}), "invalid_item")

expect_risky(SilentDLC:verify_character("character_unowned"), "unowned_dlc")
expect_risky(SilentDLC:verify_job_to_host("job_unowned"), "unowned_dlc")

local contract_warning = SilentDLC:format_preflight("Hosting", {
	SilentDLC:verify_job_to_host("job_unowned")
})
expect(string.find(contract_warning, "Hosting this heist without owning its DLC", 1, true), "contract warning should explain the hosting risk")
expect(string.find(contract_warning, "Required DLC: The Test Heist DLC", 1, true), "contract warning should show the localized DLC name")
expect(not string.find(contract_warning, "[unowned]", 1, true), "contract warning should not expose an internal DLC key")
expect(SilentDLC:dlc_display_name("missing_name", "Fallback Heist DLC") == "Fallback Heist DLC", "missing localization should use the supplied fallback")

managers.blackmarket = {
	get_crafted_category_slot = function()
		return nil
	end,
	equipped_primary = function()
		return {
			weapon_id = "weapon_owned",
			factory_id = "factory",
			blueprint = { "unowned_part" }
		}
	end,
	equipped_secondary = function()
		return {
			weapon_id = "weapon_owned",
			factory_id = "factory",
			blueprint = { "default_part" }
		}
	end,
	equipped_mask = function()
		return {
			mask_id = "mask_owned",
			blueprint = {
				material = { id = "default_material" }
			}
		}
	end,
	equipped_melee_weapon = function()
		return "melee_owned"
	end,
	equipped_character = function()
		return "character_unowned"
	end
}

expect(not SilentDLC:slot_data_is_risky({
	category = "primaries",
	slot = 2,
	name = "bm_menu_btn_buy_new_weapon",
	empty_slot = true
}), "empty weapon slots should never be marked")
expect(not SilentDLC:slot_data_is_risky({
	category = "primaries",
	slot = 9,
	name = "bm_menu_btn_buy_weapon_slot",
	locked_slot = true
}), "locked weapon slots should never be marked")
expect(not SilentDLC:slot_data_is_risky({
	category = "secondaries",
	slot = 3,
	name = "unknown_placeholder"
}), "uncrafted weapon slots should not fall back to item verification")

local join_risks = SilentDLC:collect_loadout_risks(false)
expect(#join_risks == 1 and join_risks[1].label == "Primary", "join preflight should report risky outfit items only")
local host_risks = SilentDLC:collect_loadout_risks(true, "job_unowned")
expect(#host_risks == 3, "host preflight should add character and contract risks")

distribution = "EPIC"
expect_safe(SilentDLC:verify_item("weapon_mods", "unowned_part"), "Epic outfits should not use Steam outfit verification")

print("Verifier parity tests passed.")
