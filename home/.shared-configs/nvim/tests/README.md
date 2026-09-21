# Neovim tests

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

This runs the spec in the Neovim instance that loaded the test init.

The full command behind `make test` is:

```bash
nvim --headless --noplugin -u tests/plenary/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/plenary/spec/ { minimal_init = 'tests/plenary/minimal_init.lua', sequential = true }"
```

## Required plugins

The test runner loads local plugin checkouts from Lazy's data directory by default. Set the corresponding environment variable if a plugin is installed elsewhere:

| Plugin | Environment variable | Default path |
| --- | --- | --- |
| Plenary | `PLENARY_DIR` | `stdpath('data') . '/lazy/plenary.nvim'` |
| codesettings | `CODESETTINGS_DIR` | `stdpath('data') . '/lazy/codesettings.nvim'` |
| Conform | `CONFORM_DIR` | `stdpath('data') . '/lazy/conform.nvim'` |

The project settings specs use the real codesettings JSONC decoder and Conform formatter definitions.

## Test layout

- `tests/plenary/minimal_init.lua`: loads the repository and required plugins for the runner and each child Neovim instance.
- `tests/plenary/spec/`: integration tests; the runner discovers files ending in `_spec.lua`.
- `tests/plenary/helpers/`: shared test helpers.
