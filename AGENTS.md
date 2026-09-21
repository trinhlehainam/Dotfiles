# AGENT

Chezmoi dotfiles (Win/macOS/Linux). Main areas: Neovim, WezTerm, shells.

## Do / Don't

- Neovim source of truth: `home/.shared-configs/nvim/` (edit here)
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

- Add module: `home/.shared-configs/nvim/lua/configs/lsp/<lang>.lua`
- Return a plain table annotated `---@type dotfiles.lsp.Language`:
  - `parsers`: Tree-sitter parser names; `tools`: Mason package names
  - `servers`: server name → native `vim.lsp.Config`
  - Optional: `formatters`, `linters`, `lint_on_save`, `dap`, `neotest`
- Register the module in the ordered list in `lua/configs/lsp/init.lua`.
- Use `dap` only for mason-nvim-dap-managed adapters; see [language tooling](home/.shared-configs/nvim/doc/language-tooling.md) for plugin ownership.

## Lua Conventions

- Formatting via `.stylua.toml` (2 spaces, ~100 cols)
- Naming: `snake_case` vars/functions, `PascalCase` types, `UPPER_CASE` constants
- Types: `---@param`, `---@return`, `---@class`, `---@type`
