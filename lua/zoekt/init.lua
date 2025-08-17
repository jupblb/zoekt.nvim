local M = {}

-- Setup function to initialize the plugin
function M.setup(opts)
  -- Setup configuration
  local config = require('zoekt.config')
  config.setup(opts)

  -- Register user commands
  local index = require('zoekt.index')
  local search = require('zoekt.search')
  local hook = require('zoekt.hook')

  -- ZoektIndex command
  vim.api.nvim_create_user_command('ZoektIndex', function()
    index.handle_index_command()
  end, {
    desc = 'Index the current directory or git repository with Zoekt',
  })

  -- ZoektSearch command
  vim.api.nvim_create_user_command('ZoektSearch', function(cmd_opts)
    search.handle_search_command(cmd_opts.args)
  end, {
    nargs = '*', -- Changed from '+' to '*' to allow no args when using telescope
    desc = 'Search indexed code with Zoekt',
  })

  -- ZoektHook command
  vim.api.nvim_create_user_command('ZoektHook', function()
    hook.install_hook()
  end, {
    desc = 'Install a git post-commit hook to automatically index with Zoekt',
  })

  -- Register telescope extension if telescope is available
  local has_telescope = pcall(require, 'telescope')
  if has_telescope then
    -- Load the telescope extension
    pcall(function()
      require('telescope').load_extension('zoekt')
    end)

    -- Telescope-specific command (live search only)
    vim.api.nvim_create_user_command('ZoektTelescope', function()
      require('telescope').extensions.zoekt.zoekt()
    end, {
      desc = 'Live search with Zoekt using Telescope',
    })
  end
end

return M
