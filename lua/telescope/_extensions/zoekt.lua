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

-- Create a custom previewer that highlights the matched line
local function create_zoekt_previewer(opts)
  return previewers.new_buffer_previewer({
    title = 'Zoekt Preview',

    get_buffer_by_name = function(_, entry)
      return entry.filename
    end,

    define_preview = function(self, entry, status)
      if not entry or not entry.filename then
        return
      end

      -- Check if file exists
      local filepath = vim.fn.expand(entry.filename)
      if not vim.fn.filereadable(filepath) then
        vim.api.nvim_buf_set_lines(
          self.state.bufnr,
          0,
          -1,
          false,
          { 'File not found: ' .. filepath }
        )
        return
      end

      -- Load file contents
      conf.buffer_previewer_maker(filepath, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        preview = {
          highlight_line = true,
        },
        callback = function(bufnr)
          -- Set the filetype for syntax highlighting
          local ft = vim.filetype.match({ filename = filepath })
          if ft then
            vim.api.nvim_buf_set_option(bufnr, 'filetype', ft)
          end

          -- Schedule highlight after buffer is loaded and displayed
          vim.schedule(function()
            -- Clear any existing highlights
            vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

            -- Highlight the matched line if we have a line number
            local lnum = entry.actual_lnum or entry.lnum
            if lnum and lnum > 0 then
              -- Create a namespace for our highlights
              local ns = vim.api.nvim_create_namespace('zoekt_preview')

              -- Add highlight to the entire line
              vim.api.nvim_buf_add_highlight(
                bufnr,
                ns,
                'TelescopePreviewLine',
                lnum - 1,
                0,
                -1
              )

              -- Try to center the view on the matched line
              pcall(function()
                vim.api.nvim_win_set_cursor(self.state.winid, { lnum, 0 })
                vim.api.nvim_win_call(self.state.winid, function()
                  vim.cmd('normal! zz')
                end)
              end)
            end
          end)
        end,
      })
    end,
  })
end

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
    -- For file searches, show just the filename
    if entry.is_file_search then
      return displayer({
        { entry.filename, 'TelescopeResultsIdentifier' },
        { '', 'TelescopeResultsNumber' },
        { '', 'TelescopeResultsComment' },
      })
    else
      return displayer({
        { entry.filename, 'TelescopeResultsIdentifier' },
        { tostring(entry.lnum), 'TelescopeResultsNumber' },
        { entry.text, 'TelescopeResultsComment' },
      })
    end
  end

  -- Make ordinal unique by including index for file searches
  local ordinal = string.format(
    '%s:%d:%s:%d',
    result.filename,
    result.lnum or 0,
    result.text or '',
    result._idx or 0
  )

  -- For file searches, use index as line number to prevent telescope deduplication
  local display_lnum = result.lnum
  if result.is_file_search and result._idx then
    display_lnum = result._idx
  end

  return {
    value = result,
    filename = result.filename,
    lnum = display_lnum or 1,
    col = result.col or 1,
    text = result.text,
    display = display,
    ordinal = ordinal,
    is_file_search = result.is_file_search,
    actual_lnum = result.lnum, -- Store actual line number for navigation
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
      finder = finders.new_dynamic({
        fn = function(prompt)
          if not prompt or prompt == '' then
            return {}
          end

          local cmd = string.format(
            'zoekt -index_dir %s %s',
            vim.fn.shellescape(index_path),
            vim.fn.shellescape(prompt)
          )

          local results = vim.fn.systemlist(cmd)
          local entries = {}
          local entry_idx = 0

          for _, line in ipairs(results) do
            if line and line ~= '' then
              -- Parse zoekt output format: filename:line:text
              local colon1 = line:find(':')
              if colon1 then
                local filename = line:sub(1, colon1 - 1)
                local rest = line:sub(colon1 + 1)

                local colon2 = rest:find(':')
                if colon2 then
                  local lnum_str = rest:sub(1, colon2 - 1)
                  local lnum = tonumber(lnum_str)
                  if lnum ~= nil then
                    local text = rest:sub(colon2 + 1)

                    -- For file searches (lnum == 0), mark as file search
                    local is_file_search = (lnum == 0)

                    -- Try to determine column by finding first non-whitespace
                    local col = 1
                    if text and text ~= '' and not is_file_search then
                      local _, col_end = string.find(text, '^%s*')
                      col = (col_end or 0) + 1
                    end

                    -- Create result with unique index
                    entry_idx = entry_idx + 1
                    table.insert(entries, {
                      filename = filename,
                      lnum = lnum,
                      col = col,
                      text = text or '',
                      is_file_search = is_file_search,
                      _idx = entry_idx, -- Unique index to prevent deduplication
                    })
                  end
                end
              end
            end
          end

          return entries
        end,
        entry_maker = make_entry,
      }),
      sorter = (function()
        local base_sorter = conf.generic_sorter(opts)
        local original_score = base_sorter.score

        -- Wrap the sorter to handle zoekt query syntax
        base_sorter.score = function(self, prompt, entry, cb_add, cb_filter)
          -- Check if prompt contains zoekt query syntax (f:, c:, etc.)
          local has_zoekt_syntax = prompt
            and (
              prompt:match('[fcrb]:') -- file, content, regex, both
              or prompt:match('-') -- exclusions
              or prompt:match('sym:') -- symbols
              or prompt:match('case:') -- case sensitivity
              or prompt:match('lang:') -- language filter
            )

          -- If using zoekt syntax or file search, pass empty prompt to sorter
          local sorter_prompt = prompt
          if has_zoekt_syntax or (entry and entry.is_file_search) then
            sorter_prompt = ''
          end

          return original_score(self, sorter_prompt, entry, cb_add, cb_filter)
        end

        return base_sorter
      end)(),
      previewer = create_zoekt_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            -- Open the file at the specified location
            vim.cmd('edit ' .. selection.filename)
            -- For file searches, go to line 1, otherwise use the actual line number
            local target_line = 1
            if selection.actual_lnum and selection.actual_lnum > 0 then
              target_line = selection.actual_lnum
            end
            vim.api.nvim_win_set_cursor(0, { target_line, selection.col - 1 })
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
