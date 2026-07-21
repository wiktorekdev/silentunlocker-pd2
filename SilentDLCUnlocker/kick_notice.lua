if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

-- ============================================================================
-- Explain mid-game disconnects.
-- ----------------------------------------------------------------------------
-- Remote clients always verify equipped items against REAL platform ownership
-- (NetworkPeer:_verify_content -> Steam:is_user_product_owned). Verification
-- re-runs when the asynchronous Steam ticket check completes, which can be
-- minutes into a heist, and hosts auto-kick detected cheaters by default
-- (Global.game_settings.auto_kick). A local mod cannot change what other
-- players' games report, so the best we can do is explain the kick.
-- ============================================================================
Hooks:PostHook(BaseNetworkSession, "on_peer_kicked", "SilentDLC_KickNotice", function(self, peer, peer_id, message_id)
	local ok, err = pcall(function()
		local session = managers.network and managers.network:session()
		local local_peer = session and session:local_peer()

		if not local_peer or peer ~= local_peer then
			return
		end

		local risks = SilentDLC:collect_loadout_risks(false)

		if #risks == 0 then
			return
		end

		SilentDLC:alert("Disconnected", "You were kicked while using CHEATER-risk items. The host's game detected unowned DLC and removed you; this can happen a few minutes into a game when the ownership re-check finishes.\n\nTo stay connected: play offline, host your own lobby, or unequip the flagged items.\n\n" .. SilentDLC:format_preflight("Playing", risks))
	end)

	if not ok then
		log("[SilentDLC] kick notice error: " .. tostring(err))
	end
end)
