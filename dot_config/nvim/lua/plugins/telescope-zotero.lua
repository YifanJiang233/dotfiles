return {
  "jmbuhr/telescope-zotero.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "kkharji/sqlite.lua",
  },
  config = function()
    require("zotero").setup({
      picker = { with_icons = false },
    })
    require("telescope").load_extension("zotero")
  end,
  keys = {
    { "<leader>fz", "<cmd>Telescope zotero<cr>", desc = "Find Zotero citation" },
  },
}
