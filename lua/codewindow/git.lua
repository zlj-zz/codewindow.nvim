local M = {}

local utils = require("codewindow.utils")

local FLAGS = { 1, 2, 4, 8 }
local MIN_REFRESH_MS = 100

-- Per-buffer state: { cache = {add_lines, remove_lines}, pending = bool, last_refresh = ms }
local buf_state = {}

local function get_state(bufnr)
  if not buf_state[bufnr] then
    buf_state[bufnr] = {}
  end
  return buf_state[bufnr]
end

local function set_equal(a, b)
  if a == b then
    return true
  end
  if not a or not b then
    return false
  end
  for k in pairs(a) do
    if not b[k] then
      return false
    end
  end
  for k in pairs(b) do
    if not a[k] then
      return false
    end
  end
  return true
end

local function parse_diff_lines(diff_lines)
  local add_lines = {}
  local remove_lines = {}

  for _, line in ipairs(diff_lines) do
    if line:sub(1, 2) == "@@" then
      local d_start, d_lines, a_start, a_lines = line:match("@@ %-(%d+),(%d+) %+(%d+),?(%d*) @@")
      if a_start ~= nil then
        a_start = tonumber(a_start)
        a_lines = a_lines == "" and 1 or tonumber(a_lines)
        d_start = tonumber(d_start)
        d_lines = tonumber(d_lines)

        for i = a_start, a_start + a_lines - 1 do
          add_lines[i] = true
        end
        if d_lines ~= 0 then
          remove_lines[d_start] = true
        end
      end
    end
  end

  return add_lines, remove_lines
end

local function build_git_lines(lines, add_lines, remove_lines)
  local git_lines = {}
  local minimap_height = math.ceil(#lines / 4)

  for y = 1, minimap_height do
    local a_flag = 0
    local d_flag = 0
    for dy = 1, 4 do
      local line_y = (y - 1) * 4 + dy
      if add_lines[line_y] then
        a_flag = a_flag + FLAGS[dy]
      end
      if remove_lines[line_y] then
        d_flag = d_flag + FLAGS[dy]
      end
    end

    git_lines[y] = utils.flag_to_char(a_flag) .. utils.flag_to_char(d_flag)
  end

  return git_lines
end

function M.get_git_text(lines, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = get_state(bufnr)
  if state.cache then
    return build_git_lines(lines, state.cache.add_lines, state.cache.remove_lines)
  end
  return {}
end

function M.refresh(bufnr, callback)
  local state = get_state(bufnr)

  if state.pending then
    return
  end

  local now = (vim.uv or vim.loop).now()
  if state.last_refresh and (now - state.last_refresh) < MIN_REFRESH_MS then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return
  end

  state.pending = true

  vim.system({ "git", "diff", "-U0", filepath }, { text = true }, function(obj)
    state.pending = nil
    state.last_refresh = (vim.uv or vim.loop).now()

    local add_lines, remove_lines = {}, {}
    if obj.code == 0 and obj.stdout then
      local diff_lines = vim.split(obj.stdout, "\n", { plain = true })
      add_lines, remove_lines = parse_diff_lines(diff_lines)
    end

    local prev = state.cache
    local changed = not prev
      or not set_equal(prev.add_lines, add_lines)
      or not set_equal(prev.remove_lines, remove_lines)

    state.cache = { add_lines = add_lines, remove_lines = remove_lines }

    if changed and callback then
      vim.schedule(function()
        callback()
      end)
    end
  end)
end

function M.clear(bufnr)
  if bufnr then
    buf_state[bufnr] = nil
  end
end

return M
