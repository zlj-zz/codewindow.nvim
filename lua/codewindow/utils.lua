local M = {}

local get_line = vim.fn.line
local exe = vim.cmd.execute
local api = vim.api

function M.buf_to_minimap(col0, row0)
  local config = require('codewindow.config').get()
  local minimap_x_idx = math.floor(col0 / config.width_multiplier / 2) + 1
  local minimap_y_idx = math.floor(row0 / 4) + 1
  return minimap_x_idx, minimap_y_idx
end

local braille_chars = "⠀⠁⠂⠃⠄⠅⠆⠇⡀⡁⡂⡃⡄⡅⡆⡇⠈⠉⠊⠋⠌⠍⠎⠏⡈⡉⡊⡋⡌⡍⡎⡏"
    ..
    "⠐⠑⠒⠓⠔⠕⠖⠗⡐⡑⡒⡓⡔⡕⡖⡗⠘⠙⠚⠛⠜⠝⠞⠟⡘⡙⡚⡛⡜⡝⡞⡟" ..
    "⠠⠡⠢⠣⠤⠥⠦⠧⡠⡡⡢⡣⡤⡥⡦⡧⠨⠩⠪⠫⠬⠭⠮⠯⡨⡩⡪⡫⡬⡭⡮⡯" ..
    "⠰⠱⠲⠳⠴⠵⠶⠷⡰⡱⡲⡳⡴⡵⡶⡷⠸⠹⠺⠻⠼⠽⠾⠿⡸⡹⡺⡻⡼⡽⡾⡿" ..
    "⢀⢁⢂⢃⢄⢅⢆⢇⣀⣁⣂⣃⣄⣅⣆⣇⢈⢉⢊⢋⢌⢍⢎⢏⣈⣉⣊⣋⣌⣍⣎⣏" ..
    "⢐⢑⢒⢓⢔⢕⢖⢗⣐⣑⣒⣓⣔⣕⣖⣗⢘⢙⢚⢛⢜⢝⢞⢟⣘⣙⣚⣛⣜⣝⣞⣟" ..
    "⢠⢡⢢⢣⢤⢥⢦⢧⣠⣡⣢⣣⣤⣥⣦⣧⢨⢩⢪⢫⢬⢭⢮⢯⣨⣩⣪⣫⣬⣭⣮⣯" ..
    "⢰⢱⢲⢳⢴⢵⢶⢷⣰⣱⣲⣳⣴⣵⣶⣷⢸⢹⢺⢻⢼⢽⢾⢿⣸⣹⣺⣻⣼⣽⣾⣿"

function M.coord_to_flag(x0, y0)
  return math.pow(2, y0 % 4) * ((x0 % 2 == 0) and 1 or 16)
end

function M.flag_to_char(flag)
  return braille_chars:sub(flag * 3 + 1, (flag + 1) * 3)
end

function M.get_top_line(window)
  if window then
    return get_line('w0', window)
  end
  return get_line('w0')
end

function M.get_bot_line(window)
  if window then
    return get_line('w$', window)
  end
  return get_line('w$')
end

function M.get_buf_height(buffer)
  return api.nvim_buf_line_count(buffer)
end

function M.scroll_window(window, amount)
  if not api.nvim_win_is_valid(window) then
    return
  end

  api.nvim_win_call(window, function()
    if amount > 0 then
      local botline = M.get_bot_line()
      local buffer = api.nvim_win_get_buf(window)
      local height = M.get_buf_height(buffer)
      if botline >= height then
        return
      end
      local max_move_down = math.min(amount, height - botline)
      exe(string.format("\"normal! %d\\<C-e>\"", max_move_down))
    else
      amount = -amount
      if window == nil then
        return
      end
      local topline = M.get_top_line()
      if topline <= 1 then
        return
      end
      local max_move_up = math.min(amount, topline - 1)
      exe(string.format("\"normal! %d\\<C-y>\"", max_move_up))
    end
  end)
end

return M
