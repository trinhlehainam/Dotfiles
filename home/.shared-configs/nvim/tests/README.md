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

## Required plugins

The runner uses local plugin checkouts. Override their paths with environment
variables if needed:

| Plugin | Environment variable | Default path |
| --- | --- | --- |
| Plenary | `PLENARY_DIR` | `stdpath('data') . '/lazy/plenary.nvim'` |
| codesettings | `CODESETTINGS_DIR` | `stdpath('data') . '/lazy/codesettings.nvim'` |
| Conform | `CONFORM_DIR` | `stdpath('data') . '/lazy/conform.nvim'` |

## Test layout

- [minimal_init.lua](plenary/minimal_init.lua) loads the config and plugins in each test process.
- [spec/](plenary/spec/) contains tests named `*_spec.lua`.
- [helpers/](plenary/helpers/) contains shared test helpers.

Tests use real Neovim APIs, codesettings JSONC parsing, and Conform definitions.
LSP and Tree-sitter specs stub server startup and parser installation, so they
do not require running language servers or downloading parsers.
