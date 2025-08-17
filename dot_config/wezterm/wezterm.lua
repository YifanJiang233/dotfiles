-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
config.window_decorations = "RESIZE"
config.font = wezterm.font_with_fallback({ "JetBrainsMono Nerd Font", "LXGW Bright Medium" })
config.hide_tab_bar_if_only_one_tab = true

config.window_background_opacity = 0.9

config.keys = {
	{
		key = "k",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ScrollByPage(-0.5),
	},
	{
		key = "j",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ScrollByPage(0.5),
	},
}

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Mocha"

config.font_rules = {
	{
		intensity = "Bold",
		italic = false,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono",    weight = "Bold", stretch = "Normal", style = "Normal" },
			{ family = "LXGW Bright Medium" },
		}),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono",    weight = "Bold", stretch = "Normal", style = "Italic" },
			{ family = "LXGW Bright Medium" },
		}),
	},
}

-- and finally, return the configuration to wezterm
return config
