return {
	"L3MON4D3/LuaSnip",

	opts = {
		-- Your custom config
		enable_autosnippets = true,
		store_selection_keys = "<Tab>",
	},
	config = function(plugin, opts)
		-- include the default astronvim config that calls the setup call
		require("astronvim.plugins.configs.luasnip")(plugin, opts)
		-- load snippets paths
		require("luasnip.loaders.from_lua").lazy_load({
			paths = { vim.fn.stdpath("config") .. "/snippets" },
		})
		vim.keymap.set({ "i", "s" }, "<C-J>", function()
			if require("luasnip").choice_active() then
				require("luasnip").change_choice(1)
			end
		end, { silent = true })

		vim.keymap.set({ "i", "s" }, "<C-K>", function()
			if require("luasnip").choice_active() then
				require("luasnip").change_choice(-1)
			end
		end, { silent = true })
		vim.keymap.set({ "i" }, "jk", function()
			require("luasnip").expand()
		end, { silent = true })
		vim.keymap.set({ "i", "s" }, "jk", function()
			require("luasnip").jump(1)
		end, { silent = true })
		vim.keymap.set({ "i", "s" }, "kj", function()
			require("luasnip").jump(-1)
		end, { silent = true })
	end,
}
