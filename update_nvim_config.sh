#!/bin/bash

# Determine the operating system
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  nvim_config_dir="$HOME/.config/nvim"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  nvim_config_dir="$HOME/.config/nvim"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  # Cygwin (POSIX compatibility layer and Linux environment emulation for Windows)
  nvim_config_dir="$HOME/AppData/Local/nvim"
elif [[ "$OSTYPE" == "msys" ]]; then
  # Git Bash (Windows)
  nvim_config_dir="$HOME/AppData/Local/nvim"
elif [[ "$OSTYPE" == "win32" ]]; then
  # Windows (rare, might need further checks)
  nvim_config_dir="$HOME/AppData/Local/nvim"
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi

# Define chezmoi directories
chezmoi_config_dir="$HOME/.local/share/chezmoi"
templates_dir="$chezmoi_config_dir/.chezmoitemplates/nvim"

# Ensure the templates directory exists
mkdir -p "$templates_dir"

# Copy the Neovim config to .chezmoitemplates
cp -r "$nvim_config_dir"/* "$templates_dir/"

# Convert files to templates
find "$templates_dir" -type f -exec sh -c 'mv "$0" "${0}.tmpl"' {} \;

# Create the chezmoi managed files to use the templates
find "$templates_dir" -type f -exec sh -c '
  template_file="${0#$chezmoi_config_dir/.chezmoitemplates/}"
  target_file="$chezmoi_config_dir/dot_${template_file%.tmpl}"
  echo "{{ template \"$template_file\" . }}" > "$target_file"
' {} \;

# Apply chezmoi configuration
chezmoi apply
