# zoekt.nvim

A Neovim plugin for integrating [Zoekt] code search engine directly into your
editor workflow.

## Features

- **Fast code search**: Leverage Zoekt's powerful indexing and search
  capabilities within Neovim
- **Git hook integration**: Install post-commit hooks to automatically keep your
  index up-to-date
- **Quickfix integration**: Search results displayed in Neovim's quickfix list
  for easy navigation
- **Telescope integration**: Optional integration with telescope.nvim for
  interactive live search with real-time results as you type
- **Configurable**: Flexible index path configuration with environment variable
  support

## Requirements

- Neovim \>= 0.11.2
- [Zoekt] installed (`zoekt-index`, `zoekt-git-index`, and `zoekt` binaries in
  PATH)
- [plenary.nvim] (optional, for enhanced functionality)
- [telescope.nvim] (optional, for telescope integration)

## Installation

### Using [lazy.nvim]

``` lua
{
  "jupblb/zoekt.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Optional but recommended
    "nvim-telescope/telescope.nvim", -- Optional, for telescope integration
  },
  config = function()
    require("zoekt").setup({
      -- All config options are optional
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
      -- All config options are optional
    })
  end,
}
```

## Configuration

``` lua
require("zoekt").setup({
  -- Path where Zoekt indexes are stored
  -- Default priority:
  -- 1. ZOEKT_INDEX_PATH environment variable (if set)
  -- 2. Git project root + "/.zoekt" (if in git repo)
  -- 3. "~/.zoekt" (fallback)
  index_path = nil,  -- nil uses smart defaults

  -- Automatically open quickfix window after search
  auto_open_quickfix = true,

  -- Use telescope.nvim for search results (if available)
  use_telescope = true,  -- default: true, falls back to quickfix if telescope not installed
})
```

**Recommendation**: For better search isolation, consider using separate index
paths for each repository. This prevents search results from mixing across
different projects and eliminates the need for `repo:` filters in your queries.
You can set a custom `index_path` per project or use environment variables to
manage multiple indexes.

## Usage

### Commands

#### `:ZoektIndex`

Build or update the Zoekt index for the current project.

- In a git repository: Uses `zoekt-git-index` and indexes from the repository
  root
- Outside git: Uses `zoekt-index` and indexes the current working directory
- Uses the configured `index_path` for storing the index

Example:

``` vim
:ZoektIndex " Index current directory/repository
```

#### `:ZoektSearch [query]`

Search the indexed codebase using Zoekt query syntax.

- When telescope is available (default): Opens telescope picker with live search
- When telescope is not available: Results are populated in the quickfix list

Examples:

``` vim
:ZoektSearch " Open live search (telescope) or show usage (quickfix)
```

#### `:ZoektTelescope`

Live search mode with telescope (telescope.nvim required).

- Search results update as you type
- Press `<Enter>` to jump to result
- Press `<C-q>` to send results to quickfix

Example:

``` vim
:ZoektTelescope " Start live search
```

#### `:ZoektHook`

Install a git post-commit hook that automatically updates the Zoekt index after
each commit.

- Only works in git repositories
- Automatically overwrites any existing post-commit hook
- The hook runs `zoekt-index` after each commit
- Hook is standalone and doesn't require Neovim to run

Example:

``` vim
:ZoektHook " Install post-commit hook
```

**Recommendation**: When working in a git repository, it's recommended to
install this hook to keep your Zoekt index automatically up-to-date with your
commits.

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
    │       ├── config.lua      # Configuration handling
    │       └── hook.lua        # Git hook management
    ├── tests/
    │   ├── minimal_init.lua    # Minimal config for testing
    │   ├── zoekt_spec.lua      # Test specifications
    │   └── zoekt_hook_spec.lua # Hook functionality tests
    ├── README.md
    ├── AGENT.md                # AI agent instructions
    └── PLAN.md                 # Implementation plan

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

  [Zoekt]: https://github.com/sourcegraph/zoekt
  [plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
  [telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
  [lazy.nvim]: https://github.com/folke/lazy.nvim
  [packer.nvim]: https://github.com/wbthomason/packer.nvim
  [Zoekt documentation]: https://github.com/sourcegraph/zoekt#query-language
