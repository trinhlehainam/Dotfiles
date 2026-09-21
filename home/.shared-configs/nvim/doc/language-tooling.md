# Language tooling

Requires **Neovim 0.12+** for native LSP configuration and built-in CodeLens.
Lua code targets Neovim's [Lua 5.1/LuaJIT interface](https://neovim.io/doc/user/lua/#lua-compat).

## Adding a language

Add `lua/configs/lsp/<language>.lua` using [lua.lua](../lua/configs/lsp/lua.lua) as
an example, then register it in [init.lua](../lua/configs/lsp/init.lua).
[types.lua](../lua/configs/lsp/types.lua) defines the available fields.

Parser names, Mason package names, and LSP server names can differ. Include tools
that servers call: Go needs both `golangci-lint-langserver` and `golangci-lint`.

## Loading and ownership

Language modules → registry → plugin setup. The registry rejects duplicate server
and formatter declarations. It combines linter lists; `lint_on_save = false` wins
unless [project settings](project-settings.md) override it. Neotest adapters load
after their plugin dependencies; initialization errors remain visible.

Mason installs tools. These plugins handle setup:

| Tool | Setup owner |
| --- | --- |
| Rust LSP and debugger | rustaceanvim |
| PowerShell LSP | powershell.nvim |
| C# LSP | roslyn.nvim |
| C# project commands and debugger | easy-dotnet; its LSP integration is disabled |
| Adapters listed in `dap` | mason-nvim-dap; omit adapters owned by other plugins |

The LSP setup registers its configs before enabling clients. Native `before_init`
hooks run before codesettings applies `.vscode/settings.json` from the client root,
so project settings take precedence. Roslyn is a dependency so its native config
is available during setup.

Missing Tree-sitter parsers are skipped during installation. Reopen the buffer
after installation to activate highlighting.

PHP reindexing and asynchronous CodeLens diagnostics live in
[features/intelephense.lua](../lua/features/intelephense.lua), separate from language settings.

## Updates

The repository has no shared lockfile, so fresh installs can use different plugin
revisions. Keep each installation's [lazy-lock.json](https://lazy.folke.io/usage/lockfile)
to reproduce it with `:Lazy restore`.

When updating plugins, check upstream migration notes, [run the tests](../tests/README.md),
and smoke-test the affected languages. Mason tools update separately; automatic
updates are disabled.
