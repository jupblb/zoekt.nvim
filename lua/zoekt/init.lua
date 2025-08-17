local M = {}

-- Setup function to initialize the plugin
function M.setup(opts)
  -- Setup configuration
  local config = require('zoekt.config')
  config.setup(opts)

  -- Register user commands
  local index = require('zoekt.index')
  local search = require('zoekt.search')

  -- ZoektIndex command
  vim.api.nvim_create_user_command('ZoektIndex', function(cmd_opts)
    index.handle_index_command(cmd_opts.args)
  end, {
    nargs = '?',
    complete = 'dir',
    desc = 'Index a directory or git repository with Zoekt',
  })

  -- ZoektSearch command
  vim.api.nvim_create_user_command('ZoektSearch', function(cmd_opts)
    search.handle_search_command(cmd_opts.args)
  end, {
    nargs = '+',
    desc = 'Search indexed code with Zoekt',
  })
end

return M
