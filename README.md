# cxIndentHighlight.nvim

一个**极简**的 indent guide：按当前 buffer 的 `shiftwidth`，在每个缩进级填 `sw` 个字符（默认空格），循环上色。**与 `tabstop` 完全无关**。

## 为什么单独写这一个

起因是 snacks.nvim 的 `indent` 在某些文件里把前 8 列整块盖死。排查下来是两层问题叠在一起，而 snacks 的架构没法在不改它源码的前提下修好，所以单独抽出来。

### 1. guide 字符是 `\t`，而 TAB 的宽度由 `tabstop` 决定

之前配置里 `indent.char = "\t"`。snacks 把这个字符作为 virt_text 贴在每级缩进处。但 **Neovim 渲染 virtual text 里的 `\t` 时，按当前 buffer 的 `tabstop` 展开到下一个停靠点**（这是 TAB 字符的固有语义，`:h 'tabstop'`：*"the width of a TAB character"*；`shiftwidth` 管的是缩进步长，跟字形宽度无关）。

所以一旦某个项目的 `.editorconfig` 把 `tabstop` 设成 8（例如 `nvim-lspconfig` 仓库自带的 `.editorconfig` 里 `tab_width = 8`），第 0 列那个 guide tab 就从 col 0 展开到 col 8，**一次性铺满前 8 列**，再叠上暗色高亮，就是"前 8 列被盖住"。`:set tabstop=2` 能临时修好，正是因为让 tab 宽度重新等于 2。

> 顺带澄清：chunk（`─│╭╰>`）和 scope（`│`）用的都是定宽字符，不受 tabstop 影响。**只有 guide 受影响**，因为它用了 `\t`。所以这个插件只替换 guide，chunk/scope 继续用 snacks。

### 2. 想让 guide 宽度随 buffer 的 `shiftwidth` 变 —— snacks 做不到

理想效果：lua（sw=2）画 2 格 guide、rust（sw=4）画 4 格，且都不受 tabstop 影响。

但 snacks.indent 的 guide 字符有三个硬限制（都看了源码）：

- `Snacks.config.get` 内部对配置做了 `vim.deepcopy`（`init.lua:116`），返回的是**拷贝**；
- `indent.enable()` 在第一次 `BufReadPost` 时（`once = true`）把这份配置**快照**进一个 module-local（`indent.lua:489`），之后渲染读的是这份快照（`indent.lua:165`），改 `Snacks.config` 不再生效；
- 而且 `opts` 里的 `char` 是**静态字符串**，snacks 不会替你按 `shiftwidth` 去算。

结论：snacks 的 guide 字符是**全局、一次性、静态**的，没法 per-buffer 随 `shiftwidth` 变。固定写 `char = "  "` 又会在 sw=4 的文件里只填一半。要 per-buffer + tabstop 无关，只能自己画。

## 这个插件怎么解决

自己挂一个 decoration provider，`on_win` 里**每个 buffer、每次 redraw 现读 `shiftwidth`**，guide 填 `char:rep(sw)` 个字符：

- `char` 默认是空格 → 永远不会被 tabstop 展开，`tabstop=8` 也无所谓；
- 宽度 = `shiftwidth` → sw=2 填 2 格、sw=4 填 4 格，per-buffer 自动适配，多窗口 split 各自正确；
- `ephemeral = true` 的 extmark，每次 redraw 重画，跟 snacks/ibl 一个套路。

## 安装（本地路径，lazy.nvim）

```lua
{
  dir = "~/software/nvim/cxIndentHighlight.nvim",
  name = "cxIndentHighlight",
  lazy = false,
  config = function()
    require("cxIndentHighlight").setup({
      -- 复用你已有的高亮组（在那边定义底色），或省略用内置 CxIndent1..8
      hl = require("cxhl.hlIndent").cxhl,
    })
  end,
}
```

## 配置

```lua
require("cxIndentHighlight").setup({
  hl = { "CxIndent1", "CxIndent2", "CxIndent3", "CxIndent4",
         "CxIndent5", "CxIndent6", "CxIndent7", "CxIndent8" }, -- 每级循环
  char = " ",              -- 填充字符，rep(shiftwidth) 次；保持空格才 tabstop 无关
  priority = 1,            -- extmark 优先级，低于 chunk/scope(200)
  exclude_filetypes = {},  -- 这些 filetype 不画
})
```

| 字段 | 默认 | 说明 |
| --- | --- | --- |
| `hl` | `CxIndent1..8` | 每个缩进级循环使用的高亮组；不传则用内置暗色彩虹底色 |
| `char` | `" "` | 填充字符。**保持空格**才能保证 tabstop 无关 |
| `priority` | `1` | extmark 优先级 |
| `exclude_filetypes` | `{}` | 跳过的 filetype |

内置 `CxIndent1..8` 用 `default = true` 定义，不会覆盖 colorscheme 或你已定义的同名组。

## 备注

- 没做缩进缓存（snacks 按 `changedtick` 缓存），每次 redraw 全重算 `nextnonblank`/`indent`。日常文件无感，超大文件可感知；真碰到再加 `state` 缓存即可。
- `vim.fn.indent()` 对含真 TAB 的行会按 `tabstop` 折算缩进宽度——这只影响"这行算第几级"的位置判断，不影响 guide 字形宽度（字形始终是 `char`，默认空格）。对纯空格缩进的文件完全精确。
