-- Test synchronous telescope zoekt
require('zoekt').setup({
  use_telescope = true,
})

require('telescope._extensions.zoekt_test').test_sync()
