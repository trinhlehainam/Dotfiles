# Dotfiles

Cross-platform development configurations managed with [chezmoi](https://chezmoi.io/).

## Quick Start

```bash
# Install
chezmoi init https://github.com/trinhlehainam/Dotfiles.git

# Preview changes
chezmoi diff

# Apply
chezmoi apply
```

## What's Included

| Category | Tools |
|----------|-------|
| Editor | Neovim (LSP, DAP, lazy.nvim), VS Code, IdeaVim |
| Terminal | WezTerm, Nushell, PowerShell, Bash, Tmux |
| Tools | Yazi, Lazydocker, gh-dash |

## Structure

```
home/
  .chezmoitemplates/nvim/   # Neovim source templates
  dot_config/
    wezterm/                # Terminal config
    nushell/                # Shell config
  AppData/                  # Windows configs
```

## Key Points

- **Neovim configs**: Edit in `home/.chezmoitemplates/nvim/`, not `dot_config/nvim/`
- **WezTerm configs**: Edit directly in `home/dot_config/wezterm/`
- **Templates**: Files ending in `.tmpl` are processed by chezmoi

## Commands

```bash
chezmoi apply -v      # Apply with verbose output
chezmoi doctor        # Check for issues
stylua <path>         # Format Lua code
```

## Requirements

- [chezmoi](https://chezmoi.io/)
- Git
- Platform package manager (homebrew, winget, apt, etc.)
