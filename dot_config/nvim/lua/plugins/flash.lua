return {
	"folke/flash.nvim",
	dependencies = {
		{
			"AstroNvim/astrocore",
			opts = function(_, opts)
				for _, mode in ipairs({ "n", "x", "o" }) do
					opts.mappings[mode]["s"] = false
					opts.mappings[mode]["f"] = {
						function() require("flash").jump() end,
						desc = "Flash",
					}
				end
			end,
		},
	},
	opts = {
		modes = {
			char = {
				keys = { "F", "t", "T", ";", "," }, -- Reserve f for Flash jump
			},
		},
		label = {
			uppercase = false,
		},
	},
}
