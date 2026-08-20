local mod = get_mod("machine_spirit_upgrade")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local MAX_CELLS = 40
local AUTO_MAX_CELLS = 12
local CELL_GAP = 2

local cfg = mod.cfg

local function rect_pass(style_id, z)
	return {
		pass_type = "rect",
		style_id = style_id,
		style = {
			size = { 0, 0 },
			vertical_alignment = "center",
			horizontal_alignment = "center",
			color = { 0, 255, 255, 255 },
			offset = { 0, 0, z },
		},
	}
end

local function bar_passes()
	local passes = {
		rect_pass("track", 100),
		rect_pass("fill", 101),
	}

	for ii = 1, MAX_CELLS do
		passes[#passes + 1] = rect_pass("cell_" .. ii, 101)
	end

	return passes
end

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		bar_area = {
			parent = "screen",
			size = { 480, 160 },
			vertical_alignment = "center",
			horizontal_alignment = "center",
			position = { 0, 0, 100 },
		},
	},
	widget_definitions = {
		charge_bar = UIWidget.create_definition(bar_passes(), "bar_area"),
	},
}

HudElementMPSMachineSpiritUpgradeBar = class("HudElementMPSMachineSpiritUpgradeBar", "HudElementBase")

function HudElementMPSMachineSpiritUpgradeBar:init(parent, draw_layer, start_scale)
	HudElementMPSMachineSpiritUpgradeBar.super.init(self, parent, draw_layer, start_scale, definitions)

	self._windup_bounds = { 0, 0, 0, 0 }
end

local function windup_windows(weapon_template, action_name, time_scale)
	local actions = weapon_template.actions
	local action = actions and actions[action_name]

	if not action or action.kind ~= "windup" or not action.activate_special_during_windup then
		return nil
	end

	local action_inputs = weapon_template.action_inputs
	local heavy_input = action_inputs and action_inputs.heavy_attack_special
	local sequence = heavy_input and heavy_input.input_sequence
	local first = sequence and sequence[1]
	local second = sequence and sequence[2]
	local heavy_commit = first and first.duration
	local release_window = second and second.auto_complete and second.time_window

	if not heavy_commit or not release_window then
		return nil
	end

	local total = heavy_commit + release_window
	local chain = action.allowed_chain_actions
	local heavy_chain = chain and chain.heavy_attack_special
	local chain_time = heavy_chain and heavy_chain.chain_time
	local heavy_ready

	if chain_time and time_scale and time_scale > 0 then
		heavy_ready = chain_time / time_scale
	end

	return total, heavy_commit, heavy_ready
end

function HudElementMPSMachineSpiritUpgradeBar:_windup_state(player_extensions, t)
	local unit_data = player_extensions.unit_data
	local inventory_component = unit_data:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot

	if wielded_slot ~= "slot_primary" and wielded_slot ~= "slot_secondary" then
		return nil
	end

	local visual_loadout_extension = player_extensions.visual_loadout
	local weapon_template = visual_loadout_extension
		and visual_loadout_extension:weapon_template_from_slot(wielded_slot)

	if not weapon_template then
		return nil
	end

	local weapon_action_component = unit_data:read_component("weapon_action")
	local action_name = weapon_action_component and weapon_action_component.current_action_name

	if not action_name or action_name == "none" then
		return nil
	end

	local total, heavy_commit, heavy_ready =
		windup_windows(weapon_template, action_name, weapon_action_component.time_scale)

	if not total or total <= 0 then
		return nil
	end

	local progress = math.clamp((t - weapon_action_component.start_t) / total, 0, 1)
	local mark_1 = math.clamp(heavy_commit / total, 0, 1)
	local mark_2 = heavy_ready and math.clamp(heavy_ready / total, 0, 1)

	if mark_2 and mark_2 <= mark_1 then
		mark_1 = mark_2
		mark_2 = nil
	end

	local final_start = mark_2 or mark_1

	return progress, mark_1, mark_2, final_start
end

function HudElementMPSMachineSpiritUpgradeBar:_hide()
	local style = self._widgets_by_name.charge_bar.style

	style.track.color[1] = 0
	style.fill.color[1] = 0

	for ii = 1, MAX_CELLS do
		style["cell_" .. ii].color[1] = 0
	end
end

local function set_rect(style, alpha, r, g, b, width, height, offset_x, offset_y)
	local color = style.color
	local size = style.size
	local offset = style.offset

	color[1] = alpha
	color[2] = r
	color[3] = g
	color[4] = b
	size[1] = width
	size[2] = height
	offset[1] = offset_x
	offset[2] = offset_y
end

local function hide_cells(style, from)
	for ii = from, MAX_CELLS do
		style["cell_" .. ii].color[1] = 0
	end
end

function HudElementMPSMachineSpiritUpgradeBar:_draw_track()
	local style = self._widgets_by_name.charge_bar.style
	local vertical = cfg.bar_shape == "vertical"
	local track_w = vertical and cfg.bar_thickness or cfg.bar_length
	local track_h = vertical and cfg.bar_length or cfg.bar_thickness

	set_rect(style.track, cfg.track_opacity, cfg.track_r, cfg.track_g, cfg.track_b,
		track_w, track_h, cfg.bar_offset_x, cfg.bar_offset_y)

	return style, vertical
end

function HudElementMPSMachineSpiritUpgradeBar:_draw_windup(progress, mark_1, mark_2, final_start)
	local style, vertical = self:_draw_track()
	local length = cfg.bar_length
	local thickness = cfg.bar_thickness
	local ox = cfg.bar_offset_x
	local oy = cfg.bar_offset_y
	local r, g, b

	if progress >= final_start then
		r, g, b = cfg.retention_r, cfg.retention_g, cfg.retention_b
	else
		r, g, b = cfg.regen_r, cfg.regen_g, cfg.regen_b
	end

	style.fill.color[1] = 0

	local bounds = self._windup_bounds
	local num_bounds

	bounds[1] = 0
	bounds[2] = mark_1

	if mark_2 then
		bounds[3] = mark_2
		bounds[4] = 1
		num_bounds = 4
	else
		bounds[3] = 1
		num_bounds = 3
	end

	local cell_index = 0
	local from = 0

	for ii = 2, num_bounds do
		local to = bounds[ii]

		if to > from then
			cell_index = cell_index + 1

			local gap = ii < num_bounds and CELL_GAP or 0
			local cell_style = style["cell_" .. cell_index]
			local filled = math.clamp((progress - from) / (to - from), 0, 1)
			local span = (to - from) * length - gap
			local fill_len = span > 0 and span * filled or 0
			local alpha = fill_len > 0 and cfg.bar_opacity or 0

			if vertical then
				local stage_bottom = oy + length * 0.5 - from * length

				set_rect(cell_style, alpha, r, g, b, thickness, fill_len,
					ox, stage_bottom - fill_len * 0.5)
			else
				local stage_left = ox - length * 0.5 + from * length

				set_rect(cell_style, alpha, r, g, b, fill_len, thickness,
					stage_left + fill_len * 0.5, oy)
			end

			from = to
		end
	end

	hide_cells(style, cell_index + 1)
end

function HudElementMPSMachineSpiritUpgradeBar:_draw_recharge(kind, phase, progress, num, max, cost, in_recovery)
	local style, vertical = self:_draw_track()
	local length = cfg.bar_length
	local thickness = cfg.bar_thickness
	local ox = cfg.bar_offset_x
	local oy = cfg.bar_offset_y
	local overheat = kind == "overheat"
	local r, g, b

	if overheat and in_recovery then
		r, g, b = cfg.retention_r, cfg.retention_g, cfg.retention_b
	else
		r, g, b = cfg.regen_r, cfg.regen_g, cfg.regen_b
	end

	local fill, cells, filled

	if overheat then
		-- the whole bar is the vented fraction; one cell per estimated swing
		fill = phase == "full" and 1 or progress
		cells = max
		filled = fill * max
	else
		cells = max
		filled = phase == "full" and max or num + progress

		if cost and cost > 1 then
			cells = math.floor(cells / cost)
			filled = filled / cost
		end

		-- with no refill timer there is no tick to show; the level is the bar
		if phase == "level" then
			fill = cells > 0 and filled / cells or 0
		else
			fill = mod.use_progress(phase, progress, num, cost)
		end
	end

	-- A cell spans a whole number of uses: the configured count, or on "Auto"
	-- the smallest that keeps at most AUTO_MAX_CELLS cells. Either way the
	-- count is clamped so cells fit the pass pool (an uneven tail shortens the
	-- last bucket only), so segments never silently fall back to a solid bar.
	local per_cell = cfg.bar_cell_uses

	if not per_cell or per_cell < 1 then
		per_cell = math.ceil(cells / AUTO_MAX_CELLS)
	end

	per_cell = math.max(per_cell, math.ceil(cells / MAX_CELLS))

	if per_cell > 1 then
		cells = math.ceil(cells / per_cell)
		filled = filled / per_cell
	end

	if cfg.bar_shape == "segments" and cells >= 1 and cells <= MAX_CELLS then
		style.fill.color[1] = 0

		local cell_w = math.max((length - CELL_GAP * (cells - 1)) / cells, 1)
		local left = ox - length * 0.5 + cell_w * 0.5

		for ii = 1, cells do
			local cell_style = style["cell_" .. ii]
			local fill_ratio = math.clamp(filled - (ii - 1), 0, 1)
			local alpha = fill_ratio > 0 and cfg.bar_opacity * fill_ratio or 0

			set_rect(cell_style, alpha, r, g, b, cell_w, thickness,
				left + (ii - 1) * (cell_w + CELL_GAP), oy)
		end

		hide_cells(style, cells + 1)

		return
	end

	hide_cells(style, 1)

	if vertical then
		local fill_h = length * fill

		set_rect(style.fill, cfg.bar_opacity, r, g, b, thickness, fill_h,
			ox, oy + (length - fill_h) * 0.5)
	else
		local fill_w = length * fill

		set_rect(style.fill, cfg.bar_opacity, r, g, b, fill_w, thickness,
			ox - (length - fill_w) * 0.5, oy)
	end
end

function HudElementMPSMachineSpiritUpgradeBar:update(dt, t, ui_renderer, render_settings, input_service)
	HudElementMPSMachineSpiritUpgradeBar.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local drawn = false

	if mod:is_enabled() and cfg.bar_enabled and mod.in_gameplay() then
		local parent = self._parent
		local player_extensions = parent and parent:player_extensions()
		local gameplay_t = player_extensions and mod.gameplay_time()

		if gameplay_t then
			if cfg.bar_mode == "windup" then
				local progress, mark_1, mark_2, final_start = self:_windup_state(player_extensions, gameplay_t)

				if progress then
					self:_draw_windup(progress, mark_1, mark_2, final_start)

					drawn = true
				end
			end

			-- recharge mode; wind-up mode falls back to this on overheat
			-- weapons, whose special has no wind-up to show
			if not drawn then
				local kind, phase, progress, num, max, _, in_recovery, cost = mod.display_state(player_extensions, gameplay_t)

				if (cfg.bar_mode == "recharge" or kind == "overheat")
					and phase
					and not (phase == "full" and cfg.bar_hide_at_max) then
					self:_draw_recharge(kind, phase, progress, num, max, cost, in_recovery)

					drawn = true
				end
			end
		end
	end

	if not drawn then
		self:_hide()
	end

	-- one flag skips all 42 passes in UIWidget.draw while nothing is shown
	self._widgets_by_name.charge_bar.visible = drawn
end

return HudElementMPSMachineSpiritUpgradeBar
