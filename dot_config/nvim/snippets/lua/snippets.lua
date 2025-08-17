-- This is a snippet for creating new LuaSnip snippets.

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local fmta = require("luasnip.extras.fmt").fmta -- Import fmta

return {
	s(
		{ trig = "ss", desc = "create a single-line luasnip snippet", snippetType = "autosnippet" },
		fmta(
			[[
        s({ trig = "<>", name = "<>"<><> },
          fmta(
            "<>",
            {
              <>
            }
          )
        ),
      ]],
			{
				i(1, "trigger"), -- Placeholder for the trigger word
				i(2, "description"), -- Placeholder for the description
				-- Choice between a regular snippet and an autosnippet
				c(3, {
					t(', snippetType = "autosnippet"'),
					t(""),
				}),
				c(4, {
					t(",{ conditon = in_math }"),
					t(",{ conditon = not_in_math }"),
					t(""),
				}),
				i(5, "snippet body"),
				i(6, "nodes list"),
			}
		)
	),
	s(
		{ trig = "ms", desc = "create a multi-line luasnip snippet", snippetType = "autosnippet" },
		fmta(
			[=[
        s({ trig = "<>", name = "<>"<><> },
          fmta(
          	[[
            	<>
            ]],
            {
              <>
            }
          )
        ),
      ]=],
			{
				i(1, "trigger"), -- Placeholder for the trigger word
				i(2, "description"), -- Placeholder for the description
				-- Choice between a regular snippet and an autosnippet
				c(3, {
					t(', snippetType = "autosnippet"'),
					t(""),
				}),
				c(4, {
					t(",{ conditon = in_math }"),
					t(""),
				}),
				i(5, "snippet body"),
				i(6, "nodes list"),
			}
		)
	),
	s({ trig = ";;", name = "auto complete angle bracket", snippetType = "autosnippet" }, fmta("<>", { t("<>") })),
}
