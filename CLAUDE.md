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

### Neovim Configuration
- Scripts for syncing Neovim configs are in `scripts/`:
  - `scripts/unix/copy-nvim-config-from-os.sh` - Copy existing Neovim config on Unix systems
  - `scripts/windows/copy-nvim-config-from-os.ps1` - Copy existing Neovim config on Windows

### Lua Development (WezTerm)
- `stylua` for code formatting (config: `home/dot_config/wezterm/dot_stylua.toml`)
- `luacheck` for linting (config: `home/dot_config/wezterm/dot_luacheckrc`)
- Style settings: 100 column width, 3-space indentation, single quotes preferred

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

### Template System
Files ending in `.tmpl` are chezmoi templates that can use Go template syntax with access to:
- OS/platform detection
- Environment variables  
- Custom template data
- Conditional includes based on system type

### Cross-Platform Support
The configuration supports Windows, macOS, and Linux with platform-specific adaptations handled through chezmoi templating and conditional logic in setup scripts.