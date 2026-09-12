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
					["<leader>a"] = { desc = "Open Org Agenda" },
					["<leader>z"] = { desc = "Org Capture" },
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
