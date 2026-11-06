# Neovim tests

These tests require Neovim 0.12+.

## Run

Run the test suite from `home/.shared-configs/nvim/`:

```bash
make test
```

To run one test file:

```bash
nvim --headless --noplugin -u tests/plenary/minimal_init.lua \
  -c "lua require('plenary.busted').run('tests/plenary/spec/project_detection_spec.lua')"
```

On Linux or macOS, install tmux and Bash to check markers from a real tmux client:

```bash
make test-tmux
```

This test starts a private temporary tmux server and a Bash terminal. It checks
reattaching to a running program, reloading the config, detaching, and exiting
the final session. It leaves existing tmux sessions alone.

## Required plugins

Tests use local plugin checkouts. Set the environment variables below if your
plugins are stored elsewhere:

| Plugin | Environment variable | Default path |
| --- | --- | --- |
| Plenary | `PLENARY_DIR` | `stdpath('data') . '/lazy/plenary.nvim'` |
| lazy.nvim | `LAZY_DIR` | `stdpath('data') . '/lazy/lazy.nvim'` |
| Easy Dotnet | `EASY_DOTNET_DIR` | `stdpath('data') . '/lazy/easy-dotnet.nvim'` |
| Blink completion | `BLINK_CMP_DIR` | `stdpath('data') . '/lazy/blink.cmp'` |
| auto-session | `AUTO_SESSION_DIR` | `stdpath('data') . '/lazy/auto-session'` |
| Markdown Reader | `MARKDOWN_TABLE_WRAP_DIR` | `stdpath('data') . '/lazy/markdown-table-wrap.nvim'` |
| codesettings | `CODESETTINGS_DIR` | `stdpath('data') . '/lazy/codesettings.nvim'` |
| Conform | `CONFORM_DIR` | `stdpath('data') . '/lazy/conform.nvim'` |
| nvim-lspconfig | `LSPCONFIG_DIR` | `stdpath('data') . '/lazy/nvim-lspconfig'` |
| nvim-dap | `DAP_DIR` | `stdpath('data') . '/lazy/nvim-dap'` |
| nvim-nio | `NIO_DIR` | `stdpath('data') . '/lazy/nvim-nio'` |
| smart-splits v3 | `SMART_SPLITS_DIR` | `stdpath('data') . '/lazy/smart-splits.nvim'` |
| tmux backend | `SMART_SPLITS_TMUX_DIR` | `stdpath('data') . '/lazy/backend-tmux'` |
| WezTerm backend | `SMART_SPLITS_WEZTERM_DIR` | `stdpath('data') . '/lazy/backend-wezterm'` |

## Test layout

- [minimal_init.lua](plenary/minimal_init.lua) loads the config and plugins in each test process.
- [spec/](plenary/spec/) contains tests named `*_spec.lua`.
- [integration/](plenary/integration/) contains tests you run separately against real processes.
- [helpers/](plenary/helpers/) contains shared test helpers.

Tests use real Neovim APIs, codesettings JSONC parsing, and Conform definitions.
LSP, Mason, and Tree-sitter tests simulate server startup and installs, so they
need no network, running servers, or parser builds.

Installation tests cover duplicate requests, partially linked packages, failures
and retries, closed buffers, filetype aliases, plugin-owned servers, and debug
launches. Project tests cover Biome monorepos and Windows home paths. A real
Markdown tree checks that newly available injections work without editing text.
The Rust debug regression uses real nvim-dap and nvim-nio scheduling; it simulates
installation and adapter process launch. C# tests check `.cs`, `.razor`, and `.cshtml` detection.

For a real download/build check, run `make test-tool-install`. It installs Pyright,
Ruff, and the Python parser in temporary XDG directories, then removes them.
It checks that startup and an unopened Node project install nothing (Noice's UI
parsers are excluded), that the first Python buffer gets both servers and
highlighting, and that repeated FileType events reuse the clients.
Normal Mason/parser installations stay untouched.

Requires Python 3, Node/npm, network access, a C compiler, the Tree-sitter CLI
version nvim-treesitter requires, and local Mason, nvim-lspconfig, and
nvim-treesitter checkouts. Set `NVIM_TEST_PLUGIN_DIR` if those checkouts are outside
`$XDG_DATA_HOME/nvim/lazy` (default: `~/.local/share/nvim/lazy`).

The [session restoration tests](../doc/session-restoration.md) use real session
scripts and stale swap files. The Reader test starts an isolated Neovim with
lazy.nvim and markdown-table-wrap.nvim to check source recovery and swap protection.

The smart-splits tests run the real core and backend plugins. They replace tmux
process calls and terminal OSC writes with test doubles. The WezTerm navigation
tests run the real routing helpers with a small substitute for WezTerm's action
API. These tests need neither a running tmux server nor a WezTerm GUI.
