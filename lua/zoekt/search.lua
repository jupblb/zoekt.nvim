local M = {}
local utils = require('zoekt.utils')
local config = require('zoekt.config')

-- Check if telescope is available
local has_telescope = pcall(require, 'telescope')

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

  -- Check if any index files exist (*.zoekt files)
  local index_files = vim.fn.glob(index_path .. '/*.zoekt', false, true)
  if not index_files or #index_files == 0 then
    utils.notify(
      'No index files found in '
        .. index_path
        .. '\nRun :ZoektIndex to generate the index first',
      vim.log.levels.WARN
    )
    -- Continue with the search anyway, but user has been warned
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

  -- Schedule quickfix operations to avoid conflicts with other plugins
  vim.schedule(function()
    -- Ensure all items have required fields for plugin compatibility
    local items = {}
    for _, result in ipairs(results) do
      table.insert(items, {
        filename = result.filename or '',
        lnum = result.lnum or 1,
        col = result.col or 1,
        text = result.text or '',
        type = result.type or '', -- Use empty string instead of nil
        nr = result.nr or 0,
      })
    end

    -- Set quickfix list using simple format first, then add title
    vim.fn.setqflist(items, 'r')
    vim.fn.setqflist({}, 'a', { title = 'Zoekt Search Results' })

    -- Check if we should auto-open the quickfix window
    local auto_open = config.get_option('auto_open_quickfix')
    if auto_open then
      -- Open quickfix window at the bottom spanning full width
      local ok, err = pcall(function()
        vim.cmd('botright copen')
        -- Explicitly focus the quickfix window
        local qf_winnr = vim.fn.getqflist({ winid = 0 }).winid
        if qf_winnr and qf_winnr ~= 0 then
          vim.api.nvim_set_current_win(qf_winnr)
        end
      end)
      if not ok then
        -- If copen fails, still try to notify about results
        utils.notify(
          'Results added to quickfix list. Error opening window: '
            .. tostring(err),
          vim.log.levels.WARN
        )
        return
      end
    else
      -- Just notify that results are available
      utils.notify(
        'Results added to quickfix list. Use :copen to view.',
        vim.log.levels.INFO
      )
    end
  end)
end

-- Handle the ZoektSearch command
function M.handle_search_command(args)
  -- Check if we should use telescope
  local use_telescope = config.get_option('use_telescope')

  -- If telescope is requested but not available, fallback to quickfix
  if use_telescope and not has_telescope then
    utils.notify(
      'Telescope not available, falling back to quickfix',
      vim.log.levels.WARN
    )
    use_telescope = false
  end

  if use_telescope then
    -- Use telescope for live search (always live search now)
    require('telescope').extensions.zoekt.zoekt()
  else
    -- Use traditional quickfix
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
end

return M
