if not SilentDLC then
	dofile(ModPath .. "core.lua")
end

local RISK_COLOR = Color(1, 1, 0.15, 0.15)
local BADGE_BG = Color(0.9, 0.55, 0.05, 0.05)
local BADGE_TEXT = "CHEATER"

local function has_risk_tint(bitmap)
	local color = bitmap:color()
	return color.r == RISK_COLOR.r and color.g == RISK_COLOR.g and color.b == RISK_COLOR.b
end

local function tint_bitmap(slot, bitmap_key, state_key)
	local bitmap = slot[bitmap_key]
	if not alive(bitmap) then
		return
	end

	local state = slot[state_key]
	-- A texture callback or another mod may have replaced the bitmap/color.
	-- Save that current color, including alpha, before applying our tint.
	if not state or state.bitmap ~= bitmap or not has_risk_tint(bitmap) then
		slot[state_key] = { bitmap = bitmap, color = bitmap:color(), data = slot._data }
	end
	bitmap:set_color(RISK_COLOR)
end

local function restore_bitmap(slot, bitmap_key, state_key)
	local bitmap, state = slot[bitmap_key], slot[state_key]
	if state and state.bitmap == bitmap and alive(bitmap) and has_risk_tint(bitmap) then
		if state.data == slot._data then
			bitmap:set_color(state.color)
		else
			-- Reused slots must use the new item's stock tint, not the old one.
			local data = slot._data or {}
			bitmap:set_color((slot._post_load_color or data.bitmap_color or Color.white):with_alpha(slot._post_load_alpha or data.bitmap_alpha or 1))
		end
	end
	-- Unmarked bitmaps and colors changed by others are left intact.
	slot[state_key] = nil
end

local function clear_slot_mark(slot)
	if not slot then
		return
	end

	slot._silent_dlc_risky = nil

	restore_bitmap(slot, "_bitmap", "_silent_dlc_bitmap_state")
	restore_bitmap(slot, "_akimbo_bitmap", "_silent_dlc_akimbo_state")

	if alive(slot._silent_dlc_badge) then
		slot._silent_dlc_badge:set_visible(false)
	end
end

local function apply_slot_mark(slot)
	if not slot or not alive(slot._panel) then
		return
	end

	local data = slot._data
	if not data or not SilentDLC:should_mark_risky() then
		clear_slot_mark(slot)
		return
	end

	if not SilentDLC:slot_data_is_risky(data) then
		clear_slot_mark(slot)
		return
	end

	slot._silent_dlc_risky = true

	-- Tint main bitmap (may load later — reapplied in texture hook)
	tint_bitmap(slot, "_bitmap", "_silent_dlc_bitmap_state")
	tint_bitmap(slot, "_akimbo_bitmap", "_silent_dlc_akimbo_state")

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

-- Slot create
Hooks:PostHook(BlackMarketGuiSlotItem, "init", "SilentDLC_SlotMarkInit", function(self, main_panel, data, x, y, w, h)
	apply_slot_mark(self)
end)

-- Bitmap often loads after init — re-tint
if BlackMarketGuiSlotItem.texture_loaded_clbk then
	Hooks:PostHook(BlackMarketGuiSlotItem, "texture_loaded_clbk", "SilentDLC_SlotMarkTexture", function(self, ...)
		apply_slot_mark(self)
	end)
end

if BlackMarketGuiSlotItem.refresh then
	Hooks:PostHook(BlackMarketGuiSlotItem, "refresh", "SilentDLC_SlotMarkRefresh", function(self)
		apply_slot_mark(self)
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

		local msg = "⚠ May trigger CHEATER TAG if equipped online"
		local is_character = data.category == "characters" or data.category == "character"
		if is_character then
			msg = "⚠ May trigger CHEATER TAG if you host with this unowned DLC character"
		end
		if SilentDLC:is_safe_mode() then
			msg = msg .. (is_character and " | Safe mode blocks hosting with this" or " | Safe mode blocks online use; offline equip allowed")
		elseif SilentDLC:is_normal_mode() then
			msg = msg .. (is_character and " | Normal mode confirms hosting" or " | Normal mode confirms online use; offline equip allowed")
		end

		append_info(self, msg)
	end)
end

-- ---------------------------------------------------------------------------
-- Grid rescan (restored from 1.4.1 with clear semantics)
-- ----------------------------------------------------------------------------
-- Slot init / texture / refresh hooks miss marks when the menu grid is
-- rebuilt or when a slot's data is swapped in place. Re-evaluate every slot
-- of the active tab whenever the selection moves; apply_slot_mark also
-- clears stale marks on safe or reused slots.
-- ---------------------------------------------------------------------------
local function rescan_tab_slots(tab)
	if not tab or not tab._slots then
		return
	end

	for _, slot in ipairs(tab._slots) do
		if slot and slot._data then
			apply_slot_mark(slot)
		end
	end
end

-- Current game: slot selection lives on the tab item
if BlackMarketGuiTabItem and BlackMarketGuiTabItem.select_slot then
	Hooks:PostHook(BlackMarketGuiTabItem, "select_slot", "SilentDLC_TabSelectMark", function(self, ...)
		rescan_tab_slots(self)
	end)
end

-- Older game builds: selection lived on BlackMarketGui itself
if BlackMarketGui and BlackMarketGui.select_slot then
	Hooks:PostHook(BlackMarketGui, "select_slot", "SilentDLC_SelectMark", function(self, ...)
		if not self._tabs then
			return
		end

		for _, tab in pairs(self._tabs) do
			rescan_tab_slots(tab)
		end
	end)
end
