# Project settings

Create only the files you need:

| File | Configure |
| --- | --- |
| `.vscode/settings.json` | LSP settings, filetypes, indentation, format on save |
| `.nvim/tooling.json` | Formatters, linters, arguments, save behavior |
| `.vscode/launch.json` | Debugging with nvim-dap |

For each file, editor and tooling settings come from the nearest enclosing directory with `.git`, `.jj`, `.nvim`, or `.vscode`. All markers have equal priority. Nested projects use their own settings without inheriting parent settings. LSP settings load from each language server's root when it starts.

## Editor settings

Create `.vscode/settings.json`. Comments and trailing commas are allowed:

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

The four `editor.*` options shown above must be inside a language block such as `[php]`; top-level defaults are not supported.

- Use Neovim filetype names, which may differ from VS Code language names. Check the current file with `:set filetype?`.
- Use `[html][php]` to share settings across languages. For a compound filetype such as `html.php`, settings apply in order: `html`, `php`, then `html.php`.
- Set `editor.tabSize` to an integer from 1 to 9999. Invalid values produce a warning and are ignored.
- Explicit indentation values override indentation detection plugins. Setting `editor.detectIndentation` to `false` restores filetype defaults before applying those values; `true` alone does not run a detector.

### File associations

Use `files.associations` to assign filetypes by filename or path. Patterns support `*`, `**`, `?`, braces, and character classes.

- Patterns without `/` match the filename; patterns with `/` match the path relative to the project root.
- Exact filenames win over other glob patterns, which win over simple `*.ext` rules. Ties within each group favor longer patterns, then descending lexical order.
- Neovim's built-in detection still works outside matching projects and after an association is removed.

## Formatter and linter settings

Create `.nvim/tooling.json` using standard JSON, without comments or trailing commas:

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

This example disables formatting on save for PHP while keeping linting on save enabled.

- Use Conform formatter names and nvim-lint linter names. Install their executables separately.
- Tool lists add to globally configured tools. An empty list does not disable them.
- Use `args` to replace arguments or `args_append` to add arguments. Existing formatter definitions and inheritance are preserved, including custom formatters.
- `filetypes` values override `defaults`. For a compound filetype such as `html.php`, settings apply in order: `html`, `php`, then `html.php`.
- A tooling `format_on_save` value overrides the editor's `editor.formatOnSave`. A tooling `lint_on_save` value overrides language defaults, but `:LintDisable` still disables automatic linting.

## Apply settings changes

After editing `.vscode/settings.json` or `.nvim/tooling.json`, run:

```vim
:ProjectSettingsReload
```

This refreshes open buffers and clears cached settings and tool overrides. Removing project filetype or indentation settings restores Neovim defaults. Manually selected filetypes are kept when no project association applies.

Restart language servers to apply changed LSP settings. Debug profiles reload separately when a new session starts.

## PHP debugging

The PHP debug adapter is already configured through Mason. Create `.vscode/launch.json` in your workspace using standard JSON:

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

To use the example:

1. Replace `/var/www/app` with the source path on the server. The value is the matching local directory; use `${workspaceFolder}/src` if your source lives in a `src` subdirectory.
2. Match `port` to your Xdebug configuration; use `9003` if Xdebug is configured to connect to that port.
3. Start Neovim from the workspace root, or run `:tcd /path/to/workspace`.
4. Open a PHP file, press F5, and choose `Listen for Xdebug` if prompted.

Both `.vscode/launch.json` discovery and `${workspaceFolder}` use Neovim's current directory, independently of the editor settings root. nvim-dap reads the file when starting a new session; no custom Lua loader, codesettings integration, or `:ProjectSettingsReload` is needed.

For more options, see the [nvim-dap documentation](https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt) and [PHP adapter settings](https://github.com/xdebug/vscode-php-debug#supported-launchjson-settings).
