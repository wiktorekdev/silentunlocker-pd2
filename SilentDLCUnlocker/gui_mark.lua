if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local RISK_COLOR = Color(1, 1, 0.15, 0.15)
local BADGE_BG = Color(0.9, 0.55, 0.05, 0.05)
local BADGE_TEXT = "CHEATER"

local function apply_slot_mark(slot)
	if not slot or not alive(slot._panel) then
		return
	end

	local data = slot._data
	if not data or not SilentDLC:should_mark_risky() then
		return
	end

	if not SilentDLC:slot_data_is_risky(data) then
		return
	end

	slot._silent_dlc_risky = true

	-- Tint main bitmap (may load later — reapplied in texture hook)
	if alive(slot._bitmap) then
		slot._bitmap:set_color(RISK_COLOR)
	end

	if alive(slot._akimbo_bitmap) then
		slot._akimbo_bitmap:set_color(RISK_COLOR)
	end

	-- Persistent corner badge (does not rely on text_name which BM slots often lack)
	if not alive(slot._silent_dlc_badge) then
		local badge = slot._panel:panel({
			name = "silent_dlc_cheater_badge",
			layer = 50,
			w = slot._panel:w(),
			h = 18
		})
		badge:set_top(2)
		badge:set_left(2)

		badge:rect({
			name = "bg",
			color = BADGE_BG,
			halign = "grow",
			valign = "grow"
		})

		local label = badge:text({
			name = "label",
			text = BADGE_TEXT,
			font = tweak_data.menu.pd2_small_font,
			font_size = 14,
			color = Color.white,
			align = "center",
			vertical = "center",
			layer = 1
		})

		local _, _, tw, th = label:text_rect()
		badge:set_size(math.max(tw + 8, 52), math.max(th + 2, 16))
		label:set_size(badge:w(), badge:h())

		slot._silent_dlc_badge = badge
	end

	if alive(slot._silent_dlc_badge) then
		slot._silent_dlc_badge:set_visible(true)
	end
end

local function clear_slot_mark(slot)
	if not slot then
		return
	end

	slot._silent_dlc_risky = nil

	if alive(slot._silent_dlc_badge) then
		slot._silent_dlc_badge:set_visible(false)
	end
end

-- Slot create
Hooks:PostHook(BlackMarketGuiSlotItem, "init", "SilentDLC_SlotMarkInit", function(self, main_panel, data, x, y, w, h)
	apply_slot_mark(self)
end)

-- Bitmap often loads after init — re-tint
if BlackMarketGuiSlotItem.texture_loaded_clbk then
	Hooks:PostHook(BlackMarketGuiSlotItem, "texture_loaded_clbk", "SilentDLC_SlotMarkTexture", function(self, ...)
		if self._silent_dlc_risky then
			if alive(self._bitmap) then
				self._bitmap:set_color(RISK_COLOR)
			end
			if alive(self._akimbo_bitmap) then
				self._akimbo_bitmap:set_color(RISK_COLOR)
			end
		else
			apply_slot_mark(self)
		end
	end)
end

if BlackMarketGuiSlotItem.refresh then
	Hooks:PostHook(BlackMarketGuiSlotItem, "refresh", "SilentDLC_SlotMarkRefresh", function(self)
		if self._silent_dlc_risky and alive(self._bitmap) then
			self._bitmap:set_color(RISK_COLOR)
		end
	end)
end

-- Mask-specific slot class
if BlackMarketGuiMaskSlotItem then
	Hooks:PostHook(BlackMarketGuiMaskSlotItem, "init", "SilentDLC_MaskSlotMark", function(self, ...)
		apply_slot_mark(self)
	end)
end

-- Info panel when selecting a risky item
local function append_info(self, text)
	if not self._info_texts then
		return
	end

	-- Prefer last info text block or first available
	for i = 5, 1, -1 do
		local t = self._info_texts[i]
		if alive(t) then
			local current = t:text() or ""
			if not string.find(current, "CHEATER", 1, true) then
				if current ~= "" then
					t:set_text(current .. "\n" .. text)
				else
					t:set_text(text)
				end
				t:set_color(RISK_COLOR)
			end
			return
		end
	end
end

if BlackMarketGui and BlackMarketGui.update_info_text then
	Hooks:PostHook(BlackMarketGui, "update_info_text", "SilentDLC_InfoMark", function(self)
		if not SilentDLC:should_mark_risky() then
			return
		end

		local data = self._slot_data
		if not data or not SilentDLC:slot_data_is_risky(data) then
			return
		end

		local msg = "⚠ CHEATER TAG if equipped online (unowned DLC)"
		if SilentDLC:is_safe_mode() then
			msg = msg .. " | Safe mode blocks this"
		elseif SilentDLC:is_normal_mode() then
			msg = msg .. " | Normal mode asks to confirm"
		end

		append_info(self, msg)
	end)
end

if BlackMarketGui and BlackMarketGui.select_slot then
	Hooks:PostHook(BlackMarketGui, "select_slot", "SilentDLC_SelectMark", function(self, ...)
		-- ensure marks stay after grid rebuilds
		if not self._tabs then
			return
		end

		for _, tab in pairs(self._tabs) do
			if tab and tab._slots then
				for _, slot in ipairs(tab._slots) do
					if slot and slot._data then
						if SilentDLC:should_mark_risky() and SilentDLC:slot_data_is_risky(slot._data) then
							apply_slot_mark(slot)
						end
					end
				end
			end
		end
	end)
end
