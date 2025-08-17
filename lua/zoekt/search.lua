local M = {}
local utils = require('zoekt.utils')
local config = require('zoekt.config')

-- Execute a search query
function M.execute_search(query)
  if not utils.executable_exists('zoekt') then
    utils.notify('zoekt is not installed or not in PATH', vim.log.levels.ERROR)
    return
  end

  if not query or query == '' then
    utils.notify('Search query cannot be empty', vim.log.levels.ERROR)
    return
  end

  local index_path = config.get_option('index_path')
  index_path = vim.fn.expand(index_path)

  -- Check if index path exists
  if not vim.fn.isdirectory(index_path) then
    utils.notify(
      'Index path does not exist: ' .. index_path .. '\nRun :ZoektIndex first',
      vim.log.levels.ERROR
    )
    return
  end

  local cmd = 'zoekt'
  local args = { '-index_dir', index_path, query }

  utils.notify('Searching for: ' .. query, vim.log.levels.INFO)

  -- Execute the search command
  utils.execute_async(cmd, args, function(exit_code, stdout, stderr)
    if exit_code == 0 then
      if #stdout == 0 then
        utils.notify('No results found', vim.log.levels.INFO)
        return
      end

      -- Parse results and populate quickfix
      local results = utils.parse_zoekt_output(stdout)
      M.populate_quickfix(results)

      utils.notify('Found ' .. #results .. ' results', vim.log.levels.INFO)
    else
      local error_msg = 'Search failed'
      if #stderr > 0 then
        error_msg = error_msg .. ': ' .. table.concat(stderr, '\n')
      end
      utils.notify(error_msg, vim.log.levels.ERROR)
    end
  end)
end

-- Populate quickfix list with search results
function M.populate_quickfix(results)
  if not results or #results == 0 then
    return
  end

  -- Set quickfix list
  vim.fn.setqflist(results, 'r')

  -- Open quickfix window
  vim.cmd('copen')

  -- Jump to first result
  vim.cmd('cfirst')
end

-- Handle the ZoektSearch command
function M.handle_search_command(args)
  if not args or args == '' then
    utils.notify('Usage: :ZoektSearch query', vim.log.levels.ERROR)
    return
  end

  -- Parse arguments to get the query
  local query = utils.parse_search_args(args)

  if not query or query == '' then
    utils.notify('Search query cannot be empty', vim.log.levels.ERROR)
    return
  end

  M.execute_search(query)
end

return M
