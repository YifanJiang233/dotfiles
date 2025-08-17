return {
	"jghauser/papis.nvim",
	dependencies = {
		"kkharji/sqlite.lua",
		"MunifTanjim/nui.nvim",
		"pysan3/pathlib.nvim",
		"nvim-neotest/nvim-nio",
		-- if not already installed, you may also want:
		-- "hrsh7th/nvim-cmp",

		-- Choose one of the following two if not already installed:
		-- "nvim-telescope/telescope.nvim",
		"folke/snacks.nvim",
	},
	config = function()
		require("papis").setup({
			-- Your configuration goes here
			init_filetypes = { "tex", "bib", "markdown", "norg", "yaml" },
		})
	end,
}
