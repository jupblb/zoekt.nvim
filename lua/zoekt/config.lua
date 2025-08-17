local M = {}

-- Helper function to get git root directory
local function get_git_root()
  local git_dir = vim.fn.finddir('.git', '.;')
  if git_dir ~= '' then
    return vim.fn.fnamemodify(git_dir, ':h')
  end
  return nil
end

-- Function to determine default index path
local function get_default_index_path()
  -- Priority 1: Environment variable
  if vim.env.ZOEKT_INDEX_PATH then
    return vim.env.ZOEKT_INDEX_PATH
  end

  -- Priority 2: Git project root
  local git_root = get_git_root()
  if git_root then
    return git_root .. '/.zoekt'
  end

  -- Priority 3: Home directory
  return '~/.zoekt'
end

-- Default configuration
local defaults = {
  index_path = get_default_index_path(),
  auto_open_quickfix = true, -- Automatically open quickfix window after search
  use_telescope = true, -- Use telescope.nvim for search results (if available, default: true)
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

  -- Re-calculate defaults in case CWD changed
  defaults.index_path = get_default_index_path()

  M.options = vim.tbl_deep_extend('force', defaults, opts)

  -- Expand the index path
  M.options.index_path = vim.fn.expand(M.options.index_path)

  -- Ensure the index path directory exists
  if M.options.index_path and not vim.fn.isdirectory(M.options.index_path) then
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
