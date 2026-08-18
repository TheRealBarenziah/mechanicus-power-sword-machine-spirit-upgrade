local mod = get_mod("machine_spirit_upgrade")

local CHARGE_COUNTER_TYPES = {
	cooldown_charges = true,
	kill_charges = true,
	block_charges = true,
}

-- Some charge weapons track num_special_charges without declaring a stock
-- weapon_counter (Arbites maul & shield, dual shivs); recognize them by class.
local SPECIAL_CLASS_COUNTER_TYPES = {
	WeaponSpecialCooldownCharges = "cooldown_charges",
	WeaponSpecialHitCharges = "cooldown_charges",
	WeaponSpecialKillCountCharges = "kill_charges",
	WeaponSpecialBlockCharges = "block_charges",
}

local OVERHEAT_COUNTER_TYPE = "overheat_lockout"

local DEFAULTS = {
	numbers_enabled = false,
	number_format = "uses_max",
	font_size = 32,
	opacity = 255,
	color_mode = "thresholds",
	color_r = 255,
	color_g = 255,
	color_b = 255,
	band_scale = "absolute",
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
	"number_format", "color_mode", "band_scale", "underline_position",
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

-- "charges" for discrete-charge weapons, "overheat" for heat/lockout weapons
-- (power falchion, two-handed power sword), nil for anything the mod leaves alone.
function mod.display_kind(counter_type)
	if not counter_type then
		return nil
	end

	if counter_type == OVERHEAT_COUNTER_TYPE then
		return cfg.scope ~= "cooldown_only" and "overheat" or nil
	end

	if not CHARGE_COUNTER_TYPES[counter_type] then
		return nil
	end

	if cfg.scope == "cooldown_only" and counter_type ~= "cooldown_charges" then
		return nil
	end

	return "charges"
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

	if not weapon_template then
		return nil
	end

	local weapon_counter = weapon_template.weapon_counter
	local counter_type = weapon_counter and weapon_counter.weapon_counter_type
		or SPECIAL_CLASS_COUNTER_TYPES[weapon_template.weapon_special_class]
	local kind = mod.display_kind(counter_type)

	if kind == "overheat" then
		if not weapon_template.overheat_configuration then
			return nil
		end

		return weapon_template, counter_type, kind
	end

	if kind == "charges" then
		local weapon_special_tweak_data = weapon_template.weapon_special_tweak_data

		if not weapon_special_tweak_data or not weapon_special_tweak_data.max_charges then
			return nil
		end

		return weapon_template, counter_type, kind
	end

	return nil
end

function mod.charge_slot(player_extensions)
	if not mod.in_gameplay() then
		return nil
	end

	local inventory_component = player_extensions.unit_data:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot

	if wielded_slot == SLOT_PRIMARY or wielded_slot == SLOT_SECONDARY then
		local weapon_template, counter_type, kind = charge_weapon_template(player_extensions, wielded_slot)

		if weapon_template then
			return wielded_slot, weapon_template, counter_type, kind
		end
	end

	if not cfg.show_when_stowed then
		return nil
	end

	if wielded_slot ~= SLOT_PRIMARY then
		local weapon_template, counter_type, kind = charge_weapon_template(player_extensions, SLOT_PRIMARY)

		if weapon_template then
			return SLOT_PRIMARY, weapon_template, counter_type, kind
		end
	end

	if wielded_slot ~= SLOT_SECONDARY then
		local weapon_template, counter_type, kind = charge_weapon_template(player_extensions, SLOT_SECONDARY)

		if weapon_template then
			return SLOT_SECONDARY, weapon_template, counter_type, kind
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

function mod.charge_color(num, max)
	if cfg.color_mode == "thresholds" then
		local low = cfg.low_max
		local mid = cfg.mid_max

		if cfg.band_scale == "percent" and max and max > 0 then
			low = max * low * 0.01
			mid = max * mid * 0.01
		end

		if num <= low then
			return cfg.low_r, cfg.low_g, cfg.low_b
		end

		if num <= mid then
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

local function cooldown_recharge_state(player_extensions, slot_name, weapon_template, t)
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

local WeaponChargeTemplates

local function static_charge_template(template_name)
	if WeaponChargeTemplates == nil then
		local ok, templates = pcall(require, "scripts/settings/equipment/weapon_handling_templates/weapon_charge_templates")

		WeaponChargeTemplates = ok and templates or false
	end

	return WeaponChargeTemplates and WeaponChargeTemplates[template_name] or nil
end

-- The per-item charge template with the weapon's stat lerps applied; the static
-- settings table is the fallback when the weapon extension isn't available.
local function resolved_charge_template(player_extensions, slot_name, template_name)
	if not template_name then
		return nil
	end

	local weapon_extension = player_extensions.weapon
	local weapons = weapon_extension and weapon_extension._weapons
	local weapon = weapons and weapons[slot_name]
	local tweak_templates = weapon and weapon.weapon_tweak_templates
	local charge_templates = tweak_templates and tweak_templates.charge

	return charge_templates and charge_templates[template_name] or static_charge_template(template_name)
end

-- Resolved templates hold plain numbers; static ones still hold
-- { lerp_basic, lerp_perfect } stat-lerp tables.
local function lerp_value(value, fallback)
	if type(value) == "number" then
		return value
	end

	if type(value) == "table" then
		return value.lerp_basic or value.lerp_perfect or fallback
	end

	return fallback
end

local DEFAULT_SWING_HEAT = 0.05
local DEFAULT_VENT_DURATION = 15

local eta_bands = { {}, {}, {}, {} }

local function overheat_eta(heat, decay, dissipation, wait)
	local duration = lerp_value(decay.auto_vent_duration, DEFAULT_VENT_DURATION)
	local thresholds = decay.thresholds
	local bands = eta_bands

	if thresholds then
		bands[1][1] = thresholds.critical or 1
		bands[1][2] = decay.critical_threshold_decay_rate_modifier or 1
		bands[2][1] = thresholds.high or 1
		bands[2][2] = decay.high_threshold_decay_rate_modifier or 1
		bands[3][1] = thresholds.low or 1
		bands[3][2] = decay.low_threshold_decay_rate_modifier or 1
	else
		bands[1][1] = 1
		bands[2][1] = 1
		bands[3][1] = 1
	end

	bands[4][1] = 0
	bands[4][2] = 1

	local eta = 0
	local remaining = heat

	for ii = 1, 4 do
		local floor_heat = bands[ii][1]
		local rate_modifier = bands[ii][2]

		if remaining > floor_heat and rate_modifier and rate_modifier > 0 then
			eta = eta + (remaining - floor_heat) * duration / rate_modifier
			remaining = floor_heat
		end
	end

	if dissipation and dissipation > 0 and dissipation ~= 1 then
		eta = eta / dissipation
	end

	if wait and wait > 0 then
		eta = eta + wait
	end

	return eta
end

-- Same tuple shape as the cooldown state. progress is the cooled fraction,
-- num/max are estimated powered swings before lockout, remaining is seconds
-- until fully vented, in_recovery flags an active lockout.
function mod.overheat_state(player_extensions, slot_name, weapon_template, t)
	local slot_component = player_extensions.unit_data:read_component(slot_name)
	local heat = math.clamp(slot_component.overheat_current_percentage or 0, 0, 1)
	local overheat_state = slot_component.overheat_state
	local locked = overheat_state == "lockout" or overheat_state == "soft_lockout"
	local charge_template = resolved_charge_template(player_extensions, slot_name, weapon_template.special_charge_template)
	local overtime = charge_template and charge_template.overheat_overtime
	local per_swing = overtime and lerp_value(overtime.overheat_percent, DEFAULT_SWING_HEAT) or DEFAULT_SWING_HEAT

	if per_swing <= 0 then
		per_swing = DEFAULT_SWING_HEAT
	end

	local max_swings = math.max(math.floor(1 / per_swing + 0.001), 1)

	if heat <= 0 and not locked then
		return "full", 1, max_swings, max_swings, 0, false, 1
	end

	local headroom = 1 - heat
	local swings = locked and 0 or math.min(math.floor(headroom / per_swing + 0.001), max_swings)
	local decay = charge_template and charge_template.overheat_decay
	local remaining = 0

	if decay then
		local buff_extension = player_extensions.buff
		local stat_buffs = buff_extension and buff_extension:stat_buffs()
		local dissipation = stat_buffs and stat_buffs.overheat_dissipation_multiplier or 1
		local last_charge_t = slot_component.overheat_last_charge_at_t
		local wait = last_charge_t and last_charge_t + (decay.auto_vent_delay or 0) - t or 0

		remaining = overheat_eta(heat, decay, dissipation, wait)
	end

	return "recharge", headroom, swings, max_swings, remaining, locked, 1
end

-- One entry point for the HUD elements: kind plus the state tuple for weapons
-- with a timed refill (cooldown charges, overheat). Kill/block charge weapons
-- return their kind alone - their numbers come straight off the component.
function mod.display_state(player_extensions, t)
	local slot_name, weapon_template, counter_type, kind = mod.charge_slot(player_extensions)

	if not slot_name then
		return nil
	end

	if kind == "overheat" then
		return kind, mod.overheat_state(player_extensions, slot_name, weapon_template, t)
	end

	-- covers the passive-refill weapons too (Arc Maul, maul & shield); weapons
	-- with neither a cooldown nor a passive interval get no timed state
	return kind, cooldown_recharge_state(player_extensions, slot_name, weapon_template, t)
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

	if mod.display_kind(settings.weapon_counter_type) then
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

local transformed_widgets = setmetatable({}, { __mode = "k" })
local tinted_widgets = setmetatable({}, { __mode = "k" })

-- Overheat weapons draw a single material bar whose style colour starts as a
-- shared settings table - swap in an own table before tinting, never mutate it.
local function tint_overheat_widget(widget, overheat_style)
	local color = widget.msu_tint_color

	if not color then
		local original = overheat_style.color

		color = { original and original[1] or 255, 255, 255, 255 }
		widget.msu_original_color = original
		widget.msu_tint_color = color
		overheat_style.color = color
	end

	color[2] = cfg.stock_filled_r
	color[3] = cfg.stock_filled_g
	color[4] = cfg.stock_filled_b
end

local function untint_widget(widget)
	if not widget.msu_tint_color then
		return
	end

	local style = widget.style
	local overheat_style = style and style.charge_bar

	if overheat_style then
		overheat_style.color = widget.msu_original_color or overheat_style.color
	end

	widget.msu_tint_color = nil
	widget.msu_original_color = nil
	tinted_widgets[widget] = nil
end

local function recolor_widget(widget)
	local style = widget.style
	local content = widget.content

	if not style or not content then
		return
	end

	local overheat_style = style.charge_bar

	if overheat_style then
		tint_overheat_widget(widget, overheat_style)

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
	local handled = mod:is_enabled() and mod.display_kind(counter_type) ~= nil

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
		tinted_widgets[widget] = true
	elseif widget.msu_tint_color then
		untint_widget(widget)
	end
end)

function mod.on_disabled()
	for widget in pairs(transformed_widgets) do
		restore_widget(widget)
	end

	for widget in pairs(tinted_widgets) do
		untint_widget(widget)
	end
end

mod.on_enabled = refresh_cfg
mod.on_all_mods_loaded = refresh_cfg

function mod.on_setting_changed()
	refresh_cfg()
end
