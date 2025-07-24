# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a chezmoi dotfiles repository for managing cross-platform development configurations. The repository contains templated configuration files for various development tools and environments.

## Key Commands

### Chezmoi Operations
- `chezmoi apply` - Apply dotfiles to the system
- `chezmoi diff` - Show differences between source and target states  
- `chezmoi add <file>` - Add a file to chezmoi management
- `chezmoi edit <file>` - Edit a managed file
- `chezmoi data` - Show template data available for use in templates
- `chezmoi doctor` - Check for potential configuration issues

### Development & Testing Commands
- `stylua home/dot_config/wezterm/` - Format WezTerm Lua code
- `luacheck home/dot_config/wezterm/` - Lint WezTerm Lua code
- Style settings: 100 column width, 3-space indentation, single quotes preferred

### Neovim Template Management
- `home/.chezmoitemplates/scripts/unix/pre_apply/update-nvim-config-from-template.sh` - Automatically syncs Neovim config templates on Unix/macOS
- `home/.chezmoitemplates/scripts/windows/pre_apply/update-nvim-config-from-template.ps1` - Automatically syncs Neovim config templates on Windows
- These scripts run automatically during `chezmoi apply` to keep template references updated

## Architecture

### Directory Structure
- `home/` - Contains dotfiles that will be installed to the user's home directory
- `home/dot_config/` - XDG config directory files (prefixed with `dot_` for chezmoi)
- `scripts/` - Utility scripts for setup and maintenance
- Template files use `.tmpl` extension for chezmoi templating

### Key Configuration Areas

#### Neovim (`home/dot_config/nvim/`)
- Modular Lua-based configuration using lazy.nvim
- LSP configurations in `lua/configs/lsp/` for multiple languages
- Plugin configurations split into `lua/configs/plugins/` and `lua/plugins/`
- Separate keymaps, options, and utility modules

#### WezTerm (`home/dot_config/wezterm/`)
- Modular configuration structure with separate modules for appearance, bindings, fonts, etc.
- Event-driven setup for status bars and UI customization
- Backdrop image management system
- Cross-platform domain and launch configurations

#### Shell Configurations
- Nushell config templates for cross-platform shell setup
- PowerShell profiles for Windows environments
- Bash aliases and rc files for Unix systems

### Advanced Template Architecture

#### Template Types
- **`.tmpl` files**: Direct templates that render to target locations
- **`.chezmoitemplates/` directory**: Reusable template fragments included via `{{- template "name" . -}}` syntax

#### Template Management System
The repository uses an automated template management system for Neovim configurations:
- Templates in `home/.chezmoitemplates/nvim/` are automatically tracked
- Pre-apply scripts create `.tmpl` files that reference templates using `{{- template "nvim/path/to/file" . -}}`
- State tracking in `home/.chezmoitemplates/nvim/state.json` monitors template changes
- Added/removed templates trigger automatic creation/deletion of corresponding `.tmpl` files

#### Cross-Platform Adaptations
- **Windows**: Templates render to `AppData/Local/` structure
- **Unix/macOS**: Templates render to `.config/` structure  
- Platform detection via `$OSTYPE` in shell scripts and chezmoi's built-in OS detection
- Conditional logic handles path differences and tool availability

### Configuration Workflows

#### Adding New Neovim Configurations
1. Create template file in `home/.chezmoitemplates/nvim/`
2. Run `chezmoi apply` to trigger automatic template creation
3. The pre-apply script will create corresponding `.tmpl` file with template reference

#### Modifying Existing Configurations
1. Edit template files directly in `.chezmoitemplates/` directory
2. Changes automatically propagate via template system during `chezmoi apply`
3. No manual `.tmpl` file management required