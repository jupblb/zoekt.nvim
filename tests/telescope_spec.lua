describe('zoekt.nvim telescope integration', function()
  before_each(function()
    -- Reset configuration
    package.loaded['zoekt.config'] = nil
    package.loaded['zoekt.search'] = nil
    package.loaded['zoekt.init'] = nil

    -- Mock environment
    vim.env.ZOEKT_INDEX_PATH = nil

    -- Create mock index directory
    vim.fn.mkdir('/tmp/test_zoekt_index', 'p')
  end)

  after_each(function()
    -- Clean up
    vim.fn.delete('/tmp/test_zoekt_index', 'rf')
  end)

  describe('telescope configuration', function()
    it('should default to using telescope', function()
      local config = require('zoekt.config')
      config.setup()

      assert.equals(true, config.get_option('use_telescope'))
    end)

    it('should allow disabling telescope', function()
      local config = require('zoekt.config')
      config.setup({
        use_telescope = false,
      })

      assert.equals(false, config.get_option('use_telescope'))
    end)
  end)

  describe('search command with telescope', function()
    it('should fallback to quickfix when telescope is not available', function()
      -- Mock telescope as not available
      package.loaded['telescope'] = nil

      local config = require('zoekt.config')
      local search = require('zoekt.search')

      config.setup({
        use_telescope = true,
        index_path = '/tmp/test_zoekt_index',
      })

      -- Mock the execute_search function to track if it was called
      local execute_called = false
      local original_execute = search.execute_search
      search.execute_search = function(query)
        execute_called = true
        assert.equals('test query', query)
      end

      -- Mock notify to capture warning
      local notify_called = false
      local utils = require('zoekt.utils')
      local original_notify = utils.notify
      utils.notify = function(msg, level)
        if msg:match('Telescope not available') then
          notify_called = true
          assert.equals(vim.log.levels.WARN, level)
        end
      end

      -- Call the search command
      search.handle_search_command('test query')

      -- Verify fallback behavior
      assert.is_true(notify_called, 'Should warn about telescope not available')
      assert.is_true(execute_called, 'Should fallback to execute_search')

      -- Restore
      search.execute_search = original_execute
      utils.notify = original_notify
    end)

    it('should use quickfix when telescope is disabled', function()
      local config = require('zoekt.config')
      local search = require('zoekt.search')

      config.setup({
        use_telescope = false,
        index_path = '/tmp/test_zoekt_index',
      })

      -- Mock the execute_search function
      local execute_called = false
      local original_execute = search.execute_search
      search.execute_search = function(query)
        execute_called = true
        assert.equals('test query', query)
      end

      -- Call the search command
      search.handle_search_command('test query')

      -- Verify quickfix was used
      assert.is_true(execute_called, 'Should use execute_search for quickfix')

      -- Restore
      search.execute_search = original_execute
    end)

    it('should error when no query provided for quickfix', function()
      local config = require('zoekt.config')
      local search = require('zoekt.search')
      local utils = require('zoekt.utils')

      config.setup({
        use_telescope = false,
        index_path = '/tmp/test_zoekt_index',
      })

      -- Mock notify to capture error
      local error_msg = nil
      local original_notify = utils.notify
      utils.notify = function(msg, level)
        if level == vim.log.levels.ERROR then
          error_msg = msg
        end
      end

      -- Call without arguments
      search.handle_search_command('')

      -- Verify error
      assert.is_not_nil(error_msg)
      assert.truthy(error_msg:match('Usage: :ZoektSearch query'))

      -- Restore
      utils.notify = original_notify
    end)
  end)

  describe('telescope extension', function()
    it('should register telescope extension when available', function()
      -- Mock telescope
      local extension_registered = false
      local extension_loaded = false

      package.loaded['telescope'] = {
        register_extension = function(ext)
          extension_registered = true
          assert.is_not_nil(ext.exports)
          assert.is_function(ext.exports.zoekt)
          return true
        end,
        load_extension = function(name)
          if name == 'zoekt' then
            extension_loaded = true
          end
        end,
        extensions = {
          zoekt = {
            zoekt = function() end,
          },
        },
      }

      -- Initialize zoekt with telescope support
      local zoekt = require('zoekt')
      zoekt.setup({
        use_telescope = true,
      })

      -- Verify extension was registered
      assert.is_true(extension_loaded, 'Telescope extension should be loaded')
    end)
  end)

  describe('telescope commands', function()
    it(
      'should create telescope-specific commands when telescope is available',
      function()
        -- Mock telescope
        package.loaded['telescope'] = {
          load_extension = function() end,
          extensions = {
            zoekt = {
              zoekt = function() end,
            },
          },
        }

        -- Initialize zoekt
        local zoekt = require('zoekt')
        zoekt.setup()

        -- Check if commands exist
        local commands = vim.api.nvim_get_commands({})
        assert.is_not_nil(commands.ZoektTelescope)

        -- Verify command description
        assert.equals(
          'Live search with Zoekt using Telescope',
          commands.ZoektTelescope.definition
        )
      end
    )
  end)
end)
