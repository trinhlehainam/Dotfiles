# Language tooling

Requires **Neovim 0.12+**. Lua follows Neovim's
[Lua 5.1/LuaJIT interface](https://neovim.io/doc/user/lua/#lua-compat).

## What installs

Open a supported file to install its language's missing LSP servers, formatters,
and linters. For example, a Python file requests Pyright and Ruff. Installation
runs in the background; the LSP attaches to the open buffer when ready.

- Opening a project folder alone installs no language tools. Files are not scanned.
- Terminals, file explorers, and hover windows do not request language tools.
- Installed tools stay available across projects and sessions; nothing is uninstalled automatically.
- JavaScript, TypeScript, and Vue install vtsls and vue-language-server together:
  the configured vtsls server uses Vue's TypeScript plugin.
- Go template files do not request Go tools.
- C# and Razor files (`.cs`, `.razor`, `.cshtml`) request Roslyn.

For configured languages, Tree-sitter installs the file's missing parser and common embedded grammars
(for example, PHP with HTML, or Vue with JavaScript/TypeScript and CSS).
Markdown also gets YAML/TOML front matter and HTML grammars.
Embedded grammars add syntax highlighting only.
Highlighting starts in the existing buffer after installation, without an edit.
Arbitrary Markdown code fences do not trigger downloads.
Reopen the file if a code fence or template needs a grammar installed later.

**Startup exception:** Noice needs `vim`, `regex`, `lua`, `bash`, `markdown`,
and `markdown_inline` for its UI. Only missing grammars install at startup; bundled
parsers are reused. Help, hover, and other special buffers use installed parsers
without triggering downloads.

Go, Python, PHP, and Rust debug adapters install when a debug session needs them.
Loading DAP or opening a file does not install these adapters.
F5 reports first-use installation and ignores repeated presses until setup finishes.
Direct DAP commands and API calls still request separate launches.

## Project checks

Biome and Tailwind install only in projects that use them:

- **Biome:** `biome.json`, `biome.jsonc`, or an `@biomejs/biome` dependency.
- **Tailwind:** a `tailwind.config.*` file with a `js`, `cjs`, `mjs`, `ts`,
  `cts`, or `mts` extension, or a `tailwindcss` dependency. The dependency alone
  is enough for v4 projects without a config file.

Checks search upward from the file's folder, stopping at the repository root
(Git worktrees included) or your home folder. They read `package.json` dependencies,
including dev, peer, and optional dependencies, without running project commands.
Checks run when a file opens. After adding Biome or Tailwind, reopen already-open files.
Razor files also request Tailwind when the project check passes.

Tailwind also attaches only where this check passes. A Git repository, PostCSS
config, Rails/Phoenix lockfile, or Django theme folder alone does not count.
Biome attachment still uses nvim-lspconfig's checks, which handle monorepos and
prefer the project's `node_modules/.bin/biome`.

## First use, errors, and updates

Each native LSP starts once its own required packages are ready. A failed optional
formatter or linter does not block it. Automatic linting skips missing executables;
formatting may temporarily fall back to the LSP.
New installations can reactivate manually stopped LSPs or Tree-sitter highlighting
in open buffers. Neovim also reapplies modelines when a new server is enabled.

A failed tool or parser is not retried automatically in that session. Parser retry
warnings are grouped per batch. Servers managed by Mason wait for its packages,
even if another copy of the server is on `PATH`.

| Task | Command and behavior |
| --- | --- |
| Diagnose a tool | `:MasonLog`, `:checkhealth mason` |
| Retry a tool | `:MasonInstall <package>`; a server that had not started attaches after success; otherwise reopen the file |
| Retry a parser | Check `:TSLog`, run `:TSInstall <parser>` (`:TSInstall! <parser>` if query files are missing), then reopen the file |
| Retry debugging | Run `:MasonInstall <package>` from the warning, then launch again |
| Run linters manually | `:Lint`; reports all errors, including missing linters |
| Install/update every configured tool | `:MasonToolsInstall` / `:MasonToolsUpdate`, including debug tools |
| Update installed parsers | `:TSUpdate`; also runs when lazy.nvim updates nvim-treesitter |

If another Neovim instance is installing the same tool, this one may report a
failure; reopen the file after that installation finishes. A failed adapter install
can leave a neotest debug run pending; neotest's stop action may not clear it.
Install the adapter before retrying, and restart Neovim to clear the pending run.

Bulk tool installation at startup is disabled, and Mason tools never update automatically.
Install required runtimes yourself (for example Go, Node, PHP, Python, .NET,
and PowerShell); parser builds also need the
[upstream Tree-sitter CLI and compiler requirements](https://github.com/nvim-treesitter/nvim-treesitter#requirements).

There is no shared plugin lockfile. Keep your
[lazy-lock.json](https://lazy.folke.io/usage/lockfile) for `:Lazy restore`.
After Neovim or plugin updates, [run the tests](../tests/README.md) and check affected languages.
Receipt paths, highlighter state, and missing-injection cache handling depend on
upstream internals. The tests cover these workarounds; native Windows/macOS installs
and competing Neovim processes have not been smoke-tested.

## Chezmoi filetypes

[filetypes.lua](../lua/configs/filetypes.lua) detects `dot_` path components as their
deployed `.` names, then delegates to Neovim's built-in filetype detection. For example,
`dot_tmux.conf` uses `tmux`, and `dot_bashrc` uses `sh` with Bash buffer settings.
Names ending in `.tmpl` skip decoding, so templates keep the existing `gotmpl` highlighting.
The rule covers `dot_` names; other chezmoi attributes are not decoded.

## Adding a language

Create `lua/configs/lsp/<language>.lua`, following
[lua.lua](../lua/configs/lsp/lua.lua), and register it in
[init.lua](../lua/configs/lsp/init.lua). Return a plain
`dotfiles.lsp.Language` table; [types.lua](../lua/configs/lsp/types.lua) defines all fields.

| Field | Purpose |
| --- | --- |
| `filetypes` | Exact buffer filetypes that request editing tools |
| `tools` | Mason packages for editing |
| `server_tools` | Required packages per native server, including tools it calls; each must appear in `tools` |
| `servers` | Server name → native `vim.lsp.Config`; omit `server_tools` for system-owned servers such as Nushell |
| `parsers` | Allowed Tree-sitter grammar names; add common embedded grammars to the [companion map](../lua/configs/plugins/nvim-treesitter.lua) |
| `condition` | Optional install gate; attachment must also be gated by upstream checks or a matching `root_dir` |
| `on_ready` | Start a plugin-owned server in the supplied buffer after all of the language's `tools` install; tolerate repeated FileType events |
| `debug_tools` | Packages included in explicit bulk installs, excluded from editing requests |
| `dap` | Only adapters managed by mason-nvim-dap |

Keep setup ownership intact: rustaceanvim owns Rust, powershell.nvim owns
PowerShell, roslyn.nvim owns C# LSP, and easy-dotnet owns C# debugging.
Nushell uses the system installation.

`formatters`, `linters`, `lint_on_save`, and `neotest` configure the remaining
tools. Linter lists merge; `lint_on_save = false` wins unless
[project settings](project-settings.md) override it. Neotest factories run after
their dependencies load. The registry checks install triggers, required packages,
and duplicate server/formatter owners.

## Implementation notes

- [Language dispatch](../lua/features/language_install.lua) handles FileType and
  already-open buffers. Each buffer rechecks only its own servers; enabled servers
  are skipped. Language modules still load at startup to register filetype rules.
- [Mason installation](../lua/utils/mason_install.lua) shares concurrent requests
  and checks receipts written after binary linking. Native
  [vim.lsp.enable()](https://neovim.io/doc/user/lsp/#vim.lsp.enable()) attaches
  existing buffers and reuses clients.
- [Tree-sitter installation](../lua/configs/plugins/nvim-treesitter.lua) uses
  nonblocking batches, refreshes runtime lookup, and reparses waiting buffers so
  newly installed injections work. Catch-up skips closed buffers, uses each buffer's
  current filetype, and reuses highlighters for the same parser. Failed companions
  do not block the host grammar. Invalid injection or highlight queries in one buffer
  do not prevent other buffers from activating. Highlight errors are reported. The plugin stays
  `lazy = false`, as [upstream requires](https://github.com/nvim-treesitter/nvim-treesitter#installation).
- [DAP installation](../lua/features/dap_install.lua) waits for executables before
  resolving adapters or starting a session. Callback adapters let neotest keep
  control of its async tasks; Rust launch settings still come from rustaceanvim.

Native `before_init` hooks run before codesettings applies
`.vscode/settings.json`, so project settings take precedence.
PHP indexing and CodeLens remain in
[features/intelephense.lua](../lua/features/intelephense.lua).

API references: [Mason](https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt),
[DAP](https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt).
