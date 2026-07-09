if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local MENU_ID = "silent_dlc_menu"

Hooks:Add("LocalizationManagerPostInit", "SilentDLC_Localization", function(loc)
	loc:add_localized_strings({
		silent_dlc_menu_title = "Silent DLC Unlocker",
		silent_dlc_menu_desc = "Safe / Normal / Risky modes and Crime.Net filters",
		silent_dlc_mode_title = "Mode",
		silent_dlc_mode_desc = "Safe blocks risk | Normal asks to confirm | Risky no limits",
		silent_dlc_mode_safe = "Safe (block risk)",
		silent_dlc_mode_normal = "Normal (confirm popups)",
		silent_dlc_mode_risky = "Risky (no limits)",
		silent_dlc_hide_jobs_title = "Hide risky heists on Crime.Net",
		silent_dlc_hide_jobs_desc = "Do not show unowned DLC heist pins on the Crime.Net map (host pool)"
	})
end)

Hooks:Add("MenuManagerInitialize", "SilentDLC_MenuInit", function(menu_manager)
	SilentDLC:load()

	MenuCallbackHandler.silent_dlc_set_mode = function(self, item)
		local modes = {
			SilentDLC.MODE.SAFE,
			SilentDLC.MODE.NORMAL,
			SilentDLC.MODE.RISKY
		}
		SilentDLC:set_mode(modes[item:value()] or SilentDLC.MODE.SAFE)
	end

	MenuCallbackHandler.silent_dlc_set_hide_jobs = function(self, item)
		SilentDLC.settings.hide_risky_heists = item:value() == "on"
		SilentDLC:save()
	end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "SilentDLC_SetupMenu", function(menu_manager, nodes)
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "SilentDLC_PopulateMenu", function(menu_manager, nodes)
	local mode = SilentDLC:normalize_mode(SilentDLC.settings.mode)
	SilentDLC.settings.mode = mode

	local mode_value = 1
	if mode == SilentDLC.MODE.NORMAL then
		mode_value = 2
	elseif mode == SilentDLC.MODE.RISKY then
		mode_value = 3
	end

	MenuHelper:AddMultipleChoice({
		id = "silent_dlc_mode",
		title = "silent_dlc_mode_title",
		desc = "silent_dlc_mode_desc",
		callback = "silent_dlc_set_mode",
		items = {
			"silent_dlc_mode_safe",
			"silent_dlc_mode_normal",
			"silent_dlc_mode_risky"
		},
		value = mode_value,
		menu_id = MENU_ID,
		priority = 100
	})

	MenuHelper:AddToggle({
		id = "silent_dlc_hide_jobs",
		title = "silent_dlc_hide_jobs_title",
		desc = "silent_dlc_hide_jobs_desc",
		callback = "silent_dlc_set_hide_jobs",
		value = SilentDLC.settings.hide_risky_heists,
		menu_id = MENU_ID,
		priority = 80
	})
end)

Hooks:Add("MenuManagerBuildCustomMenus", "SilentDLC_BuildMenu", function(menu_manager, nodes)
	nodes[MENU_ID] = MenuHelper:BuildMenu(MENU_ID)

	local parent = nodes.blt_options or nodes.lua_mod_options_menu or nodes.options
	if parent then
		MenuHelper:AddMenuItem(parent, MENU_ID, "silent_dlc_menu_title", "silent_dlc_menu_desc")
	end
end)
