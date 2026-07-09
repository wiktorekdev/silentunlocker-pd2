if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local MENU_ID = "silent_dlc_menu"

Hooks:Add("LocalizationManagerPostInit", "SilentDLC_Localization", function(loc)
	loc:add_localized_strings({
		silent_dlc_menu_title = "Silent DLC Unlocker",
		silent_dlc_menu_desc = "Unlock modes, heist filters, CHEATER-tag tools",
		silent_dlc_mode_title = "Filter mode",
		silent_dlc_mode_desc = "safe = block risky equip | mark = show risk, allow equip | all = no filter",
		silent_dlc_mode_safe = "Safe (recommended)",
		silent_dlc_mode_mark = "Mark only",
		silent_dlc_mode_all = "Unlock all (no filter)",
		silent_dlc_block_jobs_title = "Block hosting unowned DLC heists",
		silent_dlc_block_jobs_desc = "Hosting DLC contracts you do not own can CHEATER-tag you",
		silent_dlc_hide_jobs_title = "Hide risky heists on Crime.Net",
		silent_dlc_hide_jobs_desc = "Do not show unowned DLC heist pins on the Crime.Net map (host pool)"
	})
end)

Hooks:Add("MenuManagerInitialize", "SilentDLC_MenuInit", function(menu_manager)
	SilentDLC:load()

	MenuCallbackHandler.silent_dlc_set_mode = function(self, item)
		local modes = {
			SilentDLC.MODE.SAFE,
			SilentDLC.MODE.MARK,
			SilentDLC.MODE.ALL
		}
		SilentDLC:set_mode(modes[item:value()] or SilentDLC.MODE.SAFE)
	end

	MenuCallbackHandler.silent_dlc_set_block_jobs = function(self, item)
		SilentDLC.settings.block_risky_host_jobs = item:value() == "on"
		SilentDLC:save()
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
	local mode_value = 1
	if SilentDLC.settings.mode == SilentDLC.MODE.MARK then
		mode_value = 2
	elseif SilentDLC.settings.mode == SilentDLC.MODE.ALL then
		mode_value = 3
	end

	MenuHelper:AddMultipleChoice({
		id = "silent_dlc_mode",
		title = "silent_dlc_mode_title",
		desc = "silent_dlc_mode_desc",
		callback = "silent_dlc_set_mode",
		items = {
			"silent_dlc_mode_safe",
			"silent_dlc_mode_mark",
			"silent_dlc_mode_all"
		},
		value = mode_value,
		menu_id = MENU_ID,
		priority = 100
	})

	MenuHelper:AddToggle({
		id = "silent_dlc_block_jobs",
		title = "silent_dlc_block_jobs_title",
		desc = "silent_dlc_block_jobs_desc",
		callback = "silent_dlc_set_block_jobs",
		value = SilentDLC.settings.block_risky_host_jobs,
		menu_id = MENU_ID,
		priority = 90
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
