-- cxIndentHighlight.nvim
-- 按每个 buffer 的 shiftwidth 画 indent guide：每个缩进级填充 sw 个字符（默认空格），
-- 与 tabstop 完全无关。为什么单独写、为什么不直接用 snacks.indent，见 README。
local M = {}

local ns = vim.api.nvim_create_namespace("cxIndentHighlight")

---@class cxIndentHighlight.Config
---@field hl string[]         每个 indent 级循环使用的高亮组
---@field char string         填充字符，会 rep(shiftwidth) 次；默认空格
---@field priority integer    extmark 优先级（建议低于 chunk/scope）
---@field exclude_filetypes string[]  这些 filetype 不画 guide

local defaults = {
  hl = { "CxIndent1", "CxIndent2", "CxIndent3", "CxIndent4", "CxIndent5", "CxIndent6", "CxIndent7", "CxIndent8" },
  char = " ",
  priority = 1,
  exclude_filetypes = {},
}

-- 默认暗色彩虹底色。default=true：不覆盖已存在的同名组 / colorscheme 定义。
local palette = { "#212123", "#1B2226", "#22192D", "#222123", "#18212D", "#1A1B2A", "#232323", "#18172D" }

local function define_hl()
  for i, color in ipairs(palette) do
    vim.api.nvim_set_hl(0, "CxIndent" .. i, { bg = color, default = true })
  end
end

local config

---setup
---@param opts? cxIndentHighlight.Config
function M.setup(opts)
  if M._setup then
    return
  end
  M._setup = true
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  define_hl()

  -- colorscheme 切换后会清掉自定义 hl，重新打一遍
  local group = vim.api.nvim_create_augroup("cxIndentHighlight", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_hl })

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, buf, top, bottom) -- top/bottom 为 0-indexed
      if vim.bo[buf].buftype ~= "" then
        return
      end
      local ft = vim.bo[buf].filetype
      for _, f in ipairs(config.exclude_filetypes) do
        if f == ft then
          return
        end
      end

      -- 关键：每 buffer、每次 redraw 现读 shiftwidth，guide 宽度随 buffer 变
      local sw = vim.bo[buf].shiftwidth
      if sw == 0 then
        sw = vim.bo[buf].tabstop
      end
      if sw <= 0 then
        return
      end
      local leftcol = vim.api.nvim_win_call(win, function()
        return vim.fn.winsaveview().leftcol
      end)
      local fill = config.char:rep(sw) -- 空格（或自定义字符）rep sw 次，不是 \t
      local hl = config.hl

      for l = top, bottom do
        local nb = vim.fn.nextnonblank(l + 1) -- 空行沿用下一个非空行的缩进
        if nb and nb > 0 then
          local indent = vim.fn.indent(nb)
          for level = 1, math.floor(indent / sw) do
            local col = (level - 1) * sw - leftcol
            if col >= 0 then
              vim.api.nvim_buf_set_extmark(buf, ns, l, 0, {
                virt_text = { { fill, hl[(level - 1) % #hl + 1] } },
                virt_text_pos = "overlay",
                virt_text_win_col = col,
                hl_mode = "combine",
                priority = config.priority,
                ephemeral = true,
              })
            end
          end
        end
      end
    end,
  })
end

return M
