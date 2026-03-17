## Test Layout

- `tests/plenary/minimal_init.vim`: shared Plenary init used by the parent runner and child test instances
- `tests/plenary/spec/`: busted-style integration specs
- `tests/plenary/helpers/`: shared harness helpers for specs

## Run

Short command:

```bash
make test
```

Canonical raw command:

```bash
nvim --headless --noplugin -u tests/plenary/minimal_init.vim \
  -c "PlenaryBustedDirectory tests/plenary/spec/ { minimal_init = 'tests/plenary/minimal_init.vim', sequential = true }"
```

This uses one shared init:
- it loads Plenary and the repo on `runtimepath`
- `PlenaryBustedDirectory` discovers `*_spec.lua` files under `tests/plenary/spec/`
- each child Neovim instance reuses the same `tests/plenary/minimal_init.vim`

## Plenary Path

The test init resolves Plenary in this order:

1. `$PLENARY_DIR`
2. `stdpath('data') . '/lazy/plenary.nvim'`

If your Plenary checkout is not under Lazy's default path, set `PLENARY_DIR`
before running the command.
