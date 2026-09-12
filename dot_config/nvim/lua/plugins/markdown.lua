---@type LazySpec
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  cmd = { "RenderMarkdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
  keys = {
    { "<LocalLeader>mr", "<Cmd>RenderMarkdown toggle<CR>", ft = "markdown", desc = "Toggle rendering" },
    { "<LocalLeader>mp", "<Cmd>RenderMarkdown preview<CR>", ft = "markdown", desc = "Toggle split preview" },
    {
      "<LocalLeader>mo",
      function() require("aerial").toggle { focus = false } end,
      ft = "markdown",
      desc = "Toggle heading outline",
    },
    {
      "<LocalLeader>mc",
      function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local tree = vim.treesitter.get_parser(0, "markdown"):parse()[1]
        local query = vim.treesitter.query.parse("markdown", [[
          (task_list_marker_unchecked) @unchecked
          (task_list_marker_checked) @checked
        ]])
        for id, node in query:iter_captures(tree:root(), 0, row, row + 1) do
          local start_row, start_col, end_row, end_col = node:range()
          if start_row == row then
            local marker = query.captures[id] == "unchecked" and "[x]" or "[ ]"
            vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { marker })
            return
          end
        end
        vim.notify("No Markdown checkbox on this line", vim.log.levels.INFO)
      end,
      ft = "markdown",
      desc = "Toggle checkbox",
    },
  },
  specs = {
    {
      "AstroNvim/astrocore",
      opts = { mappings = { n = { ["<LocalLeader>m"] = { desc = "Markdown" } } } },
    },
  },
  opts = {
    -- Keep surrounding text rendered while editing; reveal syntax on the cursor line.
    render_modes = { "n", "c", "i" },
    anti_conceal = { enabled = true },
    heading = {
      icons = { "★ ", "☆ ", "✦ ", "✧ ", "◆ ", "◇ " },
      -- Leave the terminal's transparent background visible.
      backgrounds = {},
      sign = false,
      width = "block",
      right_pad = 1,
    },
    win_options = {
      conceallevel = { default = 0, rendered = 3 },
      concealcursor = { default = "", rendered = "" },
    },
  },
}
