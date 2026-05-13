local M = {}

local api = vim.api
local minimap_txt = require('codewindow.text')
local minimap_hl = require('codewindow.highlight')
local minimap_err = require('codewindow.errors')
local utils = require('codewindow.utils')

local function build_lines(minimap_text, error_text, git_text)
  local placeholder = string.rep(utils.flag_to_char(0), 2)
  local text = {}
  for i = 1, #minimap_text do
    local line = (error_text[i] or placeholder)
        .. minimap_text[i]
        .. (git_text[i] or placeholder)
    text[i] = line
  end
  return text
end

function M.render(window, current_buffer)
  if not api.nvim_buf_is_valid(current_buffer or -1) then return end
  local config = require('codewindow.config').get()

  api.nvim_buf_set_option(window.buffer, 'modifiable', true)
  local lines = api.nvim_buf_get_lines(current_buffer, 0, -1, true)

  local minimap_text = minimap_txt.compress_text(lines)

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
        M.render(window, current_buffer)
      end
    end)
  else
    git_text = {}
  end

  local text = build_lines(minimap_text, error_text, git_text)

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
