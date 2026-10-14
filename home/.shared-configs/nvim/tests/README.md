# Neovim tests

Requires Neovim 0.12+.

## Run

Run all tests from `home/.shared-configs/nvim/`:

```bash
make test
```

To run one spec:

```bash
nvim --headless --noplugin -u tests/plenary/minimal_init.lua \
  -c "lua require('plenary.busted').run('tests/plenary/spec/project_detection_spec.lua')"
```

To check real tmux client markers on Linux/macOS with tmux and Bash installed:

```bash
make test-tmux
```

This uses a private temporary tmux server and a terminal running Bash. It checks
reattachment to an already-running program, configuration reloads, detachment,
and final-session exit. Existing tmux sessions are not touched.

## Required plugins

The runner uses local plugin checkouts. Override their paths with environment
variables if needed:

| Plugin | Environment variable | Default path |
| --- | --- | --- |
| Plenary | `PLENARY_DIR` | `stdpath('data') . '/lazy/plenary.nvim'` |
| codesettings | `CODESETTINGS_DIR` | `stdpath('data') . '/lazy/codesettings.nvim'` |
| Conform | `CONFORM_DIR` | `stdpath('data') . '/lazy/conform.nvim'` |
| smart-splits v3 | `SMART_SPLITS_DIR` | `stdpath('data') . '/lazy/smart-splits.nvim'` |
| tmux backend | `SMART_SPLITS_TMUX_DIR` | `stdpath('data') . '/lazy/backend-tmux'` |
| WezTerm backend | `SMART_SPLITS_WEZTERM_DIR` | `stdpath('data') . '/lazy/backend-wezterm'` |

## Test layout

- [minimal_init.lua](plenary/minimal_init.lua) loads the config and plugins in each test process.
- [spec/](plenary/spec/) contains tests named `*_spec.lua`.
- [integration/](plenary/integration/) contains opt-in tests against real processes.
- [helpers/](plenary/helpers/) contains shared test helpers.

Tests use real Neovim APIs, codesettings JSONC parsing, and Conform definitions.
LSP and Tree-sitter specs stub server startup and parser installation, so they
do not require running language servers or downloading parsers.

The smart-splits spec uses the real core and backend plugins, replacing only
tmux process calls and terminal OSC writes. The WezTerm navigation spec uses
the real routing helpers with a small WezTerm action API stub. Neither spec
requires a running tmux server or WezTerm GUI.
