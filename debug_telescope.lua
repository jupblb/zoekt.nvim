-- Debug telescope zoekt
local cmd = { 'zoekt', '-index_dir', vim.fn.expand('~/.zoekt'), 'f:lua' }
local result = vim.fn.systemlist(cmd)

print('Command: ' .. vim.inspect(cmd))
print('Results count: ' .. #result)
for i, line in ipairs(result) do
  print(i .. ': ' .. line)
end

-- Now test the parser
local function parse_line(line)
  if not line or line == '' then
    return nil
  end

  local colon1 = line:find(':')
  if not colon1 then
    return nil
  end

  local filename = line:sub(1, colon1 - 1)
  local rest = line:sub(colon1 + 1)

  local colon2 = rest:find(':')
  if not colon2 then
    return nil
  end

  local lnum_str = rest:sub(1, colon2 - 1)
  local lnum = tonumber(lnum_str)
  if lnum == nil then
    return nil
  end

  local text = rest:sub(colon2 + 1)

  return {
    filename = filename,
    lnum = lnum,
    text = text,
  }
end

print('\nParsed results:')
for i, line in ipairs(result) do
  local parsed = parse_line(line)
  if parsed then
    print(i .. ': ' .. vim.inspect(parsed))
  end
end
