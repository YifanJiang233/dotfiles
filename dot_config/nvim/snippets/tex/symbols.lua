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
		{
			trig = "([^%(%{%,])*",
			name = "supscript",
			snippetType = "autosnippet",
			wordTrig = false,
			regTrig = true,
			conditon = in_math,
		},
		fmta("<>^{<>}", {
			f(function(_, snip)
				return snip.captures[1]
			end),
			i(1),
		})
	),
	s(
		{ trig = "_", name = "subscript", snippetType = "autosnippet", wordTrig = false, conditon = in_math },
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
	s(
		{ trig = ";<", name = "angle bracket", snippetType = "autosnippet", { conditon = in_math } },
		fmta("\\langle <>, <> \\rangle", {
			i(1),
			i(2),
		})
	),
}
