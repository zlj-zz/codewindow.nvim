local M = {}

local utils = require("codewindow.utils")

local hl_namespace
local screenbounds_namespace
local diagnostic_namespace
local cursor_namespace

local api = vim.api
local highlight_range = vim.highlight.range

local last_screen_bounds = {}

local capture_category = {
  keyword = "keyword",
  ["keyword.function"] = "keyword",
  ["keyword.operator"] = "keyword",
  ["keyword.return"] = "keyword",
  conditional = "keyword",
  ["repeat"] = "keyword",
  operator = "keyword",
  exception = "keyword",
  string = "string",
  ["string.documentation"] = "string",
  ["string.regex"] = "string",
  ["string.escape"] = "string",
  character = "string",
  number = "string",
  float = "string",
  boolean = "string",
  comment = "comment",
  ["comment.documentation"] = "comment",
}

local function normalize_capture(capture)
  return capture_category[capture]
end

function M.setup()
  hl_namespace = api.nvim_create_namespace("codewindow.highlight")
  screenbounds_namespace = api.nvim_create_namespace("codewindow.screenbounds")
  diagnostic_namespace = api.nvim_create_namespace("codewindow.diagnostic")
  cursor_namespace = api.nvim_create_namespace("codewindow.cursor")

  api.nvim_set_hl(0, "CodewindowBackground", { link = "NormalFloat", default = true })
  api.nvim_set_hl(0, "CodewindowBorder", { fg = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowWarn", { link = "DiagnosticSignWarn", default = true })
  api.nvim_set_hl(0, "CodewindowError", { link = "DiagnosticSignError", default = true })
  api.nvim_set_hl(0, "CodewindowAddition", { fg = "#aadb56", default = true })
  api.nvim_set_hl(0, "CodewindowDeletion", { fg = "#fc4c4c", default = true })
  api.nvim_set_hl(0, "CodewindowUnderline", { underline = true, sp = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowBoundsBackground", { bg = "#2d2d2d", default = true })
end

local function create_hl_namespaces(buffer)
  api.nvim_buf_clear_namespace(buffer, hl_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, screenbounds_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, diagnostic_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, cursor_namespace, 0, -1)
end

local function most_commons(highlight)
  local max = 0
  local result = {}
  for entry, count in pairs(highlight) do
    if count > max then
      max = count
      result = { entry }
    elseif count == max then
      table.insert(result, entry)
    end
  end
  return result
end

function M.extract_highlighting(buffer, lines)
  local config = require("codewindow.config").get()
  if not config.use_treesitter or not api.nvim_buf_is_valid(buffer or -1) then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buffer)
  if not ok or parser == nil then
    return
  end

  local line_count = #lines
  local minimap_width = config.minimap_width
  local minimap_height = math.ceil(line_count / 4)
  local width_multiplier = config.width_multiplier
  local minimap_char_width = minimap_width * width_multiplier * 2

  local highlights = {}
  for _ = 1, minimap_height do
    local line = {}
    for _ = 1, minimap_width do
      table.insert(line, {})
    end
    table.insert(highlights, line)
  end

  local lang = parser:lang()
  local query = vim.treesitter.query.get(lang, "highlights")
  if not query then
    return highlights
  end

  local trees = parser:parse()
  if not trees then
    return highlights
  end
  for _, tstree in ipairs(trees) do
    if tstree then
      local root = tstree:root()
      local iter = query:iter_captures(root, buffer, 0, line_count + 1)

      for capture, node, _ in iter do
        local c = query.captures[capture]
        if c ~= nil then
          if config.minimal_highlights then
            c = normalize_capture(c)
          end
          if c then
            local start_row0, start_col0, end_row0, end_col0 = vim.treesitter.get_node_range(node)

            local last_row0 = math.max(start_row0, math.min(end_row0 - 1, line_count - 1))
            for row0 = start_row0, last_row0 do
              for col0 = start_col0, math.min(end_col0 - 1, minimap_char_width - 1) do
                local minimap_x_idx, minimap_y_idx = utils.buf_to_minimap(col0, row0, config)
                highlights[minimap_y_idx][minimap_x_idx][c] = (highlights[minimap_y_idx][minimap_x_idx][c] or 0) + 1
              end
            end
          end
        end
      end
    end
  end

  for y = 1, minimap_height do
    for x = 1, minimap_width do
      local cell = highlights[y][x]
      if next(cell) then
        highlights[y][x] = most_commons(cell)
      end
    end
  end

  return highlights
end

local function contains_group(cell, group)
  for i, v in ipairs(cell) do
    if v == group then
      return i
    end
  end
  return nil
end

function M.apply_highlight(highlights, buffer, lines)
  local config = require("codewindow.config").get()
  local minimap_height = math.ceil(#lines / 4)
  local minimap_width = config.minimap_width

  create_hl_namespaces(buffer)

  if highlights ~= nil then
    for y = 1, minimap_height do
      for x = 1, minimap_width do
        for _, group in ipairs(highlights[y][x]) do
          if group ~= "" then
            local end_x = x
            while end_x < minimap_width do
              local pos = contains_group(highlights[y][end_x + 1], group)
              if not pos then
                break
              end
              end_x = end_x + 1
              highlights[y][x][pos] = ""
            end
            api.nvim_buf_set_extmark(buffer, hl_namespace, y - 1, (x - 1) * 3 + 6, {
              end_col = end_x * 3 + 6,
              hl_group = "@" .. group,
              strict = false,
            })
          end
        end
      end
    end
  end

  for y = 1, minimap_height do
    api.nvim_buf_set_extmark(buffer, diagnostic_namespace, y - 1, 0, {
      end_col = 3,
      hl_group = "CodewindowError",
      strict = false,
    })
    api.nvim_buf_set_extmark(buffer, diagnostic_namespace, y - 1, 3, {
      end_col = 6,
      hl_group = "CodewindowWarn",
      strict = false,
    })

    local git_start = 6 + 3 * config.minimap_width
    highlight_range(
      buffer,
      diagnostic_namespace,
      "CodewindowAddition",
      { y - 1, git_start },
      { y - 1, git_start + 3 },
      {}
    )
    highlight_range(
      buffer,
      diagnostic_namespace,
      "CodewindowDeletion",
      { y - 1, git_start + 3 },
      { y - 1, git_start + 6 },
      {}
    )
  end
end

function M.display_screen_bounds(window)
  local config = require("codewindow.config").get()
  if screenbounds_namespace == nil then
    return
  end

  local topline = utils.get_top_line(window.parent_win)
  local botline = utils.get_bot_line(window.parent_win)

  local difference = math.ceil((botline - topline) / 4) + 1

  local top_y = math.floor(topline / 4)
  local bot_y = top_y + difference - 1
  local buf_height = api.nvim_buf_line_count(window.buffer)

  if bot_y > buf_height - 1 then
    bot_y = buf_height - 1
  end

  if bot_y < 0 then
    return
  end

  -- cache: skip if bounds unchanged
  local cache = last_screen_bounds[window.buffer]
  if cache and cache.top_y == top_y and cache.bot_y == bot_y and cache.mode == config.screen_bounds then
    return
  end
  last_screen_bounds[window.buffer] = { top_y = top_y, bot_y = bot_y, mode = config.screen_bounds }

  api.nvim_buf_clear_namespace(window.buffer, screenbounds_namespace, 0, -1)

  if top_y > 0 and config.screen_bounds == "lines" then
    api.nvim_buf_set_extmark(window.buffer, screenbounds_namespace, top_y - 1, 6, {
      end_col = 6 + config.minimap_width * 3,
      hl_group = "CodewindowUnderline",
      strict = false,
    })
  end

  if config.screen_bounds == "lines" then
    api.nvim_buf_set_extmark(window.buffer, screenbounds_namespace, bot_y, 6, {
      end_col = 6 + config.minimap_width * 3,
      hl_group = "CodewindowUnderline",
      strict = false,
    })
  end

  if config.screen_bounds == "background" then
    local end_col = 6 + config.minimap_width * 3
    local line_text = api.nvim_buf_get_lines(window.buffer, top_y, top_y + 1, true)[1] or ""
    if #line_text < end_col then
      end_col = #line_text
    end
    if end_col > 6 then
      api.nvim_buf_set_extmark(window.buffer, screenbounds_namespace, top_y, 6, {
        end_line = bot_y + 1,
        end_col = end_col,
        hl_group = "CodewindowBoundsBackground",
      })
    end
  end

  local center = math.floor((top_y + bot_y) / 2) + 1
  if window.focused and api.nvim_win_is_valid(window.window) then
    api.nvim_win_set_cursor(window.window, { center, 0 })
  end
end

function M.display_cursor(window)
  local config = require("codewindow.config").get()
  if not config.show_cursor then
    return
  end

  if api.nvim_buf_is_valid(window.buffer or -1) then
    api.nvim_buf_clear_namespace(window.buffer, cursor_namespace, 0, -1)
  end
  if not api.nvim_win_is_valid(window.parent_win) then
    return
  end
  local cursor = api.nvim_win_get_cursor(window.parent_win)

  local cursor_line = api.nvim_buf_get_lines(window.parent_win, cursor[1] - 1, cursor[1], true)[1] or ""
  local before_cursor = cursor_line:sub(1, cursor[2])
  local cursor_col = #utils.expand_line(before_cursor)

  local minimap_x, minimap_y = utils.buf_to_minimap(cursor_col, cursor[1] - 1)

  minimap_x = minimap_x + 2 - 1
  minimap_y = minimap_y - 1

  if api.nvim_buf_is_valid(window.buffer or -1) then
    api.nvim_buf_set_extmark(window.buffer, cursor_namespace, minimap_y, minimap_x * 3, {
      end_col = minimap_x * 3 + 3,
      hl_group = "Cursor",
      strict = false,
    })
  end
end

return M
