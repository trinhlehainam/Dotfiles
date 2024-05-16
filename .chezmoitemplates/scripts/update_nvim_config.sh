#!/bin/bash

# Determine the operating system
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  nvim_config_dir="$HOME/.config/nvim"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  nvim_config_dir="$HOME/.config/nvim"
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
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

# Create the chezmoi managed files to use the templates
find "$templates_dir" -type f -exec sh -c '
  chezmoi_config_dir="$1"
  template_file="${2#$chezmoi_config_dir/.chezmoitemplates/}"
  target_file="$chezmoi_config_dir/dot_$template_file.tmpl"
  target_dir="$(dirname "$target_file")"
  mkdir -p "$target_dir"
  if [ ! -f "$target_file" ]; then
    touch "$target_file"
  fi
  echo "{{ template \"$template_file\" . }}" > "$target_file"
' sh "$chezmoi_config_dir" {} \;

# Apply chezmoi configuration
chezmoi apply
