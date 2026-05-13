local M = {}

local utils = require 'codewindow.utils'

local diagnostic = vim.diagnostic
local CELL_HEIGHT = 4
local FLAGS = { 1, 2, 4, 8 }

function M.get_lsp_errors(buffer, line_count)
  local error_lines = {}
  for _ = 1, line_count do
    table.insert(error_lines, { warn = false, err = false })
  end

  local errors = diagnostic.get(buffer, { severity = { min = diagnostic.severity.WARN } })
  for _, v in ipairs(errors) do
    local line_idx = v.lnum + 1
    if line_idx <= line_count then
      if v.severity == diagnostic.severity.WARN then
        error_lines[line_idx].warn = true
      else
        error_lines[line_idx].err = true
      end
    end
  end

  local error_text = {}
  for block_start_idx = 1, line_count + CELL_HEIGHT - 1, CELL_HEIGHT do
    local err_flag = 0
    local warn_flag = 0

    for row_offset = 0, CELL_HEIGHT - 1 do
      local line_idx = block_start_idx + row_offset
      if error_lines[line_idx] then
        if error_lines[line_idx].err then
          err_flag = err_flag + FLAGS[row_offset + 1]
        end
        if error_lines[line_idx].warn then
          warn_flag = warn_flag + FLAGS[row_offset + 1]
        end
      end
    end

    local err_char = utils.flag_to_char(err_flag)
    local warn_char = utils.flag_to_char(warn_flag)

    table.insert(error_text, err_char .. warn_char)
  end

  return error_text
end

return M
