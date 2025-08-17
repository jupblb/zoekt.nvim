-- zoekt.nvim plugin auto-loading file
-- This file is automatically loaded by Neovim when the plugin is installed

-- Prevent loading the plugin twice
if vim.g.loaded_zoekt then
  return
end
vim.g.loaded_zoekt = true

-- Auto-setup with default configuration if user hasn't called setup
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Check if setup was already called
    local config = require('zoekt.config')
    if vim.tbl_isempty(config.options) then
      -- Auto-setup with defaults
      require('zoekt').setup()
    end
  end,
  once = true,
})
