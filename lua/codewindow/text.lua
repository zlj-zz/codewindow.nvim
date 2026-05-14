local M = {}

local utils = require('codewindow.utils')

local function is_whitespace(chr)
  return chr == " " or chr == "\t" or chr == ""
end

function M.compress_text(lines)
  local config = require('codewindow.config').get()
  local minimap_width2 = config.minimap_width * 2
  local width_mult = config.width_multiplier
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
    local current_line = utils.expand_line(lines[line_idx])
    for braille_x0 = 0, minimap_width2 - 1 do
      local any_printable = false
      for dx = 0, width_mult - 1 do
        local buf_col0 = braille_x0 * width_mult + dx
        local chr = current_line:sub(buf_col0 + 1, buf_col0 + 1)
        if not is_whitespace(chr) then
          any_printable = true
          break
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

return M
