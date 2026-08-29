-- Customize None-ls sources

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  dependencies = {
    "nvimtools/none-ls-extras.nvim",
  },
  opts = function(_, opts)
    local null_ls = require "null-ls"

    local bibtex_tidy = {
      name = "bibtex-tidy",
      method = null_ls.methods.FORMATTING,
      filetypes = { "bib" },
      generator = null_ls.formatter {
        command = "bibtex-tidy",
        to_stdin = true,
      },
    }

    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      require("none-ls.formatting.latexindent").with {
        extra_args = { "-g", "/dev/null" },
      },

      bibtex_tidy,
    })
  end,
}
