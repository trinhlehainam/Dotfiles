#!/bin/bash

# NOTE: Required tools: 
#   - find: File finder
#   - read: Read from stdin
#   - stat: File metadata processor
#   - dirname: Path processor
#   - sed: Text processor
#   - jq: JSON processor
#   - chezmoi: Template processor
REQUIRED_TOOLS=("find" "read" "stat" "dirname" "sed" "jq" "chezmoi")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! type "$tool" &> /dev/null; then
        echo "Error: $tool is not installed."
        exit 1
    fi
done

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
chezmoi_root_dir="$HOME/.local/share/chezmoi/home"
templates_dir="$chezmoi_root_dir/.chezmoitemplates/nvim"
state_file="$templates_dir/state.json"

new_template() {
  local chezmoi_root_dir="$1"
  template_file="${2#$chezmoi_root_dir/.chezmoitemplates/}"
  if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    target_file="$chezmoi_root_dir/AppData/Local/$template_file.tmpl"
  else
    target_file="$chezmoi_root_dir/dot_config/$template_file.tmpl"
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

# Function to remove a template
remove_template() {
    local chezmoi_root_dir=$1
    local template_file=$2
    
    if [ "$OSTYPE" == "msys" ]; then
        target_file="$chezmoi_root_dir/AppData/Local/$template_file.tmpl"
    else
        target_file="$chezmoi_root_dir/dot_config/$template_file.tmpl"
    fi
    
    if [ -f "$target_file" ]; then
        destination_file="${template_file#nvim/}"
        destination_file="$nvim_config_dir/$destination_file"
        chezmoi remove --force $destination_file
    fi
}

# Load previous state if it exists
declare -A previous_state
if [ -f "$state_file" ]; then
    json_data=$(cat "$state_file")
    while IFS="=" read -r key value; do
        # Convert the file path to the desired format from "\\path\\to\\file" to "/path/to/file"
        file_path=$(sed 's/\\/\//g' <<< "$key")
        previous_state[$file_path]="$value"
    done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' <<< "$json_data")
fi

# Get current state
declare -A current_state
while IFS= read -r -d '' file; do
    template_file=${file#$chezmoi_root_dir/.chezmoitemplates/}
    # Ignore create template for state.json file
    if [[ "$template_file" == *"state.json"* ]]; then
        continue
    fi
    current_state["$template_file"]=$(stat -c %Y "$file")
done < <(find "$templates_dir" -type f -print0)

# Detect added files
for file in "${!current_state[@]}"; do
    if [ ! "${previous_state[$file]+exists}" ]; then
        echo "Creating template for: $file"
        new_template "$chezmoi_root_dir" "$file"
    fi
done

# Detect deleted files
for file in "${!previous_state[@]}"; do
    if [ ! "${current_state[$file]+exists}" ]; then
        echo "Removing template for: $file"
        remove_template "$chezmoi_root_dir" "$file"
    fi
done

hashtable_to_json() {
    local -n hashtable=$1
    local json="{"

    for key in "${!hashtable[@]}"; do
        # Extract the file path and timestamp from the input JSON pattern
        file_path=$key
        timestamp=${hashtable[$key]}
        # Convert the file path to the desired format from "/path/to/file" to "\\path\\to\\file"
        converted_file_path=$(sed 's/\//\\\\/g' <<< "$file_path")
        timestamp="Date($timestamp)"
        # Construct the output JSON pattern
        output_json="\"$converted_file_path\":\"$timestamp\""

        json="$json$output_json,"
    done

    # Remove the last comma
    json="${json%,}"

    json="$json}"

    echo "$json"
}

# Save current state
result_json=$(hashtable_to_json current_state)
echo "$result_json" | jq -c . > "$state_file"
