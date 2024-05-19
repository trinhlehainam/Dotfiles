#!/bin/bash

# Define chezmoi directories
chezmoi_config_dir="$HOME/.local/share/chezmoi/home"
templates_dir="$chezmoi_config_dir/.chezmoitemplates/nvim"

create_template() {
  local chezmoi_config_dir="$1"
  template_file="${2#$chezmoi_config_dir/.chezmoitemplates/}"
  if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    target_file="$chezmoi_config_dir/AppData/Local/$template_file.tmpl"
  else
    target_file="$chezmoi_config_dir/dot_config/dot_$template_file.tmpl"
  fi
  target_dir="$(dirname "$target_file")"
  mkdir -p "$target_dir"
  if [ ! -f "$target_file" ]; then
    touch "$target_file"
  fi
  # Avoid chezmoi template checking
  template_string="- template \"$template_file\" . -"
  template_string="{$template_string}"
  template_string="{$template_string}"
  #
  echo "$template_string" > "$target_file"
}

export -f create_template
# Create the chezmoi managed files to use the templates
find "$templates_dir" -type f -exec sh -c '
  create_template "$1" "$2"
' sh "$chezmoi_config_dir" {} \;

# Apply chezmoi configuration
# chezmoi apply
