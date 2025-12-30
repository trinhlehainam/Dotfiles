# Dotfiles

Cross-platform dev configs managed with [chezmoi](https://chezmoi.io/).

## Quick Start

```bash
chezmoi init https://github.com/trinhlehainam/Dotfiles.git
chezmoi diff
chezmoi apply
```

## Where To Edit

- Neovim source of truth: `home/.chezmoitemplates/nvim/`
- Neovim generated templates: `home/dot_config/nvim/**.tmpl` (avoid hand-editing)
- WezTerm: `home/dot_config/wezterm/`
- Windows app configs: `home/AppData/`

## Layout

```text
home/
  .chezmoitemplates/nvim/   # Neovim source
  dot_config/               # Unix app configs (chezmoi-managed)
  AppData/                  # Windows app configs (chezmoi-managed)
```

## Requirements

- chezmoi + git
- A package manager (brew/winget/apt/…)
