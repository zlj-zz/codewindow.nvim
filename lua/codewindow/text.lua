local M = {}

local minimap_hl = require('codewindow.highlight')
local minimap_err = require('codewindow.errors')
local utils = require('codewindow.utils')

local api = vim.api

local function is_whitespace(chr)
  return chr == " " or chr == "\t" or chr == ""
end

local function compress_text(lines)
  local config = require('codewindow.config').get()
  local tab2chars = string.rep(" ", vim.bo.tabstop)
  local scanned_text = {}
  for _ = 1, math.ceil(#lines / 4) do
    local line = {}
    for _ = 1, config.minimap_width do
      table.insert(line, 0)
    end
    table.insert(scanned_text, line)
  end

  for line_idx = 1, #lines do
    local row0 = line_idx - 1
    local current_line = lines[line_idx]:gsub("\t", tab2chars)
    for braille_x0 = 0, config.minimap_width * 2 - 1 do

      local any_printable = false
      for dx = 0, config.width_multiplier - 1 do
        local buf_col0 = braille_x0 * config.width_multiplier + dx
        local chr = current_line:sub(buf_col0 + 1, buf_col0 + 1)
        if not is_whitespace(chr) then
          any_printable = true
        end
      end

      if any_printable then
        local flag = utils.coord_to_flag(braille_x0, row0)
        local minimap_x_idx = math.floor(braille_x0 / 2) + 1
        local minimap_y_idx = math.floor(row0 / 4) + 1
        scanned_text[minimap_y_idx][minimap_x_idx] = scanned_text[minimap_y_idx][minimap_x_idx] + flag
      end
    end
  end

  local minimap_text = {}
  local parts = {}
  for _ = 1, config.minimap_width do
    table.insert(parts, "")
  end
  for y = 1, #scanned_text do
    for x, flag in ipairs(scanned_text[y]) do
      parts[x] = utils.flag_to_char(flag)
    end
    minimap_text[y] = table.concat(parts, "", 1, config.minimap_width)
  end

  return minimap_text
end

function M.update_minimap(current_buffer, window)
  if not api.nvim_buf_is_valid(current_buffer or -1) then return end
  local config = require('codewindow.config').get()

  api.nvim_buf_set_option(window.buffer, 'modifiable', true)
  local lines = api.nvim_buf_get_lines(current_buffer, 0, -1, true)

  local minimap_text = compress_text(lines)

  local placeholder_str = string.rep(utils.flag_to_char(0), 2)

  local text = {}

  local error_text
  if config.use_lsp then
    error_text = minimap_err.get_lsp_errors(current_buffer, #lines)
  else
    error_text = {}
  end

  local git_text
  if config.use_git then
    local git = require('codewindow.git')
    git_text = git.get_git_text(lines, current_buffer)
    git.refresh(current_buffer, function()
      if api.nvim_win_is_valid(window.window or -1)
         and api.nvim_win_get_buf(window.parent_win or -1) == current_buffer then
        M.update_minimap(current_buffer, window)
      end
    end)
  else
    git_text = {}
  end
  for i = 1, #minimap_text do
    local line = (error_text[i] or placeholder_str)
        .. minimap_text[i]
        .. (git_text[i] or placeholder_str)
    text[i] = line
  end

  api.nvim_buf_set_lines(window.buffer, 0, -1, true, text)

  local highlights = minimap_hl.extract_highlighting(current_buffer, lines)
  minimap_hl.apply_highlight(highlights, window.buffer, lines)

  if config.show_cursor then
    minimap_hl.display_cursor(window)
  end

  minimap_hl.display_screen_bounds(window)
  api.nvim_buf_set_option(window.buffer, 'modifiable', false)
end

return M
