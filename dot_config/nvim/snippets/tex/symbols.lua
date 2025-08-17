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
		{ trig = "*", name = "subscript", snippetType = "autosnippet", conditon = in_math },
		fmta("^{<>}", {
			i(1),
		})
	),
	s(
		{ trig = "_", name = "subscript", snippetType = "autosnippet", conditon = in_math },
		fmta("_{<>}", {
			i(1),
		})
	),
	s(
		{ trig = ";/", name = "fraction", snippetType = "autosnippet", conditon = in_math },
		fmta(
			[[
				\frac{<>}{<>}
			]],
			{
				i(1),
				i(2),
			}
		)
	),
}
