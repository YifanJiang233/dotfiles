-- Customize Treesitter

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      ensure_installed = {
        "lua",
        "vim",
        -- add more arguments for adding more treesitter parsers
      },
      auto_install = false,
      highlight = true, -- enable/disable treesitter based highlighting
      indent = true, -- enable/disable treesitter based indentation
      ignore_install = {
        "latex",
      },
    },
  },
}
