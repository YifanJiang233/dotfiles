-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "go",
      -- add more arguments for adding more treesitter parsers
    },
    auto_install = false,
    ignore_install = {
      "latex",
    },
  },
}
