-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
	"AstroNvim/astrocommunity",
	{ import = "astrocommunity.colorscheme.catppuccin" },
	{ import = "astrocommunity.markdown-and-latex.vimtex" },
	{ import = "astrocommunity.motion.flash-nvim" },
	{ import = "astrocommunity.pack.lua" },
	{ import = "astrocommunity.pack.go" },
	{ import = "astrocommunity.pack.yaml" },
	{ import = "astrocommunity.pack.toml" },
	{ import = "astrocommunity.pack.python-ruff" },
	-- { import = "astrocommunity.pack.chezmoi" },
	{ import = "astrocommunity.pack.docker" },
	{ import = "astrocommunity.pack.bash" },
	-- { import = "astrocommunity.completion.avante-nvim" },
	-- import/override with your plugins folder
}
