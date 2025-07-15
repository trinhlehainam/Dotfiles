set -euo pipefail

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to cleanup on exit
cleanup() {
    if [[ -n "${DOTGLOB_CHANGED:-}" ]]; then
        shopt -u dotglob
    fi
}

trap cleanup EXIT

# Determine the operating system
log "Detecting operating system..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    nvim_config_dir="$HOME/.config/nvim"
    log "Detected Linux system"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    nvim_config_dir="$HOME/.config/nvim"
    log "Detected macOS system"
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    nvim_config_dir="$HOME/AppData/Local/nvim"
    log "Detected Windows system (Cygwin/MSYS)"
else
    error_exit "Unsupported OS: $OSTYPE"
fi

# Validate source directory exists
if [[ ! -d "$nvim_config_dir" ]]; then
    error_exit "Neovim configuration directory not found: $nvim_config_dir"
fi

log "Source directory: $nvim_config_dir"

# Define chezmoi directories
chezmoi_root_dir="$HOME/.local/share/chezmoi/home"
templates_dir="$chezmoi_root_dir/.chezmoitemplates/nvim"

log "Target directory: $templates_dir"

# Ensure the templates directory exists
if ! mkdir -p "$templates_dir"; then
    error_exit "Failed to create templates directory: $templates_dir"
fi

# Enable dotglob for hidden files
shopt -s dotglob
DOTGLOB_CHANGED=1

copy_and_rename() {
    local src_dir="$1"
    local dest_dir="$2"
    local file_count=0

    if [[ ! -d "$src_dir" ]]; then
        log "WARNING: Source directory does not exist: $src_dir"
        return 1
    fi

    for file in "$src_dir"/*; do
        # Skip if no files match the glob pattern
        [[ -e "$file" ]] || continue
        
        if [[ -d "$file" ]]; then
            # Create corresponding directory in the destination
            local subdir=$(basename "$file")
            if ! mkdir -p "$dest_dir/$subdir"; then
                log "ERROR: Failed to create directory: $dest_dir/$subdir"
                continue
            fi
            # Recursively copy and rename inside the subdirectory
            copy_and_rename "$file" "$dest_dir/$subdir"
        elif [[ -f "$file" ]]; then
            local filename
            filename=$(basename "$file")
            if [[ $filename == .* ]]; then
                local new_filename="dot_${filename:1}"
                if cp "$file" "$dest_dir/$new_filename"; then
                    log "Copied and renamed $filename to $new_filename"
                    ((file_count++))
                else
                    log "ERROR: Failed to copy $filename"
                fi
            else
                if cp "$file" "$dest_dir/$filename"; then
                    log "Copied $filename"
                    ((file_count++))
                else
                    log "ERROR: Failed to copy $filename"
                fi
            fi
        elif [[ -L "$file" ]]; then
            log "WARNING: Skipping symbolic link: $file"
        fi
    done
    
    return 0
}

log "Starting copy operation..."
if copy_and_rename "$nvim_config_dir" "$templates_dir"; then
    log "Copy operation completed successfully"
else
    error_exit "Copy operation failed"
fi
