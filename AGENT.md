# AGENT.md

Chezmoi dotfiles for Windows/macOS/Linux. Neovim, WezTerm, Nushell, PowerShell configs.

## Commands

```bash
chezmoi apply          # Apply configs
chezmoi apply -n -v    # Dry-run verbose
chezmoi diff           # Preview changes
chezmoi doctor         # Check issues
stylua <path>          # Format Lua
```

## Structure

```
home/.chezmoitemplates/nvim/    # Neovim source (EDIT HERE)
home/dot_config/nvim/*.tmpl     # Auto-generated (DO NOT EDIT)
home/dot_config/wezterm/        # WezTerm (edit directly)
home/AppData/                   # Windows configs
```

## Lua Style

Config: 100 cols, 2-space indent, single quotes, Unix LF

```lua
-- Module pattern
---@class custom.Name
local M = {}
function M:new() return setmetatable({}, { __index = M }) end
return M

-- Optional require
local ok, mod = pcall(require, 'module')
if not ok then return end
```

Naming: `snake_case` functions/vars, `PascalCase` classes, `UPPER_CASE` constants

Types: Use `---@param`, `---@return`, `---@class`, `---@type`

## Neovim

Stack: lazy.nvim, nvim-lspconfig, mason.nvim, blink.cmp, conform.nvim, nvim-lint, snacks.nvim

### Add Language Support

Create `home/.chezmoitemplates/nvim/lua/configs/lsp/<lang>.lua`:

```lua
local LspConfig = require('configs.lsp.lspconfig')
local M = require('configs.lsp.base'):new()

local lsp = LspConfig:new('server', 'mason-pkg')
lsp.config = { settings = {} }
table.insert(M.lspconfigs, lsp)

M.treesitter.filetypes = { 'ft' }
M.formatterconfig = { servers = { 'fmt' }, formatters_by_ft = { ft = { 'fmt' } } }

return M
```

### Keys

Leader=`<Space>`, `jk`=Esc, `<leader>sf`=files, `<leader>sg`=grep, `<leader>fm`=format

## WezTerm

Edit `home/dot_config/wezterm/`. Modules: `{ apply_to_config = function(c) ... end }`

## Platform Detection

```lua
-- Neovim
local u = require('utils.common')
if u.IS_WINDOWS then end

-- WezTerm
local p = require('utils.platform')
if p.is_win then end
```

## Paths

| OS | Config |
|----|--------|
| Unix | `~/.config/` |
| Win | `~/AppData/Local/` |

## Shell

Bash: 4+, `[[ ]]`, quote vars, shellcheck

PowerShell: approved verbs, `Join-Path`
