local mod = get_mod("machine_spirit_upgrade")

local CHARGE_COUNTER_TYPES = {
	cooldown_charges = true,
	kill_charges = true,
	block_charges = true,
}

local DEFAULTS = {
	numbers_enabled = false,
	number_format = "uses_max",
	font_size = 32,
	opacity = 255,
	color_mode = "thresholds",
	color_r = 255,
	color_g = 255,
	color_b = 255,
	low_max = 0,
	low_r = 224,
	low_g = 64,
	low_b = 64,
	mid_max = 1,
	mid_r = 255,
	mid_g = 220,
	mid_b = 80,
	numbers_offset_x = 0,
	numbers_offset_y = 0,

	bar_enabled = false,
	bar_mode = "windup",
	bar_shape = "horizontal",
	bar_length = 200,
	bar_thickness = 8,
	bar_offset_x = 0,
	bar_offset_y = 248,
	bar_hide_at_max = true,
	bar_opacity = 255,
	track_r = 20,
	track_g = 20,
	track_b = 20,
	track_opacity = 140,
	regen_r = 255,
	regen_g = 255,
	regen_b = 255,
	retention_r = 224,
	retention_g = 64,
	retention_b = 64,

	underline_enabled = false,
	underline_position = "below",
	hint_countdown = false,
	countdown_font_size = 20,
	countdown_opacity = 255,
	countdown_offset_x = 0,
	countdown_offset_y = 40,

	stock_gauge = "hidden",
	stock_rotation = 90,
	stock_offset_x = 0,
	stock_offset_y = 0,
	stock_mirror = "none",
	stock_recolor = false,
	stock_filled_r = 216,
	stock_filled_g = 229,
	stock_filled_b = 207,
	stock_unfilled_r = 169,
	stock_unfilled_g = 191,
	stock_unfilled_b = 153,
	show_when_stowed = true,
	scope = "all_charges",
}

local NUMBERS = {
	"font_size", "opacity",
	"color_r", "color_g", "color_b",
	"low_max", "low_r", "low_g", "low_b",
	"mid_max", "mid_r", "mid_g", "mid_b",
	"numbers_offset_x", "numbers_offset_y",
	"countdown_font_size", "countdown_opacity", "countdown_offset_x", "countdown_offset_y",
	"bar_length", "bar_thickness", "bar_offset_x", "bar_offset_y", "bar_opacity",
	"track_r", "track_g", "track_b", "track_opacity",
	"regen_r", "regen_g", "regen_b",
	"retention_r", "retention_g", "retention_b",
	"stock_rotation", "stock_offset_x", "stock_offset_y",
	"stock_filled_r", "stock_filled_g", "stock_filled_b",
	"stock_unfilled_r", "stock_unfilled_g", "stock_unfilled_b",
}

local BOOLEANS = {
	"numbers_enabled", "underline_enabled", "hint_countdown",
	"bar_enabled", "bar_hide_at_max", "show_when_stowed",
	"stock_recolor",
}

local STRINGS = {
	"number_format", "color_mode", "underline_position",
	"bar_mode", "bar_shape", "scope", "stock_gauge", "stock_mirror",
}

mod.cfg = { version = 0 }

local cfg = mod.cfg

local function refresh_cfg()
	for _, id in ipairs(NUMBERS) do
		cfg[id] = mod:get(id) or DEFAULTS[id]
	end

	for _, id in ipairs(STRINGS) do
		cfg[id] = mod:get(id) or DEFAULTS[id]
	end

	for _, id in ipairs(BOOLEANS) do
		local value = mod:get(id)

		if value == nil then
			cfg[id] = DEFAULTS[id]
		else
			cfg[id] = value
		end
	end

	cfg.version = cfg.version + 1
end

refresh_cfg()

function mod.handles_counter_type(counter_type)
	if not counter_type or not CHARGE_COUNTER_TYPES[counter_type] then
		return false
	end

	if cfg.scope == "cooldown_only" then
		return counter_type == "cooldown_charges"
	end

	return true
end

local HUB_GAME_MODES = {
	hub = true,
	prologue_hub = true,
}

function mod.in_gameplay()
	local game_mode = Managers.state.game_mode
	local game_mode_name = game_mode and game_mode:game_mode_name()

	return game_mode_name ~= nil and not HUB_GAME_MODES[game_mode_name]
end

local SLOT_PRIMARY = "slot_primary"
local SLOT_SECONDARY = "slot_secondary"

local function charge_weapon_template(player_extensions, slot_name)
	local visual_loadout_extension = player_extensions.visual_loadout
	local weapon_template = visual_loadout_extension and visual_loadout_extension:weapon_template_from_slot(slot_name)
	local weapon_counter = weapon_template and weapon_template.weapon_counter

	if not weapon_counter or not mod.handles_counter_type(weapon_counter.weapon_counter_type) then
		return nil
	end

	local weapon_special_tweak_data = weapon_template.weapon_special_tweak_data

	if not weapon_special_tweak_data or not weapon_special_tweak_data.max_charges then
		return nil
	end

	return weapon_template, weapon_counter.weapon_counter_type
end

function mod.charge_slot(player_extensions)
	if not mod.in_gameplay() then
		return nil
	end

	local inventory_component = player_extensions.unit_data:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot

	if wielded_slot == SLOT_PRIMARY or wielded_slot == SLOT_SECONDARY then
		local weapon_template, counter_type = charge_weapon_template(player_extensions, wielded_slot)

		if weapon_template then
			return wielded_slot, weapon_template, counter_type
		end
	end

	if not cfg.show_when_stowed then
		return nil
	end

	if wielded_slot ~= SLOT_PRIMARY then
		local weapon_template, counter_type = charge_weapon_template(player_extensions, SLOT_PRIMARY)

		if weapon_template then
			return SLOT_PRIMARY, weapon_template, counter_type
		end
	end

	if wielded_slot ~= SLOT_SECONDARY then
		local weapon_template, counter_type = charge_weapon_template(player_extensions, SLOT_SECONDARY)

		if weapon_template then
			return SLOT_SECONDARY, weapon_template, counter_type
		end
	end
end

function mod.special_use_cost(tweak_data)
	return tweak_data.num_charges_to_consume_on_sweep
		or tweak_data.num_charges_to_consume_on_activation
		or 1
end

function mod.use_progress(phase, progress, num, cost)
	if phase == "full" then
		return 1
	end

	if not cost or cost <= 1 or not num then
		return progress
	end

	return (num % cost + progress) / cost
end

function mod.charge_color(num)
	if cfg.color_mode == "thresholds" then
		if num <= cfg.low_max then
			return cfg.low_r, cfg.low_g, cfg.low_b
		end

		if num <= cfg.mid_max then
			return cfg.mid_r, cfg.mid_g, cfg.mid_b
		end
	end

	return cfg.color_r, cfg.color_g, cfg.color_b
end

function mod.gameplay_time()
	local time_manager = Managers.time

	if not time_manager then
		return nil
	end

	local ok, t = pcall(time_manager.time, time_manager, "gameplay")

	return ok and t or nil
end

local recharge = {
	slot_name = nil,
	template = nil,
	prev_num = nil,
	activation_t = nil,
	tick_start = nil,
	tick_end = nil,
}

function mod.recharge_state(player_extensions, t)
	local slot_name, weapon_template, counter_type = mod.charge_slot(player_extensions)

	if not slot_name or counter_type ~= "cooldown_charges" then
		return nil
	end

	if slot_name ~= recharge.slot_name or weapon_template ~= recharge.template then
		recharge.slot_name = slot_name
		recharge.template = weapon_template
		recharge.prev_num = nil
		recharge.activation_t = nil
		recharge.tick_start = nil
		recharge.tick_end = nil
	end

	local tweak_data = weapon_template.weapon_special_tweak_data
	local slot_component = player_extensions.unit_data:read_component(slot_name)
	local num = slot_component.num_special_charges or 0
	local max = tweak_data.max_charges
	local cost = mod.special_use_cost(tweak_data)
	local is_active = slot_component.special_active == true

	local interval = tweak_data.passive_charge_add_interval

	if interval and interval > 0 then
		if max <= num then
			return "full", 1, num, max, 0, false, cost
		end

		if is_active then
			return nil
		end

		local next_t = slot_component.special_charge_remove_at_t or 0
		local remaining = next_t > t and next_t - t or 0
		local progress = remaining > 0 and math.clamp(1 - remaining / interval, 0, 1) or 0

		return "recharge", progress, num, max, remaining, false, cost
	end

	local cooldown = tweak_data.cooldown

	if not cooldown or cooldown <= 0 then
		return nil
	end

	local prev_num = recharge.prev_num

	recharge.prev_num = num

	if max <= num then
		recharge.tick_start = nil
		recharge.tick_end = nil

		return "full", 1, num, max, 0, false, cost
	end

	local active_duration = tweak_data.active_duration
	local start_t = slot_component.special_active_start_t
	local activated = active_duration and start_t and start_t ~= recharge.activation_t

	if activated then
		recharge.activation_t = start_t
	end

	if activated and t <= start_t + cooldown + active_duration then
		recharge.tick_start = start_t
		recharge.tick_end = start_t + cooldown + active_duration
	elseif prev_num and num > prev_num then
		recharge.tick_start = t
		recharge.tick_end = t + cooldown
	elseif not recharge.tick_end then
		recharge.tick_start = t
		recharge.tick_end = t + cooldown
	end

	local span = recharge.tick_end - recharge.tick_start
	local progress = span > 0 and math.clamp((t - recharge.tick_start) / span, 0, 1) or 0
	local remaining = math.max(recharge.tick_end - t, 0)

	return "recharge", progress, num, max, remaining, span > cooldown, cost
end

mod:register_hud_element({
	class_name = "HudElementMPSMachineSpiritUpgradeNumbers",
	filename = "machine_spirit_upgrade/scripts/mods/machine_spirit_upgrade/hud_element_charge_numbers",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})

mod:register_hud_element({
	class_name = "HudElementMPSMachineSpiritUpgradeBar",
	filename = "machine_spirit_upgrade/scripts/mods/machine_spirit_upgrade/hud_element_charge_bar",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})

mod:hook("HudElementWeaponCounter", "_weapon_counter_settings", function(func, self, slot_name)
	local settings = func(self, slot_name)

	if not settings or not mod:is_enabled() or cfg.stock_gauge ~= "hidden" then
		return settings
	end

	if mod.handles_counter_type(settings.weapon_counter_type) then
		return nil
	end

	return settings
end)

local function ensure_transformable(widget)
	if widget.msu_num_passes then
		return
	end

	local passes = widget.passes
	local style = widget.style

	if not passes or not style then
		return
	end

	local num_passes = #passes

	for ii = 1, num_passes do
		local pass = passes[ii]
		local pass_style = pass.style_id and style[pass.style_id]

		if pass.pass_type == "texture" and pass_style then
			pass.pass_type = "rotated_texture"
			pass_style.angle = pass_style.angle or 0
			pass_style.pivot = pass_style.pivot or {}
			pass_style.uvs = pass_style.uvs or { { 0, 0 }, { 1, 1 } }

			local offset = pass_style.offset

			if offset then
				pass_style.msu_base_x = offset[1]
				pass_style.msu_base_y = offset[2]
			end
		end
	end

	widget.msu_num_passes = num_passes
end

local function set_uvs(uvs, mirror_h, mirror_v)
	if not uvs or not uvs[1] or not uvs[2] then
		return
	end

	uvs[1][1] = mirror_h and 1 or 0
	uvs[2][1] = mirror_h and 0 or 1
	uvs[1][2] = mirror_v and 1 or 0
	uvs[2][2] = mirror_v and 0 or 1
end

local function apply_transform(widget, angle, ox, oy, mirror_h, mirror_v)
	local passes = widget.passes
	local style = widget.style

	for ii = 1, widget.msu_num_passes do
		local pass = passes[ii]
		local pass_style = pass.style_id and style[pass.style_id]

		if pass_style and pass.pass_type == "rotated_texture" then
			pass_style.angle = angle

			set_uvs(pass_style.uvs, mirror_h, mirror_v)

			local offset = pass_style.offset

			if offset then
				offset[1] = (pass_style.msu_base_x or 0) + ox
				offset[2] = (pass_style.msu_base_y or 0) + oy
			end
		end
	end
end

local STOCK_BAR_STYLE_IDS = {}

for ii = 1, 8 do
	STOCK_BAR_STYLE_IDS[ii] = string.format("charge_bar_%d", ii)
end

local PULSE_FILL_PEAK = 5
local PULSE_OUTLINE_PEAK = 2

local function recolor_widget(widget)
	local style = widget.style
	local content = widget.content

	if not style or not content then
		return
	end

	local pulses = content.pulse
	local delays = content.delay_timer

	for ii = 1, #STOCK_BAR_STYLE_IDS do
		local segment_style = style[STOCK_BAR_STYLE_IDS[ii]]
		local material_values = segment_style and segment_style.material_values

		if material_values then
			local filled = (material_values.amount or 0) >= 1
			local r = filled and cfg.stock_filled_r or cfg.stock_unfilled_r
			local g = filled and cfg.stock_filled_g or cfg.stock_unfilled_g
			local b = filled and cfg.stock_filled_b or cfg.stock_unfilled_b
			local delay = delays and delays[ii] or 0
			local pulse = delay > 0 and 1 or (pulses and pulses[ii] or 0)
			local fillcolor = material_values.fillcolor
			local outline_color = material_values.outline_color

			if fillcolor then
				local intensity = 1 + pulse * PULSE_FILL_PEAK

				fillcolor[1] = math.min(r / 255 * intensity, 2)
				fillcolor[2] = math.min(g / 255 * intensity, 2)
				fillcolor[3] = math.min(b / 255 * intensity, 2)
				fillcolor[4] = 1
			end

			if outline_color then
				local intensity = 1 + pulse * PULSE_OUTLINE_PEAK

				outline_color[1] = math.min(r * intensity, 255) / 255
				outline_color[2] = math.min(g * intensity, 255) / 255
				outline_color[3] = math.min(b * intensity, 255) / 255
				outline_color[4] = 1
			end
		end
	end
end

local transformed_widgets = setmetatable({}, { __mode = "k" })

local function restore_widget(widget)
	apply_transform(widget, 0, 0, 0, false, false)

	transformed_widgets[widget] = nil
	widget.msu_moved = false
end

mod:hook_safe("HudElementWeaponCounter", "_update_slot", function(self, dt, t, slot_name)
	local slot_widgets = self._slot_widgets
	local widget = slot_widgets and slot_widgets[slot_name]

	if not widget then
		return
	end

	local counter_type = self._slot_weapon_counter_type[slot_name]
	local handled = mod:is_enabled() and mod.handles_counter_type(counter_type)

	if handled and cfg.stock_gauge == "transformed" then
		ensure_transformable(widget)

		local mirror = cfg.stock_mirror
		local mirror_h = mirror == "horizontal" or mirror == "both"
		local mirror_v = mirror == "vertical" or mirror == "both"

		apply_transform(widget, math.rad(cfg.stock_rotation), cfg.stock_offset_x, cfg.stock_offset_y, mirror_h, mirror_v)

		transformed_widgets[widget] = true
		widget.msu_moved = true
	elseif widget.msu_moved then
		restore_widget(widget)
	end

	if handled and cfg.stock_recolor and cfg.stock_gauge ~= "hidden" then
		recolor_widget(widget)
	end
end)

function mod.on_disabled()
	for widget in pairs(transformed_widgets) do
		restore_widget(widget)
	end
end

mod.on_enabled = refresh_cfg
mod.on_all_mods_loaded = refresh_cfg

function mod.on_setting_changed()
	refresh_cfg()
end
