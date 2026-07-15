if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local RISK_COLOR = Color(1, 1, 0.2, 0.2)
local BADGE_BG = Color(0.9, 0.55, 0.05, 0.05)

-- Each hook file load only installs what is available so far.

-- ---------------------------------------------------------------------------
-- Crime.Net map: hide unowned DLC heists from offline/host job pool
-- ---------------------------------------------------------------------------
if not SilentDLC._heist_jobs_hooked and CrimeNetManager and CrimeNetManager._get_jobs_by_jc then
	SilentDLC._heist_jobs_hooked = true

	local old_get_jobs = CrimeNetManager._get_jobs_by_jc

	function CrimeNetManager:_get_jobs_by_jc()
		local t = old_get_jobs(self)

		if not SilentDLC:should_hide_risky_heists() or type(t) ~= "table" then
			return t
		end

		for jc, list in pairs(t) do
			if type(list) == "table" then
				local filtered = {}

				for _, job in ipairs(list) do
					if job and job.job_id and not SilentDLC:is_job_risky_to_host(job.job_id) then
						table.insert(filtered, job)
					end
				end

				t[jc] = filtered
			end
		end

		return t
	end
end

-- ---------------------------------------------------------------------------
-- Crime.Net map pins: [CHEATER] when YOU would get tagged for hosting
-- ---------------------------------------------------------------------------
if not SilentDLC._heist_gui_hooked and CrimeNetGui and CrimeNetGui._create_job_gui then
	SilentDLC._heist_gui_hooked = true

	local old_create = CrimeNetGui._create_job_gui

	function CrimeNetGui:_create_job_gui(data, type, fixed_x, fixed_y, fixed_location)
		local job = old_create(self, data, type, fixed_x, fixed_y, fixed_location)

		if not job or not data or not data.job_id then
			return job
		end

		if type == "server" or type == "crime_spree" then
			return job
		end

		if not SilentDLC:should_mark_risky_heists() then
			return job
		end

		if not SilentDLC:is_job_risky_to_host(data.job_id) then
			return job
		end

		job._silent_dlc_risky_host = true

		if job.side_panel and alive(job.side_panel) then
			local job_name = job.side_panel:child("job_name")

			if alive(job_name) then
				local text = job_name:text() or ""

				if not string.find(text, "CHEATER", 1, true) then
					job_name:set_text(text .. " [CHEATER]")
				end

				job_name:set_color(RISK_COLOR)
			end

			local host_name = job.side_panel:child("host_name")

			if alive(host_name) then
				host_name:set_color(RISK_COLOR)
			end
		end

		if job.marker_panel and alive(job.marker_panel) then
			local marker = job.marker_panel:child("marker_dot") or job.marker_panel:children()[1]

			if alive(marker) and marker.set_color then
				marker:set_color(RISK_COLOR)
			end
		end

		return job
	end
end

-- ---------------------------------------------------------------------------
-- Contract Broker rows: persistent CHEATER badge before opening a contract
-- ---------------------------------------------------------------------------
if not SilentDLC._contract_broker_hooked and ContractBrokerHeistItem and ContractBrokerHeistItem.init then
	SilentDLC._contract_broker_hooked = true

	Hooks:PostHook(ContractBrokerHeistItem, "init", "SilentDLC_ContractBrokerMark", function(self)
		local job_id = self._job_data and self._job_data.job_id

		if not job_id or not SilentDLC:should_mark_risky_heists() or not SilentDLC:is_job_risky_to_host(job_id) then
			return
		end

		if not alive(self._panel) or alive(self._silent_dlc_badge) then
			return
		end

		local badge = self._panel:panel({
			name = "silent_dlc_cheater_badge",
			layer = 50,
			w = 68,
			h = 18
		})
		badge:set_left(4)
		badge:set_top(14)

		badge:rect({
			color = BADGE_BG,
			halign = "grow",
			valign = "grow"
		})

		badge:text({
			text = "CHEATER",
			font = tweak_data.menu.pd2_small_font,
			font_size = 14,
			color = Color.white,
			align = "center",
			vertical = "center",
			layer = 1,
			w = badge:w(),
			h = badge:h()
		})

		self._silent_dlc_badge = badge
	end)
end

-- ---------------------------------------------------------------------------
-- Contract details popup
-- ---------------------------------------------------------------------------
if not SilentDLC._heist_contract_hooked and CrimeNetContractGui and CrimeNetContractGui.init then
	SilentDLC._heist_contract_hooked = true

	Hooks:PostHook(CrimeNetContractGui, "init", "SilentDLC_ContractMark", function(self, ws, fullscreen_ws, node)
		if not SilentDLC:should_mark_risky_heists() then
			return
		end

		local job_data = node and node:parameters() and node:parameters().menu_component_data
		local job_id = job_data and job_data.job_id

		if not job_id or not SilentDLC:is_job_risky_to_host(job_id) then
			return
		end

		if alive(self._contact_text_header) then
			local text = self._contact_text_header:text() or ""

			if not string.find(text, "CHEATER", 1, true) then
				self._contact_text_header:set_text(text .. "  [CHEATER TAG IF HOST]")
			end

			self._contact_text_header:set_color(RISK_COLOR)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Hosting unowned DLC heists: Safe blocks, Normal confirms, Risky allows
-- ---------------------------------------------------------------------------
if not SilentDLC._heist_start_hooked and MenuCallbackHandler and MenuCallbackHandler.start_job then
	SilentDLC._heist_start_hooked = true

	local old_start = MenuCallbackHandler.start_job

	function MenuCallbackHandler:start_job(job_data)
		if SilentDLC._pass_guard then
			return old_start(self, job_data)
		end

		local job_id = job_data and job_data.job_id
		local result = SilentDLC:guard_multiplayer("Hosting", true, job_id, function()
			old_start(self, job_data)
		end)

		if result ~= "allow" then
			return
		end

		return old_start(self, job_data)
	end
end
