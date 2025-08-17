describe('zoekt.nvim', function()
  local zoekt
  local config
  local utils
  local index
  local search

  before_each(function()
    -- Clear any previous module state
    package.loaded['zoekt'] = nil
    package.loaded['zoekt.config'] = nil
    package.loaded['zoekt.utils'] = nil
    package.loaded['zoekt.index'] = nil
    package.loaded['zoekt.search'] = nil

    -- Reload modules
    zoekt = require('zoekt')
    config = require('zoekt.config')
    utils = require('zoekt.utils')
    index = require('zoekt.index')
    search = require('zoekt.search')

    -- Clear quickfix list
    vim.fn.setqflist({}, 'r')
  end)

  describe('setup', function()
    it('should use default configuration', function()
      zoekt.setup()
      local opts = config.get()
      assert.are.equal(
        '~/.zoekt',
        opts.index_path:match('%.zoekt$') and '~/.zoekt' or opts.index_path
      )
    end)

    it('should respect custom configuration', function()
      zoekt.setup({ index_path = '/custom/path' })
      local opts = config.get()
      assert.are.equal('/custom/path', opts.index_path)
    end)

    it('should respect ZOEKT_INDEX_PATH environment variable', function()
      vim.env.ZOEKT_INDEX_PATH = '/env/path'
      package.loaded['zoekt.config'] = nil
      config = require('zoekt.config')
      config.setup()
      local opts = config.get()
      assert.are.equal('/env/path', opts.index_path)
      vim.env.ZOEKT_INDEX_PATH = nil
    end)

    it('should register user commands', function()
      zoekt.setup()
      assert.is_not_nil(vim.api.nvim_get_commands({})['ZoektIndex'])
      assert.is_not_nil(vim.api.nvim_get_commands({})['ZoektSearch'])
    end)
  end)

  describe('utils', function()
    describe('parse_search_args', function()
      it('should return the query', function()
        local query = utils.parse_search_args('search query')
        assert.are.equal('search query', query)
      end)

      it('should handle empty args', function()
        local query = utils.parse_search_args('')
        assert.is_nil(query)
      end)

      it('should handle complex queries', function()
        local query = utils.parse_search_args('function handleAuth TODO')
        assert.are.equal('function handleAuth TODO', query)
      end)
    end)

    describe('parse_zoekt_output', function()
      it('should parse standard output format', function()
        local output = {
          'file.lua:10:5:function test()',
          'another.lua:20:matched text',
        }
        local results = utils.parse_zoekt_output(output)

        assert.are.equal(2, #results)
        assert.are.equal('file.lua', results[1].filename)
        assert.are.equal(10, results[1].lnum)
        assert.are.equal(5, results[1].col)
        assert.are.equal('function test()', results[1].text)

        assert.are.equal('another.lua', results[2].filename)
        assert.are.equal(20, results[2].lnum)
        assert.are.equal(1, results[2].col)
        assert.are.equal('matched text', results[2].text)
      end)

      it('should handle empty output', function()
        local results = utils.parse_zoekt_output({})
        assert.are.equal(0, #results)
      end)
    end)

    describe('is_git_repository', function()
      it('should detect git repository', function()
        -- Mock vim.fn.finddir
        local original_finddir = vim.fn.finddir
        vim.fn.finddir = function(dir, path)
          if dir == '.git' then
            return '/path/to/repo/.git'
          end
          return ''
        end

        assert.is_true(utils.is_git_repository('/path/to/repo'))

        vim.fn.finddir = original_finddir
      end)

      it('should detect non-git directory', function()
        -- Mock vim.fn.finddir
        local original_finddir = vim.fn.finddir
        vim.fn.finddir = function(dir, path)
          return ''
        end

        assert.is_false(utils.is_git_repository('/path/to/dir'))

        vim.fn.finddir = original_finddir
      end)
    end)

    describe('get_git_root', function()
      it('should return git root directory', function()
        -- Mock vim.fn.finddir and vim.fn.fnamemodify
        local original_finddir = vim.fn.finddir
        local original_fnamemodify = vim.fn.fnamemodify

        vim.fn.finddir = function(dir, path)
          if dir == '.git' then
            return '/path/to/repo/.git'
          end
          return ''
        end

        vim.fn.fnamemodify = function(path, mods)
          if mods == ':h' then
            return '/path/to/repo'
          elseif mods == ':p' then
            return path .. '/'
          end
          return path
        end

        local root = utils.get_git_root('/path/to/repo/subdir')
        assert.are.equal('/path/to/repo/', root)

        vim.fn.finddir = original_finddir
        vim.fn.fnamemodify = original_fnamemodify
      end)

      it('should return nil for non-git directory', function()
        -- Mock vim.fn.finddir
        local original_finddir = vim.fn.finddir
        vim.fn.finddir = function(dir, path)
          return ''
        end

        local root = utils.get_git_root('/path/to/dir')
        assert.is_nil(root)

        vim.fn.finddir = original_finddir
      end)
    end)
  end)

  describe('ZoektIndex', function()
    it('should handle index command without arguments', function()
      -- Test that handle_index_command calls build_index
      local build_index_called = false
      local original_build = index.build_index

      index.build_index = function()
        build_index_called = true
      end

      -- Call the function
      index.handle_index_command()

      -- Check that build_index was called
      assert.is_true(build_index_called)

      -- Restore original functions
      index.build_index = original_build
    end)

    it('should check for zoekt-git-index binary for git repos', function()
      -- Mock functions
      local original_executable = utils.executable_exists
      local original_is_git = utils.is_git_repository
      local notified = false
      local original_notify = utils.notify

      utils.executable_exists = function(cmd)
        return false
      end

      utils.is_git_repository = function(path)
        return true
      end

      utils.notify = function(msg, level)
        if level == vim.log.levels.ERROR and msg:match('zoekt%-git%-index') then
          notified = true
        end
      end

      index.build_index()
      assert.is_true(notified)

      utils.executable_exists = original_executable
      utils.is_git_repository = original_is_git
      utils.notify = original_notify
    end)

    it('should check for zoekt-index binary for non-git directories', function()
      -- Mock functions
      local original_executable = utils.executable_exists
      local original_is_git = utils.is_git_repository
      local notified = false
      local original_notify = utils.notify

      utils.executable_exists = function(cmd)
        return false
      end

      utils.is_git_repository = function(path)
        return false
      end

      utils.notify = function(msg, level)
        if level == vim.log.levels.ERROR and msg:match('zoekt%-index') then
          notified = true
        end
      end

      index.build_index()
      assert.is_true(notified)

      utils.executable_exists = original_executable
      utils.is_git_repository = original_is_git
      utils.notify = original_notify
    end)
  end)

  describe('ZoektSearch', function()
    it('should require search query', function()
      local notified = false
      local original_notify = utils.notify

      utils.notify = function(msg, level)
        if level == vim.log.levels.ERROR and msg:match('Usage:') then
          notified = true
        end
      end

      search.handle_search_command('')
      assert.is_true(notified)

      utils.notify = original_notify
    end)

    it('should check for zoekt binary', function()
      local original_executable = utils.executable_exists
      local notified = false
      local original_notify = utils.notify

      utils.executable_exists = function(cmd)
        return false
      end

      utils.notify = function(msg, level)
        if
          level == vim.log.levels.ERROR and msg:match('zoekt is not installed')
        then
          notified = true
        end
      end

      search.execute_search(nil, 'test query')
      assert.is_true(notified)

      utils.executable_exists = original_executable
      utils.notify = original_notify
    end)

    it('should parse and format search results correctly', function()
      -- Test the parse_zoekt_output function
      local output = {
        'file1.lua:10:5:matched line 1',
        'file2.lua:20:matched line 2',
        'test.vim:35:15:another match',
      }

      local results = utils.parse_zoekt_output(output)

      -- Check parsed results
      assert.are.equal(3, #results)

      -- Check first result
      assert.are.equal('file1.lua', results[1].filename)
      assert.are.equal(10, results[1].lnum)
      assert.are.equal(5, results[1].col)
      assert.are.equal('matched line 1', results[1].text)

      -- Check second result
      assert.are.equal('file2.lua', results[2].filename)
      assert.are.equal(20, results[2].lnum)
      assert.are.equal(1, results[2].col) -- Default column when not specified
      assert.are.equal('matched line 2', results[2].text)

      -- Check third result
      assert.are.equal('test.vim', results[3].filename)
      assert.are.equal(35, results[3].lnum)
      assert.are.equal(15, results[3].col)
      assert.are.equal('another match', results[3].text)
    end)

    it('should handle empty search results', function()
      local original_executable = utils.executable_exists
      local original_isdirectory = vim.fn.isdirectory
      local original_execute = utils.execute_async
      local original_expand = vim.fn.expand
      local notified = false
      local original_notify = utils.notify

      utils.executable_exists = function(cmd)
        return true
      end

      vim.fn.isdirectory = function(path)
        return 1
      end

      vim.fn.expand = function(path)
        return path
      end

      utils.execute_async = function(cmd, args, on_exit)
        -- Simulate search with no results
        on_exit(0, {}, {})
      end

      utils.notify = function(msg, level)
        if msg:match('No results found') then
          notified = true
        end
      end

      search.execute_search('test query')
      assert.is_true(notified)

      utils.executable_exists = original_executable
      vim.fn.isdirectory = original_isdirectory
      utils.execute_async = original_execute
      vim.fn.expand = original_expand
      utils.notify = original_notify
    end)
  end)
end)
