if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local function wrap_matchmaking(class_name)
	local class_table = _G[class_name]
	if not class_table then
		return
	end

	local join_key = "_session_join_" .. class_name
	if class_table.join_server_with_check and not SilentDLC[join_key] then
		SilentDLC[join_key] = true
		local old_join = class_table.join_server_with_check

		function class_table:join_server_with_check(...)
			if SilentDLC._pass_guard then
				return old_join(self, ...)
			end

			local args = { ... }
			local count = select("#", ...)
			local result = SilentDLC:guard_multiplayer("Joining", false, nil, function()
				old_join(self, unpack(args, 1, count))
			end)

			if result ~= "allow" then
				return false
			end

			return old_join(self, ...)
		end
	end

	-- Crime.Net Quickplay calls join_server directly, skipping the check above.
	-- Other callers reach join_server through join_server_with_check.
	local quick_key = "_session_quickplay_" .. class_name
	if class_table.join_server and not SilentDLC[quick_key] then
		SilentDLC[quick_key] = true
		local old_join_server = class_table.join_server

		function class_table:join_server(room_id, skip_showing_dialog, quickplay, ...)
			if not quickplay or SilentDLC._pass_guard then
				return old_join_server(self, room_id, skip_showing_dialog, quickplay, ...)
			end

			local args = { ... }
			local count = select("#", ...)
			local result = SilentDLC:guard_multiplayer("Joining", false, nil, function()
				old_join_server(self, room_id, skip_showing_dialog, quickplay, unpack(args, 1, count))
			end)

			if result ~= "allow" then
				return false
			end

			return old_join_server(self, room_id, skip_showing_dialog, quickplay, ...)
		end
	end

	local host_key = "_session_host_" .. class_name
	if class_table.create_lobby and not SilentDLC[host_key] then
		SilentDLC[host_key] = true
		local old_create = class_table.create_lobby

		function class_table:create_lobby(...)
			if SilentDLC._pass_guard then
				return old_create(self, ...)
			end

			local args = { ... }
			local count = select("#", ...)
			local job_id = managers.job and managers.job:current_job_id()
			local result = SilentDLC:guard_multiplayer("Hosting", true, job_id, function()
				old_create(self, unpack(args, 1, count))
			end)

			if result ~= "allow" then
				return false
			end

			return old_create(self, ...)
		end
	end
end

wrap_matchmaking("NetworkMatchMakingSTEAM")
