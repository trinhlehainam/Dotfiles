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
| codesettings | `CODESETTINGS_DIR` | `stdpath('data') . '/lazy/codesettings.nvim'` |
| Conform | `CONFORM_DIR` | `stdpath('data') . '/lazy/conform.nvim'` |
| smart-splits v3 | `SMART_SPLITS_DIR` | `stdpath('data') . '/lazy/smart-splits.nvim'` |
| tmux backend | `SMART_SPLITS_TMUX_DIR` | `stdpath('data') . '/lazy/backend-tmux'` |
| WezTerm backend | `SMART_SPLITS_WEZTERM_DIR` | `stdpath('data') . '/lazy/backend-wezterm'` |

## Test layout

- [minimal_init.lua](plenary/minimal_init.lua) loads the config and plugins in each test process.
- [spec/](plenary/spec/) contains tests named `*_spec.lua`.
- [integration/](plenary/integration/) contains tests you run separately against real processes.
- [helpers/](plenary/helpers/) contains shared test helpers.

Tests use real Neovim APIs, codesettings JSONC parsing, and Conform definitions.
LSP and Tree-sitter tests simulate server startup and parser installation, so
they do not need running language servers or parser downloads.

The smart-splits tests run the real core and backend plugins. They replace tmux
process calls and terminal OSC writes with test doubles. The WezTerm navigation
tests run the real routing helpers with a small substitute for WezTerm's action
API. These tests need neither a running tmux server nor a WezTerm GUI.
