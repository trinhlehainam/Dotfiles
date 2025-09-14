#!/bin/bash

# Require Bash 4+ for associative arrays (macOS default bash is 3.2)
if [[ -z "${BASH_VERSINFO:-}" || ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "[ERROR] Bash 4+ required; on macOS, install newer bash (e.g., brew install bash) and run this script with it." >&2
  exit 1
fi

# Initialize variables
DRY_RUN=false
LOG_LEVEL="info"

# Parse CHEZMOI_ARGS
if [[ -n "${CHEZMOI_ARGS:-}" ]]; then
	eval "set -- $CHEZMOI_ARGS"

		# Skip the first argument (chezmoi executable path)
		shift

		# Parse remaining arguments
		while [[ $# -gt 0 ]]; do
			case "$1" in
				-v|--verbose)
					LOG_LEVEL="debug"
					;;
				-n|--dry-run)
					DRY_RUN=true
					;;
				--debug)
					LOG_LEVEL="debug"
					;;
				*)
					# Skip other arguments
					;;
			esac
			shift
		done
fi

# Function to check if a log level should be displayed
can_log() {
	local level="$1"
	case "$LOG_LEVEL" in
		"debug")
			return 0  # Log everything
			;;
		"error")
			[[ "$level" == "ERROR" ]]
			;;
		"warn")
			[[ "$level" == "ERROR" || "$level" == "WARN" ]]
			;;
		"info")
			[[ "$level" == "ERROR" || "$level" == "WARN" || "$level" == "INFO" ]]
			;;
		*)
			# Fallback to info if an unknown level is set
			[[ "$level" == "ERROR" || "$level" == "WARN" || "$level" == "INFO" ]]
			;;
	esac
}

# Main logging function
log() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	if ! can_log "$level"; then
		return
	fi

	case "$level" in
		"ERROR")
			echo "[$timestamp] ERROR: $message" >&2
			;;
		"WARN")
			echo "[$timestamp] WARN: $message" >&2
			;;
		"INFO")
			echo "[$timestamp] INFO: $message"
			;;
		"DEBUG")
			echo "[$timestamp] DEBUG: $message"
			;;
	esac
}

# Dedicated logging methods
log_error() {
	log "ERROR" "$1"
}

log_warn() {
	log "WARN" "$1"
}

log_info() {
	log "INFO" "$1"
}

log_debug() {
	log "DEBUG" "$1"
}

# NOTE: Required tools:
#   - find: File finder
#   - basename: Path processor
#   - stat: File metadata processor
#   - dirname: Path processor
#   - sed: Text processor
#   - jq: JSON processor
#   - chezmoi: Template processor
REQUIRED_TOOLS=("find" "basename" "stat" "dirname" "sed" "jq" "chezmoi")
for tool in "${REQUIRED_TOOLS[@]}"; do
	if ! command -v "$tool" &>/dev/null; then
		log_error "$tool is not installed"
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
	log_error "Unsupported OS $OSTYPE"
	exit 1
fi

# Define chezmoi directories
chezmoi_root_dir="$HOME/.local/share/chezmoi/home"
templates_dir="$chezmoi_root_dir/.chezmoitemplates/nvim"
state_file="$templates_dir/state.json"

log_debug "Configuration loaded: LOG_LEVEL=$LOG_LEVEL, DRY_RUN=$DRY_RUN"
log_debug "Chezmoi root dir: $chezmoi_root_dir"
log_debug "Templates dir: $templates_dir"
log_debug "State file: $state_file"

validate_template_file() {
	local file=$1

	if [ "$file" = "" ]; then
		log_debug "No template file provided"
		return 1
	fi

	if [ ! -f "$file" ]; then
		log_debug "Template file does not exist"
		return 1
	fi

	if [[ "$file" != "$chezmoi_root_dir"/.chezmoitemplates/* ]]; then
		log_debug "Template file is not inside $chezmoi_root_dir/.chezmoitemplates/ folder ${file}"
		return 1
	fi

	local base_name
	base_name=$(basename "$file")

	# file start with "."
	if [[ "$base_name" =~ ^\. ]]; then
		log_debug "Template file ${base_name} starts with ."
		return 1
	fi

	if [[ "$base_name" == "state.json" ]]; then
		log_debug "Template file name is state.json"
		return 1
	fi

	return 0
}

new_template() {
	if ! validate_template_file "$2"; then
		log_warn "Invalid template file $2"
		log_debug "Skip creating template for $2"
		return 1
	fi
	local chezmoi_root_dir="$1"
	# Trip the "$chezmoi_root_dir"/.chezmoitemplates/ prefix path
	local template_file="${2#"$chezmoi_root_dir"/.chezmoitemplates/}"
	if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
		target_file="$chezmoi_root_dir/AppData/Local/$template_file.tmpl"
	else
		target_file="$chezmoi_root_dir/dot_config/$template_file.tmpl"
	fi
	target_dir="$(dirname "$target_file")"

	log_debug "Creating template: $template_file -> $target_file"

	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would create template: $target_file"
		return 0
	fi

	mkdir -p "$target_dir"
	if [ ! -f "$target_file" ]; then
		touch "$target_file"
	fi
	# Avoid chezmoi template checking
	template_string="- template \"$template_file\" . -"
	template_string="{$template_string}"
	template_string="{$template_string}"
	#
	echo "$template_string" >"$target_file"
	return 0
}

# Function to remove a template
remove_template() {
	local chezmoi_root_dir=$1
	local template_file=$2

	if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
		target_file="$chezmoi_root_dir/AppData/Local/$template_file.tmpl"
	else
		target_file="$chezmoi_root_dir/dot_config/$template_file.tmpl"
	fi

	if [ ! -f "$target_file" ]; then
		return 1
	fi

	destination_file="${template_file#nvim/}"
	destination_file="$nvim_config_dir/$destination_file"

	log_debug "Removing template: $template_file -> $target_file"

	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would remove template: $target_file and destroy: $destination_file"
		return 0
	fi

	chezmoi destroy --force "$destination_file"

	return 0
}
# Load previous state if it exists
declare -A previous_state
if [ -f "$state_file" ]; then
	json_data=$(cat "$state_file")
	while IFS="=" read -r key value; do
		# Convert the file path to the desired format from "\\path\\to\\file" to "/path/to/file"
		file_path=$(sed 's/\\/\//g' <<<"$key")
		previous_state[$file_path]="$value"
	done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' <<<"$json_data")
fi

# Get current state
declare -A current_state
# Cross-platform mtime
# stat -c %Y fails on macOS; use an OS-aware helper.
file_mtime() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		stat -f %m -- "$1"
	else
		stat -c %Y -- "$1"
	fi
}
while IFS= read -r -d '' file; do
	# Ignore files that are not templates
	if ! validate_template_file "$file"; then
		log_debug "Ignoring tracking template file \"$file\" state in \"state.json\""
		continue
	fi
	# Trip the "$chezmoi_root_dir"/.chezmoitemplates/ prefix path
	template_file=${file#"$chezmoi_root_dir"/.chezmoitemplates/}
	current_state["$template_file"]=$(file_mtime "$file")
done < <(find "$templates_dir" -type f -print0)

# Detect added files
for file in "${!current_state[@]}"; do
	if [ ! "${previous_state[$file]+exists}" ]; then
		template_file="$chezmoi_root_dir/.chezmoitemplates/$file"
		if new_template "$chezmoi_root_dir" "$template_file"; then
			log_info "Template for $file created"
		fi
	fi
done

# Detect deleted files
for file in "${!previous_state[@]}"; do
	if [ ! "${current_state[$file]+exists}" ]; then
		if remove_template "$chezmoi_root_dir" "$file"; then
			log_info "Template for $file removed"
		fi
	fi
done

hashtable_to_json() {
	local -n hashtable="$1"
	local json="{"

	for key in "${!hashtable[@]}"; do
		# Extract the file path and timestamp from the input JSON pattern
		file_path=$key
		timestamp=${hashtable[$key]}
		# Convert the file path to the desired format from "/path/to/file" to "\\path\\to\\file"
		converted_file_path=$(sed 's/\//\\\\/g' <<<"$file_path")
		timestamp="Date($timestamp)"
		# Construct the output JSON pattern
		output_json="\"$converted_file_path\":\"$timestamp\""

		json="$json$output_json,"
	done

	# Remove the last comma
	json="${json%,}"

	json="$json}"

	# Output result to stdout
	echo "$json"
}

# Save current state
result_json=$(hashtable_to_json current_state)
echo "$result_json" | jq -c . >"$state_file"
