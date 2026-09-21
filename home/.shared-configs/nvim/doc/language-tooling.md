# Language tooling

Requires **Neovim 0.12+**. Lua stays compatible with Neovim's Lua 5.1/LuaJIT interface.
The configuration uses native `vim.lsp.config` / `vim.lsp.enable` and built-in CodeLens.

## Adding a language

Add `lua/configs/lsp/<language>.lua`, return a plain table annotated
`---@type dotfiles.lsp.Language`, and register its name in `configs/lsp/init.lua`.
Use `configs/lsp/lua.lua` as a small example; optional fields are described in
`configs/lsp/types.lua`.

`parsers` contains Tree-sitter parser names, `tools` contains Mason package names,
and `servers` maps Neovim server names to native LSP configurations. These names
are separate: Go needs both the `golangci-lint-langserver` server package and the
`golangci-lint` executable it runs.

## Loading and ownership

Language modules → registry → plugin consumers:

1. The registry requires an explicit, ordered list of language modules once.
   Required import errors remain visible. Parser, tool and DAP lists are deduplicated.
2. Each server and formatter filetype has one owner; duplicates raise an error.
   Linter lists are combined in language order. Any `lint_on_save = false` disables
   automatic linting for that filetype, unless project settings override it.
3. Consumers use the resulting maps directly. Neotest adapter factories run later,
   after Neotest's dependencies load.

Mason installs tools; installation alone does not start a server or configure a debugger.
Rustaceanvim owns Rust LSP/DAP, powershell.nvim owns PowerShell startup, and roslyn.nvim
provides the C# server configuration. easy-dotnet owns C# project commands and debugging;
its competing Roslyn integration is disabled. The `dap` list contains only adapters
configured by mason-nvim-dap. Its handler filters other installed adapters to preserve
plugin ownership.

The LSP consumer registers all configs before enabling them. It composes native
`before_init` hooks with codesettings so `.vscode/settings.json` is read from the
resolved client root and overrides defaults after native initialization.
Roslyn is an explicit dependency so its native configuration is available before
the registry resolves it.

Tree-sitter activation resolves buffer filetypes to parser names, including aliases
and composite filetypes. Missing parsers are skipped while installation completes;
reopening the buffer activates highlighting once its parser is installed.

Conform runs the full formatter chain: JSX/TSX/Vue use Rustywind then prettierd;
JavaScript/TypeScript use prettierd. LSP formatting is a fallback only when no formatter
is available. Intelephense's reindex commands and asynchronous unused-reference
CodeLens diagnostics live in `features/intelephense.lua`; language settings stay in `lsp/php.lua`.

## Version and update policy

Plugin specs define the intended branches/version constraints (Tree-sitter uses `main`,
Rustaceanvim uses version 6). Lazy's `lazy-lock.json` is local to each installed config;
this repository currently does not distribute a shared lockfile. Therefore a fresh
install can select newer revisions than another machine. Keep that lockfile when
reproducing a working setup, and use `:Lazy restore` to restore its revisions.

Update plugins deliberately with Lazy, check upstream migration notes, and run
`make test` from the Neovim source directory. Smoke-test the languages being updated
before carrying the new lockfile to another machine. Mason tools have a separate
update cycle; `auto_update` remains disabled by default. The review report records
the revisions used for this change; they are verification evidence, not new pins.

References: [Neovim Lua compatibility](https://neovim.io/doc/user/lua/#lua-compat),
[native LSP configuration](https://github.com/neovim/nvim-lspconfig#configuration),
[Lazy lockfile](https://lazy.folke.io/usage/lockfile),
[Tree-sitter activation](https://github.com/nvim-treesitter/nvim-treesitter/tree/main#highlighting).
