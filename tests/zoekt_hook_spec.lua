local mock = require('luassert.mock')

describe('zoekt.hook', function()
  local hook
  local config
  local original_cwd

  before_each(function()
    -- Store original CWD
    original_cwd = vim.fn.getcwd()

    -- Clear module cache
    package.loaded['zoekt.hook'] = nil
    package.loaded['zoekt.config'] = nil

    -- Load modules
    config = require('zoekt.config')
    config.setup({ index_path = '/tmp/test-index' })
    hook = require('zoekt.hook')
  end)

  after_each(function()
    -- Restore original CWD
    vim.cmd('cd ' .. original_cwd)
  end)

  describe('install_hook', function()
    it('should detect when not in a git repository', function()
      -- Create a temporary directory without git
      local temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, 'p')
      vim.cmd('cd ' .. temp_dir)

      -- Mock vim.notify to capture messages
      local notify_called = false
      local notify_msg = ''
      vim.notify = function(msg, level)
        notify_called = true
        notify_msg = msg
      end

      local result = hook.install_hook()

      assert.is_false(result)
      assert.is_true(notify_called)
      assert.equals('Not in a git repository', notify_msg)

      -- Cleanup
      vim.fn.delete(temp_dir, 'rf')
    end)

    it('should create post-commit hook in git repository', function()
      -- Create a temporary git repository
      local temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, 'p')
      vim.cmd('cd ' .. temp_dir)

      -- Initialize git repo
      vim.fn.system('git init')

      -- Mock vim.notify to capture success message
      local notify_called = false
      local notify_msg = ''
      vim.notify = function(msg, level)
        notify_called = true
        notify_msg = msg
      end

      local result = hook.install_hook()

      assert.is_true(result)
      assert.is_true(notify_called)
      assert.truthy(
        notify_msg:match('Post%-commit hook installed successfully')
      )

      -- Verify hook file exists
      local hook_path = temp_dir .. '/.git/hooks/post-commit'
      assert.equals(1, vim.fn.filereadable(hook_path))

      -- Verify hook content
      local hook_content = vim.fn.readfile(hook_path)
      assert.truthy(table.concat(hook_content, '\n'):match('zoekt%-index'))
      assert.truthy(table.concat(hook_content, '\n'):match('/tmp/test%-index'))

      -- Verify hook is executable
      local file_info = vim.fn.system('ls -l ' .. vim.fn.shellescape(hook_path))
      assert.truthy(file_info and file_info:match('rwx'))

      -- Cleanup
      vim.fn.delete(temp_dir, 'rf')
    end)

    it('should overwrite existing hook without prompting', function()
      -- Create a temporary git repository
      local temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, 'p')
      vim.cmd('cd ' .. temp_dir)

      -- Initialize git repo
      vim.fn.system('git init')

      -- Create an existing hook
      local hook_path = temp_dir .. '/.git/hooks/post-commit'
      vim.fn.writefile({ '#!/bin/sh', 'echo "existing hook"' }, hook_path)

      -- Mock vim.notify
      local notify_msg = ''
      vim.notify = function(msg, level)
        notify_msg = msg
      end

      local result = hook.install_hook()

      assert.is_true(result)
      assert.truthy(
        notify_msg:match('Post%-commit hook installed successfully')
      )

      -- Verify hook was overwritten
      local hook_content = vim.fn.readfile(hook_path)
      assert.truthy(table.concat(hook_content, '\n'):match('zoekt%-index'))
      assert.falsy(table.concat(hook_content, '\n'):match('existing hook'))

      -- Cleanup
      vim.fn.delete(temp_dir, 'rf')
    end)
  end)
end)
