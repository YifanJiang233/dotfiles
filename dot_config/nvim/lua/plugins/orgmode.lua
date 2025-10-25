return {
	"nvim-orgmode/orgmode",
	dependencies = {
		"nvim-orgmode/org-bullets.nvim",
		"danilshvalov/org-modern.nvim",
	},
	event = "VeryLazy",
	config = function()
		require("org-bullets").setup()
		local Menu = require("org-modern.menu")
		require("orgmode").setup({
			org_agenda_files = "~/Org/**/*",
			org_default_notes_file = "~/Org/note.org",
			org_hide_emphasis_markers = true,
			org_highlight_latex_and_related = "entities",
			mappings = {
				global = {
					org_agenda = "<leader>a",
					org_capture = "<leader>z",
				},
			},
			ui = {
				menu = {
					handler = function(data)
						Menu:new({
							window = {
								margin = { 1, 0, 1, 0 },
								padding = { 0, 1, 0, 1 },
								title_pos = "center",
								border = "single",
								zindex = 1000,
							},
							icons = {
								separator = "➜",
							},
						}):open(data)
					end,
				},
			},
		})
	end,
}
