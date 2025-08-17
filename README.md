# zoekt.nvim

A Neovim plugin for integrating [Zoekt] code search engine directly into your
editor workflow.

## Features

- **Fast code search**: Leverage Zoekt's powerful indexing and search
  capabilities within Neovim
- **Automatic indexing**: Smart detection of git repositories vs regular
  directories
- **Quickfix integration**: Search results displayed in Neovim's quickfix list
  for easy navigation
- **Configurable**: Flexible index path configuration with environment variable
  support

## Requirements

- Neovim \>= 0.8.0
- [Zoekt] installed (`zoekt-index`, `zoekt-git-index`, and `zoekt` binaries in
  PATH)
- [plenary.nvim] (optional, for enhanced functionality)

## Installation

### Using [lazy.nvim]

``` lua
{
  "jupblb/zoekt.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Optional but recommended
  },
  config = function()
    require("zoekt").setup({
      -- Configuration options
      index_path = vim.env.ZOEKT_INDEX_PATH or "~/.zoekt",
    })
  end,
}
```

### Using [packer.nvim]

``` lua
use {
  "jupblb/zoekt.nvim",
  requires = {
    "nvim-lua/plenary.nvim", -- Optional but recommended
  },
  config = function()
    require("zoekt").setup({
      index_path = vim.env.ZOEKT_INDEX_PATH or "~/.zoekt",
    })
  end,
}
```

## Configuration

``` lua
require("zoekt").setup({
  -- Path where Zoekt indexes are stored
  -- Can be overridden by ZOEKT_INDEX_PATH environment variable
  index_path = "~/.zoekt",

  -- Additional configuration options can be added here
})
```

## Usage

### Commands

#### `:ZoektIndex [path]`

Build or update the Zoekt index for the current project.

- In a git repository: Uses `zoekt-git-index` and indexes from the repository
  root
- Outside git: Uses `zoekt-index` and indexes the current working directory
- Optional `path` argument: Specify custom index location (defaults to
  configured `index_path`)

Examples:

``` vim
:ZoektIndex                    " Index to default location
:ZoektIndex ~/my-indices/work  " Index to custom location
```

#### `:ZoektSearch [index=<path>] <query>`

Search the indexed codebase using Zoekt query syntax.

- Results are populated in the quickfix list
- Press `<Enter>` on a result to jump to the file and location
- Optional `index=<path>`: Use a specific index (defaults to configured
  `index_path`)

Examples:

``` vim
:ZoektSearch function handleRequest   " Search in default index
:ZoektSearch index=~/work TODO        " Search in custom index
:ZoektSearch "exact phrase"            " Search for exact phrase
:ZoektSearch file:\.lua$ setup         " Search only in Lua files
```

### Zoekt Query Syntax

Zoekt supports advanced search syntax:

- `word1 word2`: Find both words
- `"exact phrase"`: Find exact phrase
- `file:pattern`: Match file paths
- `lang:lua`: Search in specific language
- `sym:functionName`: Search for symbols
- See [Zoekt documentation] for full syntax

## Development

### Running Tests

Tests are written using plenary.nvim's testing framework:

``` bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Run specific test file
nvim --headless -c "PlenaryBustedFile tests/zoekt_spec.lua"
```

### Project Structure

    zoekt.nvim/
    ├── lua/
    │   └── zoekt/
    │       ├── init.lua        # Main plugin module
    │       ├── index.lua       # Indexing functionality
    │       ├── search.lua      # Search functionality
    │       └── config.lua      # Configuration handling
    ├── tests/
    │   ├── minimal_init.lua    # Minimal config for testing
    │   └── zoekt_spec.lua      # Test specifications
    ├── README.md
    ├── AGENT.md                # AI agent instructions
    └── PLAN.md                 # Implementation plan

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

  [Zoekt]: https://github.com/sourcegraph/zoekt
  [plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
  [lazy.nvim]: https://github.com/folke/lazy.nvim
  [packer.nvim]: https://github.com/wbthomason/packer.nvim
  [Zoekt documentation]: https://github.com/sourcegraph/zoekt#query-language
