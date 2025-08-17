-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

local augroup = vim.api.nvim_create_augroup("tex", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "*.tex",
	callback = function()
		vim.cmd([[
      highlight! link Conceal       Special
      highlight! link texCmdGreek   Special
      highlight! link texMathOper   texDelim
      highlight! link texMathDelim  texDelim
      highlight! texDelim gui=bold guifg=#89b4fa
    ]])
	end,
})

-- Auto-save .tex files on InsertLeave or FocusLost
vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost" }, {
	group = augroup,
	pattern = "*.tex",
	callback = function()
		-- Only save if the buffer is modified
		if vim.bo.modified then
			vim.cmd("silent write")
		end
	end,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "VimtexEventQuit",
	group = augroup,
	desc = "Clean files on exit.",
	command = [[ call vimtex#compiler#clean(0) ]],
})
