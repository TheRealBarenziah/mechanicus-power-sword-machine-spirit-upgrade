local mod = get_mod("machine_spirit_upgrade")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local cfg = mod.cfg

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		numbers_area = {
			parent = "screen",
			size = { 220, 60 },
			vertical_alignment = "center",
			horizontal_alignment = "center",
			position = { 0, 120, 100 },
		},
	},
	widget_definitions = {
		charge_text = UIWidget.create_definition({
			{
				pass_type = "text",
				value = "",
				value_id = "charges",
				style_id = "charges",
				style = {
					font_type = "machine_medium",
					font_size = 32,
					drop_shadow = true,
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = { 255, 255, 255, 255 },
					offset = { 0, 0, 100 },
				},
			},
		}, "numbers_area"),
		recharge_hint = UIWidget.create_definition({
			{
				pass_type = "rect",
				style_id = "track",
				style = {
					size = { 0, 0 },
					vertical_alignment = "center",
					horizontal_alignment = "center",
					color = { 0, 255, 255, 255 },
					offset = { 0, 0, 99 },
				},
			},
			{
				pass_type = "rect",
				style_id = "fill",
				style = {
					size = { 0, 0 },
					vertical_alignment = "center",
					horizontal_alignment = "center",
					color = { 0, 255, 255, 255 },
					offset = { 0, 0, 100 },
				},
			},
			{
				pass_type = "text",
				value = "",
				value_id = "countdown",
				style_id = "countdown",
				style = {
					font_type = "machine_medium",
					font_size = 20,
					drop_shadow = true,
					text_vertical_alignment = "center",
					text_horizontal_alignment = "center",
					text_color = { 255, 255, 255, 255 },
					offset = { 0, 0, 100 },
				},
			},
		}, "numbers_area"),
	},
}

HudElementMPSMachineSpiritUpgradeNumbers = class("HudElementMPSMachineSpiritUpgradeNumbers", "HudElementBase")

function HudElementMPSMachineSpiritUpgradeNumbers:init(parent, draw_layer, start_scale)
	HudElementMPSMachineSpiritUpgradeNumbers.super.init(self, parent, draw_layer, start_scale, definitions)

	self._num = nil
	self._max = nil
	self._cfg_version = nil
end

function HudElementMPSMachineSpiritUpgradeNumbers:_charges(player_extensions)
	if not mod:is_enabled() or not cfg.numbers_enabled or not player_extensions then
		return nil
	end

	local slot_name, weapon_template = mod.charge_slot(player_extensions)

	if not slot_name then
		return nil
	end

	local inventory_slot_component = player_extensions.unit_data:read_component(slot_name)
	local tweak_data = weapon_template.weapon_special_tweak_data
	local num = inventory_slot_component and inventory_slot_component.num_special_charges or 0
	local max = tweak_data.max_charges
	local format = cfg.number_format

	if format == "uses" or format == "uses_max" then
		local cost = mod.special_use_cost(tweak_data)

		if cost > 1 then
			num = math.floor(num / cost)
			max = math.floor(max / cost)
		end
	end

	return num, max
end

function HudElementMPSMachineSpiritUpgradeNumbers:_repaint(num, max)
	local widget = self._widgets_by_name.charge_text
	local style = widget.style.charges

	if num then
		local format = cfg.number_format

		widget.content.charges = (format == "current" or format == "uses")
			and tostring(num)
			or string.format("%d/%d", num, max)

		local r, g, b = mod.charge_color(num)
		local text_color = style.text_color
		local offset = style.offset

		text_color[1] = cfg.opacity
		text_color[2] = r
		text_color[3] = g
		text_color[4] = b
		style.font_size = cfg.font_size
		offset[1] = cfg.numbers_offset_x
		offset[2] = cfg.numbers_offset_y
	else
		widget.content.charges = ""
	end

	widget.dirty = true
end

function HudElementMPSMachineSpiritUpgradeNumbers:_hide_hint()
	local widget = self._widgets_by_name.recharge_hint
	local style = widget.style

	style.track.color[1] = 0
	style.fill.color[1] = 0

	if widget.content.countdown ~= "" then
		widget.content.countdown = ""
		widget.dirty = true
	end
end

function HudElementMPSMachineSpiritUpgradeNumbers:_update_hint(player_extensions, num)
	local want_underline = cfg.underline_enabled
	local want_countdown = cfg.hint_countdown

	if not num or (not want_underline and not want_countdown) then
		self:_hide_hint()

		return
	end

	local t = mod.gameplay_time()
	local phase, progress, charges, _, remaining, in_recovery, cost

	if t then
		phase, progress, charges, _, remaining, in_recovery, cost = mod.recharge_state(player_extensions, t)
	end

	if phase ~= "recharge" then
		self:_hide_hint()

		return
	end

	local widget = self._widgets_by_name.recharge_hint
	local style = widget.style
	local font_size = cfg.font_size
	local ox = cfg.numbers_offset_x
	local oy = cfg.numbers_offset_y
	local r, g, b = mod.charge_color(num)

	if want_underline then
		local length = font_size * 1.6
		local thickness = math.max(2, math.floor(font_size / 12))
		local line_y = cfg.underline_position == "above"
			and oy - font_size * 0.65
			or oy + font_size * 0.65
		local track = style.track
		local track_color = track.color
		local fill = style.fill
		local fill_color = fill.color
		local fill_len = length * mod.use_progress(phase, progress, charges, cost)

		track_color[1] = cfg.track_opacity
		track_color[2] = cfg.track_r
		track_color[3] = cfg.track_g
		track_color[4] = cfg.track_b
		track.size[1] = length
		track.size[2] = thickness
		track.offset[1] = ox
		track.offset[2] = line_y

		fill_color[1] = fill_len > 0 and cfg.opacity or 0
		fill_color[2] = r
		fill_color[3] = g
		fill_color[4] = b
		fill.size[1] = fill_len
		fill.size[2] = thickness
		fill.offset[1] = ox - (length - fill_len) * 0.5
		fill.offset[2] = line_y
	else
		style.track.color[1] = 0
		style.fill.color[1] = 0
	end

	local text = ""

	if want_countdown and in_recovery then
		text = string.format("%.1f", remaining)

		local countdown = style.countdown
		local text_color = countdown.text_color

		countdown.font_size = cfg.countdown_font_size
		text_color[1] = cfg.countdown_opacity
		text_color[2] = r
		text_color[3] = g
		text_color[4] = b
		countdown.offset[1] = ox + cfg.countdown_offset_x
		countdown.offset[2] = oy + cfg.countdown_offset_y
	end

	if widget.content.countdown ~= text then
		widget.content.countdown = text
		widget.dirty = true
	end
end

function HudElementMPSMachineSpiritUpgradeNumbers:update(dt, t, ui_renderer, render_settings, input_service)
	HudElementMPSMachineSpiritUpgradeNumbers.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local parent = self._parent
	local player_extensions = parent and parent:player_extensions()
	local num, max = self:_charges(player_extensions)
	local version = cfg.version

	if num ~= self._num or max ~= self._max or version ~= self._cfg_version then
		self._num = num
		self._max = max
		self._cfg_version = version

		self:_repaint(num, max)
	end

	self:_update_hint(player_extensions, num)
end

return HudElementMPSMachineSpiritUpgradeNumbers
