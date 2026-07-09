if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local RISK_COLOR = Color(1, 1, 0.2, 0.2)

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
-- Block hosting unowned DLC heists
-- ---------------------------------------------------------------------------
if not SilentDLC._heist_start_hooked and MenuCallbackHandler and MenuCallbackHandler.start_job then
	SilentDLC._heist_start_hooked = true

	local old_start = MenuCallbackHandler.start_job

	function MenuCallbackHandler:start_job(job_data)
		if job_data and job_data.job_id and SilentDLC:should_block_host_job(job_data.job_id) then
			SilentDLC:notify("Blocked host: unowned DLC heist would CHEATER-tag you (" .. tostring(job_data.job_id) .. ")")

			return
		end

		return old_start(self, job_data)
	end
end

if not SilentDLC._heist_quick_hooked and MenuCallbackHandler and MenuCallbackHandler.play_quick_start_job then
	SilentDLC._heist_quick_hooked = true

	local old_quick = MenuCallbackHandler.play_quick_start_job

	function MenuCallbackHandler:play_quick_start_job(item)
		local job_id = item and item.parameter and item:parameter("job_id")

		if job_id and SilentDLC:should_block_host_job(job_id) then
			SilentDLC:notify("Blocked host: unowned DLC heist would CHEATER-tag you (" .. tostring(job_id) .. ")")

			return
		end

		return old_quick(self, item)
	end
end
