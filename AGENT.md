# AGENT

Chezmoi dotfiles (Win/macOS/Linux). Main areas: Neovim, WezTerm, shells.

## Do / Don't

- Neovim source of truth: `home/.chezmoitemplates/nvim/` (edit here)
- Neovim generated templates: `home/dot_config/nvim/**.tmpl` (avoid hand-editing)
- WezTerm: `home/dot_config/wezterm/` (edit directly)

## Common Commands

```bash
chezmoi diff
chezmoi apply
chezmoi apply -n -v
chezmoi doctor
stylua <path>
```

## Neovim: Add Language Support

- Add module: `home/.chezmoitemplates/nvim/lua/configs/lsp/<lang>.lua`
- Return `require('configs.lsp.base'):new()` with:
  - `M.treesitter.filetypes = { ... }`
  - `M.lspconfigs = { ... }` (use `require('configs.lsp.lspconfig'):new(server, mason_pkg)`)
  - Optional: `M.formatterconfig`, `M.linterconfig`, `M.dapconfigs`, `M.neotest_adapter_setup`

## Lua Conventions

- Formatting via `.stylua.toml` (2 spaces, ~100 cols)
- Naming: `snake_case` vars/functions, `PascalCase` types, `UPPER_CASE` constants
- Types: `---@param`, `---@return`, `---@class`, `---@type`
