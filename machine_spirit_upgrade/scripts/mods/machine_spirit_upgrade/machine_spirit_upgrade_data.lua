local mod = get_mod("machine_spirit_upgrade")

local function numeric(setting_id, default_value, min, max)
	return {
		setting_id = setting_id,
		type = "numeric",
		default_value = default_value,
		range = { min, max },
		decimals_number = 0,
	}
end

local function channel(setting_id, default_value)
	return numeric(setting_id, default_value, 0, 255)
end

local function checkbox(setting_id, default_value, sub_widgets)
	return {
		setting_id = setting_id,
		type = "checkbox",
		default_value = default_value,
		sub_widgets = sub_widgets,
	}
end

return {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "numbers_group",
				type = "group",
				sub_widgets = {
					checkbox("numbers_enabled", false, {
						{
							setting_id = "number_format",
							type = "dropdown",
							default_value = "uses_max",
							options = {
								{ text = "number_format_uses_max", value = "uses_max" },
								{ text = "number_format_uses", value = "uses" },
								{ text = "number_format_current_max", value = "current_max" },
								{ text = "number_format_current", value = "current" },
							},
						},
						numeric("font_size", 32, 12, 96),
						numeric("opacity", 255, 0, 255),
						numeric("numbers_offset_x", 0, -1000, 1000),
						numeric("numbers_offset_y", 0, -1000, 1000),
						checkbox("underline_enabled", false, {
							{
								setting_id = "underline_position",
								type = "dropdown",
								default_value = "below",
								options = {
									{ text = "underline_position_below", value = "below" },
									{ text = "underline_position_above", value = "above" },
								},
							},
						}),
						checkbox("hint_countdown", false, {
							numeric("countdown_font_size", 20, 8, 64),
							numeric("countdown_opacity", 255, 0, 255),
							numeric("countdown_offset_x", 0, -1000, 1000),
							numeric("countdown_offset_y", 40, -1000, 1000),
						}),
						{
							setting_id = "color_mode",
							type = "dropdown",
							default_value = "thresholds",
							options = {
								{ text = "color_mode_single", value = "single", show_widgets = { 1, 2, 3 } },
								{
									text = "color_mode_thresholds",
									value = "thresholds",
									show_widgets = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
								},
							},
							sub_widgets = {
								channel("color_r", 255),
								channel("color_g", 255),
								channel("color_b", 255),
								numeric("low_max", 0, 0, 40),
								channel("low_r", 224),
								channel("low_g", 64),
								channel("low_b", 64),
								numeric("mid_max", 1, 0, 40),
								channel("mid_r", 255),
								channel("mid_g", 220),
								channel("mid_b", 80),
							},
						},
					}),
				},
			},
			{
				setting_id = "bar_group",
				type = "group",
				sub_widgets = {
					checkbox("bar_enabled", false, {
						{
							setting_id = "bar_mode",
							type = "dropdown",
							default_value = "windup",
							options = {
								{ text = "bar_mode_windup", value = "windup" },
								{ text = "bar_mode_recharge", value = "recharge" },
							},
						},
						{
							setting_id = "bar_shape",
							type = "dropdown",
							default_value = "horizontal",
							options = {
								{ text = "bar_shape_horizontal", value = "horizontal" },
								{ text = "bar_shape_vertical", value = "vertical" },
								{ text = "bar_shape_segments", value = "segments" },
							},
						},
						numeric("bar_length", 200, 20, 600),
						numeric("bar_thickness", 8, 1, 60),
						numeric("bar_offset_x", 0, -1000, 1000),
						numeric("bar_offset_y", 248, -1000, 1000),
						numeric("bar_opacity", 255, 0, 255),
						checkbox("bar_hide_at_max", true),
						channel("regen_r", 255),
						channel("regen_g", 255),
						channel("regen_b", 255),
						channel("retention_r", 224),
						channel("retention_g", 64),
						channel("retention_b", 64),
						channel("track_r", 20),
						channel("track_g", 20),
						channel("track_b", 20),
						numeric("track_opacity", 140, 0, 255),
					}),
				},
			},
			{
				setting_id = "shared_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "stock_gauge",
						type = "dropdown",
						default_value = "hidden",
						options = {
							{ text = "stock_gauge_hidden", value = "hidden" },
							{ text = "stock_gauge_original", value = "original" },
							{ text = "stock_gauge_transformed", value = "transformed", show_widgets = { 1, 2, 3, 4 } },
						},
						sub_widgets = {
							numeric("stock_rotation", 90, -180, 180),
							numeric("stock_offset_x", 0, -1000, 1000),
							numeric("stock_offset_y", 0, -1000, 1000),
							{
								setting_id = "stock_mirror",
								type = "dropdown",
								default_value = "none",
								options = {
									{ text = "stock_mirror_none", value = "none" },
									{ text = "stock_mirror_horizontal", value = "horizontal" },
									{ text = "stock_mirror_vertical", value = "vertical" },
									{ text = "stock_mirror_both", value = "both" },
								},
							},
						},
					},
					checkbox("stock_recolor", false, {
						channel("stock_filled_r", 216),
						channel("stock_filled_g", 229),
						channel("stock_filled_b", 207),
						channel("stock_unfilled_r", 169),
						channel("stock_unfilled_g", 191),
						channel("stock_unfilled_b", 153),
					}),
					checkbox("show_when_stowed", true),
					{
						setting_id = "scope",
						type = "dropdown",
						default_value = "all_charges",
						options = {
							{ text = "scope_all_charges", value = "all_charges" },
							{ text = "scope_cooldown_only", value = "cooldown_only" },
						},
					},
				},
			},
		},
	},
}
