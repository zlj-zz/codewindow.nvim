local M = {}

local api = vim.api
local minimap_txt = require('codewindow.text')
local minimap_hl = require('codewindow.highlight')
local minimap_err = require('codewindow.errors')
local utils = require('codewindow.utils')

local render_cache = {}

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

function M.clear_cache(buffer)
  if buffer then
    render_cache[buffer] = nil
  else
    render_cache = {}
  end
end

function M.render(window, current_buffer)
  if not api.nvim_buf_is_valid(current_buffer or -1) then return end
  local config = require('codewindow.config').get()

  api.nvim_set_option_value('modifiable', true, { buf = window.buffer })
  local lines = api.nvim_buf_get_lines(current_buffer, 0, -1, true)

  if config.max_lines and #lines > config.max_lines then
    api.nvim_buf_set_lines(window.buffer, 0, -1, true, {})
    api.nvim_set_option_value('modifiable', false, { buf = window.buffer })
    render_cache[current_buffer] = nil
    return
  end

  local tick = api.nvim_buf_get_changedtick(current_buffer)
  local cached = render_cache[current_buffer]
  local needs_recompute = not cached or cached.tick ~= tick
  local minimap_text

  if needs_recompute then
    minimap_text = minimap_txt.compress_text(lines)
    render_cache[current_buffer] = { tick = tick, minimap_text = minimap_text }
  else
    minimap_text = cached.minimap_text
  end

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

  local highlights
  if needs_recompute then
    highlights = minimap_hl.extract_highlighting(current_buffer, lines)
    render_cache[current_buffer].highlights = highlights
  else
    highlights = cached.highlights
  end
  minimap_hl.apply_highlight(highlights, window.buffer, lines)

  if config.show_cursor then
    minimap_hl.display_cursor(window)
  end

  minimap_hl.display_screen_bounds(window)
  api.nvim_set_option_value('modifiable', false, { buf = window.buffer })
end

return M
