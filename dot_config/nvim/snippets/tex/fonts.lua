local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local f = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta -- Import fmta
local rep = require("luasnip.extras").rep

local in_math = function()
	return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

return {
	s(
		{ trig = "b([A-Z])", desc = "mathbf", regTrig = true, snippetType = "autosnippet", conditon = in_math },
		fmta("\\mathbf{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
	s(
		{ trig = "bb([A-Z])", desc = "mathbb", regTrig = true, snippetType = "autosnippet", conditon = in_math },
		fmta("\\mathbb{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
	s(
		{ trig = "c([A-Z])", desc = "mathcal", regTrig = true, snippetType = "autosnippet", condtion = in_math },
		fmta("\\mathcal{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
	s(
		{ trig = "f([A-Z])", desc = "mathfrak", regTrig = true, snippetType = "autosnippet", condition = in_math },
		fmta("\\mathfrak{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
	s(
		{ trig = "r([A-Z])", desc = "mathrm", regTrig = true, snippetType = "autosnippet", conditon = in_math },
		fmta("\\mathrm{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
	s(
		{ trig = "s([A-Z])", desc = "mathscr", regTrig = true, snippetType = "autosnippet", condition = in_math },
		fmta("\\mathscr{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
		})
	),
}
