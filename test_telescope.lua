-- Test telescope zoekt integration
require('zoekt').setup({
  use_telescope = true,
})

-- Load telescope
local telescope = require('telescope')
telescope.load_extension('zoekt')

-- Test the extension
local zoekt_ext = telescope.extensions.zoekt

-- Try to search
print('Testing telescope zoekt...')
local ok, err = pcall(function()
  zoekt_ext.zoekt({})
end)

if not ok then
  print('Error: ' .. tostring(err))
else
  print('Success!')
end
