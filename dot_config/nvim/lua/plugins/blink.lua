return {
	"Saghen/blink.cmp",
	optional = true,
	dependencies = {
		-- add the legacy cmp source as a dependency for `blink.cmp`
		"micangl/cmp-vimtex",
		{ "L3MON4D3/LuaSnip", version = "v2.*" },
	},
	specs = {
		-- install the blink, nvim-cmp compatibility layer
		{ "Saghen/blink.compat", version = "*", lazy = true, opts = {} },
	},
	opts = {
		completion = {
			menu = {
				draw = {
					columns = {
						{ "kind_icon" },
						{ "label" },
						{ "kind" },
					},
				},
			},
			documentation = {
				auto_show = true,
			},
		},
		snippets = { preset = "luasnip" },
		sources = {
			-- enable the provider by default
			default = { "vimtex", "snippets", "orgmode" },
			-- configure the provider for your new source
			providers = {
				vimtex = {
					name = "vimtex",
					module = "blink.compat.source",
					score_offset = 100,
				},
				orgmode = {
					name = "orgmode",
					module = "orgmode.org.autocompletion.blink",
					fallbacks = { "buffer" },
				},
			},
		},
	},
}
