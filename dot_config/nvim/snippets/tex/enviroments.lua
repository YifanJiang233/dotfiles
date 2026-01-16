local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local c = ls.choice_node
local f = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta -- Import fmta
local rep = require("luasnip.extras").rep

local in_math = function() return vim.fn["vimtex#syntax#in_mathzone"]() == 1 end

local not_in_math = function() return vim.fn["vimtex#syntax#in_mathzone"]() == 0 end

return {
  s(
    {
      trig = [[\\]],
      name = "create an inline math environment",
      snippetType = "autosnippet",
      condition = not_in_math,
    },
    fmta(
      [[
				\(<>\)
			]],
      {
        i(1),
      }
    )
  ),
  s(
    { trig = "bb", desc = "create a new environment", snippetType = "autosnippet", condition = not_in_math },
    fmta(
      [[
        \begin{<>}
            <>
        \end{<>}
      ]],
      {
        i(1),
        i(2),
        rep(1),
      }
    )
  ),
  s(
    {
      trig = "beq",
      desc = "create a new equation environment",
      snippetType = "autosnippet",
      condition = not_in_math,
    },
    fmta(
      [[
        \begin{equation}
            <>
        \end{equation}
      ]],
      {
        i(1),
      }
    )
  ),
  s(
    {
      trig = "bseq",
      desc = "create a new equation* environment",
      snippetType = "autosnippet",
      condition = not_in_math,
    },
    fmta(
      [[
        \begin{equation*}
            <>
        \end{equation*}
      ]],
      {
        i(1),
      }
    )
  ),
  s(
    { trig = "bal", desc = "create a new align environment", snippetType = "autosnippet", condition = not_in_math },
    fmta(
      [[
        \begin{align}
            <>
        \end{align}
      ]],
      {
        i(1),
      }
    )
  ),
  s(
    {
      trig = "bsal",
      desc = "create a new align* environment",
      snippetType = "autosnippet",
      condition = not_in_math,
    },
    fmta(
      [[
        \begin{align*}
            <>
        \end{align*}
      ]],
      {
        i(1),
      }
    )
  ),
  s(
    {
      trig = "bald",
      desc = "create a new aligned environment",
      snippetType = "autosnippet",
      condition = in_math,
    },
    fmta(
      [[
      	\left\{
        \begin{aligned}
            <>
        \end{aligned}
        \right.
      ]],
      {
        i(1),
      }
    )
  ),
}
