local M = {}

-- Default configuration
local defaults = {
  index_path = vim.env.ZOEKT_INDEX_PATH or '~/.zoekt',
  auto_open_quickfix = true, -- Automatically open quickfix window after search
  use_telescope = true, -- Use telescope.nvim for search results (if available, default: true)
  telescope = {
    live_search = true, -- Enable live search mode in telescope (default: true)
  },
  -- Future options:
  -- auto_index = false,
  -- search_options = {},
  -- keymaps = {},
}

-- Current configuration
M.options = {}

-- Merge user configuration with defaults
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', defaults, opts)

  -- Expand the index path
  M.options.index_path = vim.fn.expand(M.options.index_path)

  -- Ensure the index path is absolute
  if not vim.fn.isdirectory(M.options.index_path) then
    -- Create the directory if it doesn't exist
    vim.fn.mkdir(M.options.index_path, 'p')
  end

  return M.options
end

-- Get current configuration
function M.get()
  if vim.tbl_isempty(M.options) then
    M.setup()
  end
  return M.options
end

-- Get a specific configuration value
function M.get_option(key)
  return M.get()[key]
end

return M
