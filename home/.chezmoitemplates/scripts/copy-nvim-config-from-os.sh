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

shopt -s dotglob

copy_and_rename() {
    local src_dir="$1"
    local dest_dir="$2"

    for file in "$src_dir"/*; do
        if [[ -d "$file" ]]; then
            # Create corresponding directory in the destination
            local subdir=$(basename "$file")
            mkdir -p "$dest_dir/$subdir"
            # Recursively copy and rename inside the subdirectory
            copy_and_rename "$file" "$dest_dir/$subdir"
        elif [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            if [[ $filename == .* ]]; then
                local new_filename="dot_${filename:1}"
                cp "$file" "$dest_dir/$new_filename"
                echo "Copied and renamed $filename to $new_filename"
            else
                cp "$file" "$dest_dir/$filename"
                echo "Copied $filename"
            fi
        fi
    done
}

copy_and_rename "$nvim_config_dir" "$templates_dir"
