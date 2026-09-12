local M = {}
local api = vim.api

function M.setup()
  if M._setup then return end
  M._setup = true

  vim.opt.showcmd = false

  local ns = api.nvim_create_namespace("KeyIndicator")
  local group = api.nvim_create_augroup("KeyIndicator", { clear = true })
  local timer = -1
  local keys, win, buf = {}, nil, nil
  local enabled, generation = true, 0

  local function hide()
    keys = {}
    if win and api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    win = nil
  end

  local function draw()
    local text = table.concat(keys)
    if text == "" then return end
    local width = math.min(vim.fn.strdisplaywidth(text), math.max(1, vim.o.columns - 2))
    if not buf or not api.nvim_buf_is_valid(buf) then
      buf = api.nvim_create_buf(false, true)
      vim.bo[buf].bufhidden = "hide"
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    local opts = {
      relative = "editor", anchor = "SE",
      row = math.max(1, vim.o.lines - vim.o.cmdheight - 1),
      col = math.max(1, vim.o.columns - 1),
      width = width, height = 1, style = "minimal", border = "none",
      focusable = false, mouse = false, noautocmd = true, zindex = 40,
    }
    if win and api.nvim_win_is_valid(win) then
      api.nvim_win_set_config(win, opts)
    else
      win = api.nvim_open_win(buf, false, opts)
      vim.wo[win].winhighlight = "Normal:Comment,NormalFloat:Comment"
      vim.wo[win].wrap = false
    end
    -- Counts and operator prefixes otherwise wait for the next normal-mode redraw.
    vim.cmd.redraw()
  end

  vim.on_key(function(_, typed)
    if not enabled or typed == "" then return end
    local key = vim.fn.keytrans(typed)
    if key:find("Mouse") or key:find("Scroll") or key:find("Drag") or key:find("Release") then return end
    key = key:gsub("<C%-", "<Ctrl-"):gsub("<M%-", "<Alt-")
    key = ({
      ["<Space>"] = "␣",
      ["<CR>"] = "↵",
      ["<Esc>"] = "Esc",
      ["<Tab>"] = "Tab",
      ["<BS>"] = "⌫",
      ["<Del>"] = "Del",
    })[key] or key
    keys[#keys + 1] = key
    if #keys > 5 then table.remove(keys, 1) end
    generation = generation + 1
    local current = generation
    draw()
    vim.fn.timer_stop(timer)
    timer = vim.fn.timer_start(2000, function()
      if current == generation then
        hide()
        vim.cmd.redraw()
      end
    end)
  end, ns)

  api.nvim_create_user_command("KeyIndicatorToggle", function()
    enabled = not enabled
    vim.fn.timer_stop(timer)
    hide()
  end, { desc = "Toggle compact keystroke indicator" })
  api.nvim_create_autocmd("VimResized", { group = group, callback = draw })
  api.nvim_create_autocmd("TabLeave", { group = group, callback = hide })
  api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
    vim.on_key(nil, ns)
    vim.fn.timer_stop(timer)
  end })
end

return M
