return {
  "Saghen/blink.cmp",
  optional = true,
  dependencies = {
    -- add the legacy cmp source as a dependency for `blink.cmp`
    "micangl/cmp-vimtex",
  },
  specs = {
    -- install the blink, nvim-cmp compatibility layer
    { "Saghen/blink.compat", version = "*", lazy = true, opts = {} },
  },
  opts = {
    sources = {
      -- enable the provider by default
      default = { "vimtex" },
      -- configure the provider for your new source
      providers = {
        vimtex = {
          name = "vimtex",
          module = "blink.compat.source",
          score_offset = 100,
        },
      },
    },
  },
}
