local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local fmta = require("luasnip.extras.fmt").fmta -- Import fmta

local in_math = function()
	return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

return {
	s(
		{ trig = ";a", desc = "alpha", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\alpha"),
		})
	),
	s(
		{ trig = ";b", desc = "beta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\beta"),
		})
	),
	s(
		{ trig = ";g", desc = "gamma", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\gamma"),
		})
	),
	s(
		{ trig = ";d", desc = "delta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\delta"),
		})
	),
	s(
		{ trig = ";e", desc = "epsilon", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\varepsilon"),
		}),
		{ condition = in_math }
	),
	s(
		{ trig = ";z", desc = "zeta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\zeta"),
		})
	),
	s(
		{ trig = ";h", desc = "eta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\eta"),
		})
	),
	s(
		{ trig = ";q", desc = "theta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\theta"),
		})
	),
	s(
		{ trig = ";k", desc = "kappa", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\kappa"),
		})
	),
	s(
		{ trig = ";l", desc = "lambda", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\lambda"),
		})
	),
	s(
		{ trig = ";m", desc = "mu", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\mu"),
		})
	),
	s(
		{ trig = ";n", desc = "nu", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\nu"),
		})
	),
	s(
		{ trig = ";x", desc = "xi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\xi"),
		})
	),
	s(
		{ trig = ";p", desc = "pi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\pi"),
		})
	),
	s(
		{ trig = ";r", desc = "rho", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\rho"),
		})
	),
	s(
		{ trig = ";s", desc = "sigma", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\sigma"),
		})
	),
	s(
		{ trig = ";t", desc = "tau", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\tau"),
		})
	),
	s(
		{ trig = ";f", desc = "phi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\phi"),
		})
	),
	s(
		{ trig = ";c", desc = "chi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\chi"),
		})
	),
	s(
		{ trig = ";y", desc = "psi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\psi"),
		})
	),
	s(
		{ trig = ";o", desc = "omega", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\omega"),
		})
	),
	s(
		{ trig = ";G", desc = "Gamma", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Gamma"),
		})
	),
	s(
		{ trig = ";D", desc = "Delta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Delta"),
		})
	),
	s(
		{ trig = ";Q", desc = "Theta", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Theta"),
		})
	),
	s(
		{ trig = ";L", desc = "Lambda", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Lambda"),
		})
	),
	s(
		{ trig = ";X", desc = "Xi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Xi"),
		})
	),
	s(
		{ trig = ";P", desc = "Pi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Pi"),
		})
	),
	s(
		{ trig = ";S", desc = "Sigma", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Sigma"),
		})
	),
	s(
		{ trig = ";F", desc = "Phi", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Phi"),
		})
	),
	s(
		{ trig = ";Y", name = "Psi", snippetType = "autosnippet", { conditon = in_math } },
		fmta("<>", {
			t("\\Psi"),
		})
	),
	s(
		{ trig = ";U", desc = "Upsilon", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Upsilon"),
		})
	),
	s(
		{ trig = ";O", desc = "Omega", snippetType = "autosnippet", condition = in_math },
		fmta("<>", {
			t("\\Omega"),
		})
	),
}
