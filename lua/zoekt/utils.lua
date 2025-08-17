local M = {}

-- Check if a command is executable
function M.executable_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Check if current directory is in a git repository
function M.is_git_repository(path)
  path = path or vim.fn.getcwd()
  local git_dir = vim.fn.finddir('.git', path .. ';')
  return git_dir ~= ''
end

-- Get the root of the git repository
function M.get_git_root(path)
  path = path or vim.fn.getcwd()
  local git_dir = vim.fn.finddir('.git', path .. ';')
  if git_dir == '' then
    return nil
  end

  -- Get the parent directory of .git
  local root = vim.fn.fnamemodify(git_dir, ':h')
  return vim.fn.fnamemodify(root, ':p')
end

-- Parse ZoektSearch arguments (now just returns the query)
function M.parse_search_args(args)
  if not args or args == '' then
    return nil
  end

  -- Entire args is the query
  return args
end

-- Parse zoekt output into quickfix format
function M.parse_zoekt_output(output)
  local results = {}

  for _, line in ipairs(output) do
    -- Expected format: filename:line:column:matched_text
    -- or filename:line:matched_text (without column)
    local filename, lnum, col, text = line:match('^([^:]+):(%d+):(%d+):(.*)$')
    if not filename then
      -- Try without column
      filename, lnum, text = line:match('^([^:]+):(%d+):(.*)$')
      col = 1
    end

    if filename and lnum then
      table.insert(results, {
        filename = filename,
        lnum = tonumber(lnum),
        col = tonumber(col) or 1,
        text = text or '',
        type = '',  -- Empty string for better compatibility (nvim-pqf expects string)
      })
    end
  end

  return results
end

-- Show notification
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify(msg, level, { title = 'zoekt.nvim' })
end

-- Execute a command asynchronously using vim.fn.jobstart
function M.execute_async(cmd, args, on_exit, on_stdout, on_stderr)
  local stdout_data = {}
  local stderr_data = {}

  local job_id = vim.fn.jobstart({ cmd, unpack(args) }, {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(stdout_data, line)
          end
        end
        if on_stdout then
          on_stdout(data)
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(stderr_data, line)
          end
        end
        if on_stderr then
          on_stderr(data)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if on_exit then
        on_exit(exit_code, stdout_data, stderr_data)
      end
    end,
  })

  return job_id
end

return M
