return {
	"lervag/vimtex",
	init = function()
		-- put vim.g.vimtex_* settings here
		vim.g.vimtex_view_method = "sioyek"
		vim.g.vimtex_quickfix_ignore_filters = {
			"Overfull",
			"Missing",
		}
	end,
}
