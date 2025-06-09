return {
	"andre-kotake/nvim-chezmoi",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{ "nvim-telescope/telescope.nvim" },
	},
	opts = {
		-- Your custom config
		edit = { apply_on_save = "auto" },
	},
	config = function(_, opts)
		require("nvim-chezmoi").setup(opts)
	end,
}
