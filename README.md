# cxIndentHighlight.nvim

> **Fixes snacks.indent:** its guide `char` is snapshotted once and shared by every buffer, so the width can't follow each file's `shiftwidth` — this plugin renders it `shiftwidth` cells wide, per buffer.

A minimal indent guide. Each indentation level is filled with `shiftwidth` cells
(spaces by default), cycled through a list of highlight groups. The fill width
tracks **each buffer's `shiftwidth`**, so a `sw=2` file gets 2-cell guides and a
`sw=4` file gets 4-cell guides — automatically, per buffer.

Only the **indent guide** is implemented. No scope, no chunk, no line numbers, no
Treesitter dependency.

## How it differs

|                       | cxIndentHighlight                      | snacks.nvim (`indent`)                      | shellRaining/hlchunk.nvim            |
| --------------------- | -------------------------------------- | ------------------------------------------- | ------------------------------------ |
| Indent guide          | solid `sw`-wide block, **per-buffer `shiftwidth`** | guide `char` is one **global, static** value (same in every buffer) | `blank` does solid fill |
| Scope                 | —                                      | ✅                                          | —                                    |
| Chunk (box)           | —                                      | ✅                                          | ✅                                    |
| Line numbers          | —                                      | —                                          | ✅                                    |
| Treesitter            | not required                           | not required                               | used for chunk                       |
| Fill char             | spaces (tabstop-proof by default)      | you choose (a tab char would be tabstop-fragile) | commonly `\t` (tabstop-sensitive)    |

**Why per-buffer matters.** snacks reads its guide `char` once — a deep-copied
snapshot taken at the first `BufReadPost` (`once = true`) — and reuses it for
every buffer, so a fixed string can't grow or shrink with each file's
`shiftwidth`. This plugin reads `shiftwidth` fresh on every redraw, per buffer,
so the guide always matches the file you are in. It fills with spaces instead of
a tab, so `tabstop` never changes the guide width.

## What to turn off in snacks

This plugin replaces snacks' indent **guides** only. Keep snacks' scope and
chunk, disable its guides:

```lua
require("snacks").setup({
  indent = {
    indent = { enabled = false }, -- 👈 snacks indent GUIDES off — this plugin replaces them
    scope = { enabled = true },   -- keep
    chunk = { enabled = true },   -- keep
  },
})
```

## Install (lazy.nvim)

```lua
{
  "cxwx/cxIndentHighlight.nvim",
  name = "cxIndentHighlight",
  lazy = false,
  config = function()
    require("cxIndentHighlight").setup({
      -- reuse your own highlight groups, or omit to use the built-in CxIndent1..8
      hl = require("cxhl.hlIndent").cxhl,
    })
  end,
}
```

## Options

```lua
require("cxIndentHighlight").setup({
  hl = { "CxIndent1", "CxIndent2", "CxIndent3", "CxIndent4",
         "CxIndent5", "CxIndent6", "CxIndent7", "CxIndent8" },
  char = " ",             -- fill char, repeated shiftwidth times
  priority = 1,           -- extmark priority (keep below chunk/scope)
  exclude_filetypes = {}, -- filetypes to skip
})
```

| Option             | Default        | Notes                                                                |
| ------------------ | -------------- | -------------------------------------------------------------------- |
| `hl`               | `CxIndent1..8` | highlight groups cycled per level; built-in dark rainbow if omitted  |
| `char`             | `" "`          | fill character; keep a space so the guide stays tabstop-proof        |
| `priority`         | `1`            | extmark priority                                                     |
| `exclude_filetypes`| `{}`           | filetypes to skip                                                    |

Built-in `CxIndent1..8` are defined with `default = true`, so they will not
override a colorscheme or groups you define yourself.

## Notes

- No indent caching (snacks caches by `changedtick`); `nextnonblank`/`indent`
  are recomputed each redraw. Fine for normal files — add a `state` cache if
  very large files feel slow.
- `vim.fn.indent()` counts a literal tab using `tabstop`, which only affects
  *which level* a tab-indented line lands on, not the guide glyph width (always
  `char`, a space by default). Exact for space-indented files.
