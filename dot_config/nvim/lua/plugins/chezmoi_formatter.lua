return {
  {
    -- Point lazy.nvim directly to your local development directory
    dir = "/home/yifan/Documents/Coding/chezmoi-formatter",
    name = "chezmoi-formatter",

    -- Ensure tree-sitter is loaded before this plugin
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },

    -- Setup the plugin when it loads
    config = function() require("chezmoi-formatter").setup() end,
  },
}
