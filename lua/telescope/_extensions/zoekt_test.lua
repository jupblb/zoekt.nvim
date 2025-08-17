local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('telescope.nvim is not installed')
end

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local entry_display = require('telescope.pickers.entry_display')

local zoekt_config = require('zoekt.config')

-- Entry maker for zoekt results
local function make_entry(result)
  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 40 }, -- filename
      { width = 5 }, -- line number
      { remaining = true }, -- text
    },
  })

  local display = function(entry)
    return displayer({
      { entry.filename, 'TelescopeResultsIdentifier' },
      { tostring(entry.lnum), 'TelescopeResultsNumber' },
      { entry.text, 'TelescopeResultsComment' },
    })
  end

  return {
    value = result,
    filename = result.filename,
    lnum = result.lnum or 1,
    col = result.col or 1,
    text = result.text or '',
    display = display,
    ordinal = result.filename
      .. ':'
      .. tostring(result.lnum or 1)
      .. ':'
      .. (result.text or ''),
  }
end

-- Test with synchronous execution
local function test_sync(opts)
  opts = opts or {}
  local index_path = zoekt_config.get_option('index_path')
  index_path = vim.fn.expand(index_path)

  -- Execute command synchronously for testing
  local cmd = { 'zoekt', '-index_dir', index_path, 'f:lua' }
  local results = vim.fn.systemlist(cmd)

  vim.notify('Got ' .. #results .. ' results from zoekt', vim.log.levels.INFO)

  local entries = {}
  for _, line in ipairs(results) do
    if line and line ~= '' then
      -- Parse zoekt output format: filename:line:text
      local colon1 = line:find(':')
      if colon1 then
        local filename = line:sub(1, colon1 - 1)
        local rest = line:sub(colon1 + 1)

        local colon2 = rest:find(':')
        if colon2 then
          local lnum = tonumber(rest:sub(1, colon2 - 1)) or 1
          local text = rest:sub(colon2 + 1)

          if lnum == 0 then
            lnum = 1
          end

          table.insert(entries, {
            filename = filename,
            lnum = lnum,
            col = 1,
            text = text,
          })
        end
      end
    end
  end

  vim.notify('Created ' .. #entries .. ' entries', vim.log.levels.INFO)

  pickers
    .new(opts, {
      prompt_title = 'Zoekt Test (Sync)',
      finder = finders.new_table({
        results = entries,
        entry_maker = make_entry,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.file_previewer(opts),
    })
    :find()
end

return {
  test_sync = test_sync,
}
