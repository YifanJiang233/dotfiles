return {
	{
		"AstroNvim/astrocore",
		---@type AstroCoreOpts

		opts = {
			mappings = {
				-- first key is the mode
				n = {
					-- second key is the lefthand side of the map
					-- mappings seen under group name "Buffer"
					-- tables with just a `desc` key will be registered with which-key if it's installed
					-- this is useful for naming menus
					["<localleader>p"] = { group = "Papis" },
					["<localleader>pp"] = { "<cmd>Papis search<cr>", desc = "Open Picker" },
					["<localleader>pf"] = { "<cmd>Papis at-cursor open-file<cr>", desc = "Open File Under Cursor" },
					["<localleader>pe"] = { "<cmd>Papis at-cursor edit<cr>", desc = "Edit Entry Under Cursor" },
					["<localleader>pn"] = { "<cmd>Papis at-cursor open-note<cr>", desc = "Open Note Under Cursor" },
					["<localleader>pi"] = {
						"<cmd>Papis at-cursor show-popup<cr>",
						desc = "Show Entry Info Under Cursor",
					},
					-- quick save
					-- ["<C-s>"] = { ":w!<cr>", desc = "Save File" },  -- change description but the same command
				},
				t = {
					-- setting a mapping to false will disable it
					-- ["<esc>"] = false,
				},
			},
		},
	},
}
