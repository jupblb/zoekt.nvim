local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('telescope.nvim is not installed')
end

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local entry_display = require('telescope.pickers.entry_display')
local utils = require('telescope.utils')

local zoekt_config = require('zoekt.config')
local zoekt_utils = require('zoekt.utils')

local M = {}

-- Entry maker for zoekt results
local function make_entry(result)
  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 40 }, -- filename
      { width = 5 }, -- line number
      { remaining = true }, -- text
    },
  })

  local display = function(entry)
    return displayer({
      { entry.filename, 'TelescopeResultsIdentifier' },
      { tostring(entry.lnum), 'TelescopeResultsNumber' },
      { entry.text, 'TelescopeResultsComment' },
    })
  end

  -- Use original line for ordinal if available to ensure uniqueness
  local ordinal = result._original_line
    or (result.filename .. ':' .. tostring(result.lnum) .. ':' .. result.text)

  return {
    value = result,
    filename = result.filename,
    lnum = result.lnum,
    col = result.col,
    text = result.text,
    display = display,
    ordinal = ordinal,
  }
end

-- Main zoekt search function (live search)
local function zoekt_search(opts)
  opts = opts or {}
  local index_path = zoekt_config.get_option('index_path')
  index_path = vim.fn.expand(index_path)

  -- Counter for file results to ensure uniqueness
  local file_result_counter = 0

  -- Check if index path exists
  if not vim.fn.isdirectory(index_path) then
    zoekt_utils.notify(
      'Index path does not exist: ' .. index_path .. '\nRun :ZoektIndex first',
      vim.log.levels.ERROR
    )
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'Zoekt Search',
      finder = finders.new_async_job({
        command_generator = function(prompt)
          if not prompt or prompt == '' then
            return nil
          end

          return {
            'zoekt',
            '-index_dir',
            index_path,
            prompt,
          }
        end,
        entry_maker = function(line)
          -- Skip empty lines
          if not line or line == '' then
            return nil
          end

          -- Parse zoekt output format: filename:line:text
          local colon1 = line:find(':')
          if not colon1 then
            return nil
          end

          local filename = line:sub(1, colon1 - 1)
          local rest = line:sub(colon1 + 1)

          local colon2 = rest:find(':')
          if not colon2 then
            return nil
          end

          local lnum_str = rest:sub(1, colon2 - 1)
          local lnum = tonumber(lnum_str)
          if lnum == nil then
            return nil
          end

          local text = rest:sub(colon2 + 1)

          -- For file searches (lnum == 0), use a unique counter
          if lnum == 0 then
            -- Use a unique counter to prevent telescope from deduplicating
            file_result_counter = file_result_counter + 1
            lnum = file_result_counter
            -- text already contains the filename from zoekt
          end

          -- Try to determine column by finding first non-whitespace
          local col = 1
          if text and text ~= '' and lnum > 1 then
            local _, col_end = string.find(text, '^%s*')
            col = (col_end or 0) + 1
          end

          -- Create result with the original line as part of ordinal for uniqueness
          local result = {
            filename = filename,
            lnum = lnum,
            col = col,
            text = text or '',
            _original_line = line, -- Store original line for unique ordinal
          }

          return make_entry(result)
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.file_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            -- Open the file at the specified location
            vim.cmd('edit ' .. selection.filename)
            vim.api.nvim_win_set_cursor(
              0,
              { selection.lnum, selection.col - 1 }
            )
          end
        end)

        -- Add quickfix list population on <C-q>
        map('i', '<C-q>', function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local multi_selections = picker:get_multi_selection()

          if #multi_selections > 0 then
            actions.send_selected_to_qflist(prompt_bufnr)
          else
            actions.send_to_qflist(prompt_bufnr)
          end
          actions.open_qflist(prompt_bufnr)
        end)

        return true
      end,
    })
    :find()
end

-- Main extension setup
return telescope.register_extension({
  setup = function(ext_config, config)
    -- Extension config can be used here
  end,
  exports = {
    zoekt = zoekt_search, -- Main entry point for live search
  },
})
