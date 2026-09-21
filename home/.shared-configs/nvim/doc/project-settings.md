# Project settings

Project configuration uses three existing formats:

| File | Owner | Purpose |
| --- | --- | --- |
| `.vscode/settings.json` | codesettings + editor adapter | LSP settings, file associations, language-specific editor options |
| `.nvim/tooling.json` | tooling adapter | Formatter/linter selection, arguments, save behavior |
| `.vscode/launch.json` | nvim-dap | Debug launch profiles |

Editor/tooling settings use the nearest ancestor containing `.git`, `.jj`,
`.nvim`, or `.vscode`. These markers have equal priority. A nested project uses
its own settings; parent settings are not inherited. LSP settings are loaded
from each client's root during initialization.

## Editor settings

`.vscode/settings.json` supports JSONC comments and trailing commas:

```jsonc
{
  "files.associations": {
    "**/*.blade.php": "blade",
    "*.{inc,phtml}": "php"
  },
  "[php]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 4,
    "editor.detectIndentation": false,
    "editor.formatOnSave": true
  }
}
```

The editor adapter supports these four options inside language blocks. Top-level
`editor.*` defaults are not supported. Bracketed groups such as `[html][php]`
apply to each language. Names must match Neovim filetypes; VS Code language names
are not translated. For compound Neovim filetypes such as `html.php`, component
settings merge in order, followed by the exact compound filetype.

`editor.tabSize` must be an integer from 1 through 9999. Invalid values warn and
are ignored. Explicit indentation settings take precedence over indentation
detection plugins. `editor.detectIndentation = false` restores filetype defaults
before applying explicit values; `true` alone does not invoke an indent detector.

Associations without `/` match the basename; patterns containing `/` match the
path relative to the project root. Native glob matching supports `*`, `**`, `?`,
braces, and character classes. Exact basenames take precedence over other globs,
which take precedence over simple `*.ext` rules. Within a group, longer patterns
win, followed by descending lexical order for ties. Built-in detection remains
available outside matching projects and after an override is removed.

## Formatter and linter settings

`.nvim/tooling.json` uses standard JSON:

```json
{
  "defaults": {
    "format_on_save": true,
    "lint_on_save": true
  },
  "filetypes": {
    "php": {
      "formatters": ["php_cs_fixer"],
      "linters": ["phpstan"],
      "format_on_save": false
    }
  },
  "formatters": {
    "php_cs_fixer": { "args_append": ["--using-cache=no"] }
  },
  "linters": {
    "phpstan": { "args_append": ["--memory-limit=1G"] }
  }
}
```

Tool names refer to Conform/nvim-lint definitions. Project lists add to configured
tools; an empty list does not disable global tools. `args` replaces arguments;
`args_append` appends arguments. Formatter inheritance is preserved, including
custom formatters with no built-in parent. Executables must already be installed.

Filetype values override tooling defaults. Compound filetypes merge their
components in order, then their exact name. An explicit tooling `format_on_save`
value takes precedence over the editor's language-specific `formatOnSave`.
An explicit tooling `lint_on_save` value takes precedence over language defaults;
the global `:LintDisable` switch still disables automatic linting.

## Reload

Run `:ProjectSettingsReload` after editing editor/tooling JSON. It clears caches,
refreshes open buffers, and restores tool definitions before reinstalling project
overrides on demand. Removed project filetype/indentation overrides return to
Neovim defaults. Manual filetypes are preserved when no project association
applies. Existing LSP clients require a restart to load changed LSP settings.

## PHP debugging with native nvim-dap

The PHP adapter is already configured through Mason. Create this standard JSON
file at `<workspace>/.vscode/launch.json`. Replace the example server path with
your remote application's source directory:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "php",
      "request": "launch",
      "name": "Listen for Xdebug",
      "port": 9000,
      "pathMappings": {
        "/var/www/app": "${workspaceFolder}"
      }
    }
  ]
}
```

Start Neovim from the workspace root, or set `:tcd /path/to/workspace`, then press
F5 and choose `Listen for Xdebug`. Both native launch discovery and
`${workspaceFolder}` use Neovim's current directory, independently of the editor
settings root. Use port 9003 instead when Xdebug is configured for that port.

nvim-dap reads launch profiles when starting a new debug session. No custom
loader, `load_launchjs()` call, codesettings bridge, or project reload is needed.
See [nvim-dap documentation](https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt)
and [PHP adapter settings](https://github.com/xdebug/vscode-php-debug#supported-launchjson-settings).
