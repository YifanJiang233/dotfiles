-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
config.window_decorations = "RESIZE"
config.font = wezterm.font("JetBrains Mono")
config.hide_tab_bar_if_only_one_tab = true

config.window_background_opacity = 0.9

-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Mocha"

-- and finally, return the configuration to wezterm
return config
