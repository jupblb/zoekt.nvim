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

  return {
    value = result,
    filename = result.filename,
    lnum = result.lnum,
    col = result.col,
    text = result.text,
    display = display,
    ordinal = result.filename .. ':' .. result.lnum .. ':' .. result.text,
  }
end

-- Main zoekt search function (live search)
local function zoekt_search(opts)
  opts = opts or {}
  local index_path = zoekt_config.get_option('index_path')
  index_path = vim.fn.expand(index_path)

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
            '-format',
            'json', -- Request JSON output for easier parsing
            prompt,
          }
        end,
        entry_maker = function(line)
          -- Parse JSON output from zoekt if available
          -- Fallback to text parsing if JSON is not supported
          local ok, json = pcall(vim.json.decode, line)
          if ok and json then
            return make_entry({
              filename = json.file or json.filename,
              lnum = json.line or json.lnum or 1,
              col = json.column or json.col or 1,
              text = json.text or json.match or line,
            })
          else
            -- Fallback to parsing text output
            -- Expected format: filename:line:column:text
            local parts = vim.split(line, ':', { plain = true })
            if #parts >= 3 then
              return make_entry({
                filename = parts[1],
                lnum = tonumber(parts[2]) or 1,
                col = tonumber(parts[3]) or 1,
                text = table.concat(vim.list_slice(parts, 4), ':'),
              })
            end
          end
          return nil
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
