# Cross-Platform Development Dotfiles

A comprehensive [chezmoi](https://chezmoi.io/) dotfiles repository for managing cross-platform development configurations. This repository provides a unified setup for development tools across Windows, macOS, and Linux environments.

## Features

- **Cross-Platform Support**: Configurations that work seamlessly across Windows, macOS, and Linux
- **Template-Based**: Leverages chezmoi's templating system for dynamic configuration generation
- **Modular Architecture**: Well-organized, modular configurations for easy maintenance
- **Development-Focused**: Optimized for software development workflows

## Tools & Configurations Included

### Editors & IDEs
- **Neovim**: Comprehensive Lua-based configuration with LSP, DAP, and extensive plugin ecosystem
- **VS Code**: Keybindings and settings for consistent editor experience
- **IntelliJ IDEA**: Vim keybindings via IdeaVim configuration
- **Windsurf**: Editor keybindings and configuration

### Terminal & Shell
- **WezTerm**: Feature-rich terminal emulator with modular configuration
- **Nushell**: Modern shell with structured data processing
- **PowerShell**: Cross-platform PowerShell profiles
- **Bash**: Traditional shell configuration with aliases

### Development Tools
- **Git**: GitHub CLI dashboard configuration
- **Tmux**: Terminal multiplexer configuration
- **Yazi**: Modern file manager with custom keybindings
- **Docker**: Lazy Docker configuration for container management

### Code Quality & Formatting
- **Stylua**: Lua code formatting for WezTerm configs
- **Luacheck**: Lua linting configuration

## Prerequisites

- [chezmoi](https://chezmoi.io/) installed on your system
- Git for repository management
- Platform-specific package managers (optional):
  - Windows: winget, chocolatey
  - macOS: homebrew
  - Linux: distribution package manager

## Installation

1. **Clone the repository** (if not already done):
   ```bash
   chezmoi init https://github.com/trinhlehainam/Dotfiles.git
   ```

2. **Review changes before applying**:
   ```bash
   chezmoi diff
   ```

3. **Apply the dotfiles**:
   ```bash
   chezmoi apply
   ```

4. **For Windows users**: Consider using the `winutil.json` for automated tool installation

## Directory Structure

```
├── home/                          # Files that go to user home directory
│   ├── dot_config/               # XDG config directory (~/.config)
│   │   ├── nvim/                 # Neovim configuration
│   │   │   ├── lua/configs/      # Core configuration modules
│   │   │   ├── lua/plugins/      # Plugin configurations
│   │   │   └── queries/          # Treesitter queries
│   │   ├── wezterm/              # WezTerm terminal configuration
│   │   │   ├── config/           # Core config modules
│   │   │   ├── events/           # Event handlers
│   │   │   ├── utils/            # Utility functions
│   │   │   └── backdrops/        # Background images
│   │   ├── nushell/              # Nushell configuration
│   │   └── yazi/                 # Yazi file manager
│   ├── AppData/                  # Windows-specific configs
│   └── Documents/                # PowerShell profiles
├── scripts/                      # Automation scripts
│   ├── unix/                     # Unix/Linux scripts
│   └── windows/                  # Windows PowerShell scripts
└── winutil.json                  # Windows package installation config
```

## Key Commands

### Chezmoi Operations
```bash
# Apply configuration changes
chezmoi apply

# Show differences between source and target
chezmoi diff

# Add a new file to chezmoi management
chezmoi add <file>

# Edit a managed file
chezmoi edit <file>

# Show available template data
chezmoi data

# Check for configuration issues
chezmoi doctor
```

### Development Tools
```bash
# Format WezTerm Lua code
stylua home/dot_config/wezterm/

# Lint WezTerm Lua code
luacheck home/dot_config/wezterm/
```

## Configuration Scripts

### Neovim Migration Scripts

The repository includes scripts to migrate existing Neovim configurations:

- **Unix/Linux/macOS**: `scripts/unix/copy-nvim-config-from-os.sh`
- **Windows**: `scripts/windows/copy-nvim-config-from-os.ps1`

These scripts copy your existing Neovim configuration and convert it to chezmoi's template format.

## Customization

### Template Variables
The configurations use chezmoi's template system. You can customize behavior by:

1. **Editing template data**: Use `chezmoi data` to see available variables
2. **Platform-specific configs**: Templates automatically adapt to your OS
3. **Environment variables**: Many configs can be customized via environment variables

### Neovim Configuration
- **LSP configurations**: Located in `home/dot_config/nvim/lua/configs/lsp/`
- **Plugin configs**: Split between `lua/configs/plugins/` and `lua/plugins/`
- **Keymaps**: Centralized in `lua/configs/keymaps.lua.tmpl`

### WezTerm Configuration
- **Appearance**: `config/appearance.lua`
- **Keybindings**: `config/bindings.lua`
- **Fonts**: `config/fonts.lua`
- **Events**: Custom event handlers in `events/`

## Windows Automation

The `winutil.json` file provides automated installation of development tools using winget and chocolatey. It includes:

- Programming languages (Rust, etc.)
- Development environments (Visual Studio, etc.)
- Essential development tools

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test across different platforms if possible
5. Submit a pull request

## Troubleshooting

### Common Issues

**Templates not rendering correctly**:
- Check `chezmoi data` for available variables
- Verify template syntax in `.tmpl` files

**Neovim plugins not loading**:
- Ensure lazy.nvim is properly installed
- Check LSP configurations match your development environment

**WezTerm configuration errors**:
- Validate Lua syntax with `luacheck`
- Check event handler configurations in `events/`

**Cross-platform issues**:
- Review platform-specific template conditionals
- Check file paths for OS compatibility

### Getting Help

- Review `chezmoi doctor` output for configuration issues
- Check individual tool documentation for specific problems
- Ensure all prerequisites are installed for your platform

## License

This dotfiles repository is provided as-is for personal and educational use. Individual tool configurations may have their own licensing terms.
