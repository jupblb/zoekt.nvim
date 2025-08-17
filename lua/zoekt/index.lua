local M = {}
local utils = require('zoekt.utils')
local config = require('zoekt.config')

-- Build index for the current directory or git repository
function M.build_index()
  local path = vim.fn.getcwd()
  local index_path = config.get_option('index_path')

  -- Expand paths
  path = vim.fn.expand(path)
  index_path = vim.fn.expand(index_path)

  -- Check if zoekt binaries are available
  local is_git = utils.is_git_repository(path)
  local cmd, args

  if is_git then
    if not utils.executable_exists('zoekt-git-index') then
      utils.notify(
        'zoekt-git-index is not installed or not in PATH',
        vim.log.levels.ERROR
      )
      return
    end

    -- Get git root for indexing
    local git_root = utils.get_git_root(path)
    if not git_root then
      utils.notify('Could not find git repository root', vim.log.levels.ERROR)
      return
    end

    cmd = 'zoekt-git-index'
    args = { '-index', index_path, git_root }
    utils.notify('Indexing git repository: ' .. git_root, vim.log.levels.INFO)
  else
    if not utils.executable_exists('zoekt-index') then
      utils.notify(
        'zoekt-index is not installed or not in PATH',
        vim.log.levels.ERROR
      )
      return
    end

    cmd = 'zoekt-index'
    args = { '-index', index_path, path }
    utils.notify('Indexing directory: ' .. path, vim.log.levels.INFO)
  end

  -- Execute the indexing command
  utils.execute_async(
    cmd,
    args,
    function(exit_code, stdout, stderr)
      if exit_code == 0 then
        utils.notify('Indexing completed successfully', vim.log.levels.INFO)
      else
        local error_msg = 'Indexing failed'
        if #stderr > 0 then
          error_msg = error_msg .. ': ' .. table.concat(stderr, '\n')
        end
        utils.notify(error_msg, vim.log.levels.ERROR)
      end
    end,
    nil,
    function(stderr_data)
      -- Log stderr output in real-time if needed
      for _, line in ipairs(stderr_data) do
        if line ~= '' then
          vim.api.nvim_echo({ { line, 'WarningMsg' } }, false, {})
        end
      end
    end
  )
end

-- Handle the ZoektIndex command
function M.handle_index_command()
  M.build_index()
end

return M
