# Agent Instructions for zoekt.nvim

This document provides instructions for AI agents working on the zoekt.nvim
project.

## Project Overview

zoekt.nvim is a Neovim plugin that integrates the Zoekt code search engine. The
plugin provides commands for indexing codebases and searching through them using
Zoekt's powerful search capabilities.

## Key Commands

### Build and Test

``` bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Run specific test file
nvim --headless -c "PlenaryBustedFile tests/zoekt_spec.lua"

# Check Lua syntax (requires luacheck)
luacheck lua/

# Format Lua code (requires stylua)
stylua lua/ tests/
```

### Development Workflow

1.  Make changes to Lua files in `lua/zoekt/`
2.  Write/update tests in `tests/`
3.  Run tests to verify functionality
4.  Test manually in Neovim

## Code Style Guidelines

### Lua Conventions

- Use snake_case for variables and functions
- Use PascalCase for classes/modules
- Indent with 2 spaces
- Follow existing code patterns in the repository
- Document public APIs with comments

### Module Structure

``` lua
local M = {}

-- Private functions
local function private_helper()
  -- implementation
end

-- Public API
function M.public_function()
  -- implementation
end

return M
```

### Testing Guidelines

- Use plenary.nvim's `describe` and `it` DSL
- Mock external commands (zoekt binaries) in tests
- Test both success and error cases
- Keep tests isolated and independent

## Architecture Notes

### Core Modules

- `lua/zoekt/init.lua`: Main entry point and setup
- `lua/zoekt/config.lua`: Configuration management
- `lua/zoekt/index.lua`: Handles ZoektIndex command
- `lua/zoekt/search.lua`: Handles ZoektSearch command

### Key Dependencies

- **plenary.nvim**: Used for async operations and testing framework
- **Zoekt binaries**: External dependencies that must be mocked in tests

### Configuration Flow

1.  User calls `require("zoekt").setup(opts)`
2.  Config module merges user options with defaults
3.  Environment variable `ZOEKT_INDEX_PATH` takes precedence if set
4.  Index path is expanded (~ to home directory)

### Command Implementation

- Commands are defined in `init.lua` using `vim.api.nvim_create_user_command`
- Command handlers parse arguments and delegate to appropriate modules
- Results are displayed using quickfix list (`vim.fn.setqflist`)

## Important Patterns

### Async Operations

Use plenary.nvim's async utilities when available:

``` lua
local Job = require("plenary.job")

Job:new({
  command = "zoekt",
  args = { "-index", index_path, query },
  on_exit = function(j, return_val)
    -- handle results
  end,
}):start()
```

### Error Handling

Always validate inputs and provide helpful error messages:

``` lua
if not executable_exists("zoekt") then
  vim.notify("Zoekt is not installed or not in PATH", vim.log.levels.ERROR)
  return
end
```

### Path Handling

Always expand and normalize paths:

``` lua
local path = vim.fn.expand(config.index_path)
local absolute_path = vim.fn.fnamemodify(path, ":p")
```

## Testing Approach

### Test Structure

``` lua
describe("zoekt.nvim", function()
  describe("ZoektIndex", function()
    it("should detect git repositories", function()
      -- test implementation
    end)

    it("should handle non-git directories", function()
      -- test implementation
    end)
  end)

  describe("ZoektSearch", function()
    it("should populate quickfix list", function()
      -- test implementation
    end)
  end)
end)
```

### Mocking External Commands

Mock Zoekt binaries to avoid dependencies in tests:

``` lua
local function mock_zoekt_command(output)
  -- Return mock Job that returns predefined output
end
```

## Common Issues and Solutions

1.  **Path expansion**: Always use `vim.fn.expand()` for paths with `~`
2.  **Git detection**: Use `vim.fn.finddir(".git", ".;")` to detect git
    repositories
3.  **Quickfix formatting**: Ensure proper format for `setqflist` entries
4.  **Async handling**: Consider using callbacks or plenary's async for
    non-blocking operations

## References

- [Zoekt Documentation]

- [Neovim Lua Guide]

- [Plenary.nvim]

  [Zoekt Documentation]: https://github.com/sourcegraph/zoekt
  [Neovim Lua Guide]: https://neovim.io/doc/user/lua-guide.html
  [Plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
