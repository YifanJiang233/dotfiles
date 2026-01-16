return {
  "lervag/vimtex",
  init = function()
    -- put vim.g.vimtex_* settings here
    vim.g.vimtex_view_method = "sioyek"
    vim.g.vimtex_imaps_enabled = 0
    vim.g.vimtex_quickfix_ignore_filters = {
      "Overfull",
      "Missing",
    }
    vim.g.vimtex_delim_toggle_mod_list = {
      { "\\bigl", "\\bigr" },
      { "\\Bigl", "\\Bigr" },
      { "\\biggl", "\\biggr" },
      { "\\Biggl", "\\Biggr" },
    }
  end,
  config = function()
    -- Keymaps and other settings that should be set AFTER the plugin loads
    -- Use `ai` and `ii` for the item text object
    vim.keymap.set({ "o", "x" }, "ai", "<Plug>(vimtex-am)")
    vim.keymap.set({ "o", "x" }, "ii", "<Plug>(vimtex-im)")

    -- Use `am` and `im` for the inline math text object
    vim.keymap.set({ "o", "x" }, "am", "<Plug>(vimtex-a$)")
    vim.keymap.set({ "o", "x" }, "im", "<Plug>(vimtex-i$)")

    vim.keymap.set("n", "dsm", "<Plug>(vimtex-env-delete-math)", { desc = "Delete surrounding math env" })
    vim.keymap.set("n", "csm", "<Plug>(vimtex-env-change-math)", { desc = "Change surrounding math env" })
    vim.keymap.set("n", "tsm", "<Plug>(vimtex-env-toggle-math)", { desc = "Toggle surrounding math env" })
    vim.keymap.set("n", "tsd", "<Plug>(vimtex-delim-toggle-modifier)", { desc = "Toggle surrounding delimiters" })
  end,
}
