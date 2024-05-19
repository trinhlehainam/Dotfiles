# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"
$state_file = "$chezmoi_root_dir\.chezmoitemplates\nvim\state.json"

function Create-Template {
    param (
        [string]$chezmoi_root_dir,
        [string]$template_file
    )

    if ($env:OS -match "Windows_NT") {
        $target_file = "$chezmoi_root_dir\AppData\Local\$template_file.tmpl"
    } else {
        $target_file = "$chezmoi_root_dir/dot_config/dot_$template_file.tmpl"
    }
    $target_dir = [System.IO.Path]::GetDirectoryName($target_file)
    if (-not (Test-Path $target_dir)) {
        New-Item -ItemType Directory -Force -Path $target_dir
    }
    if (-not (Test-Path $target_file)) {
        New-Item -ItemType File -Force -Path $target_file
    }
    # Avoid chezmoi template checking
    $template_string = "- template `"$template_file`" . -"
    $template_string = "{$template_string}"
    $template_string = "{$template_string}"
    #
    $template_string | Set-Content -Path $target_file
}

function Remove-Template {
    param (
        [string]$chezmoi_root_dir,
        [string]$template_file
    )

    if ($env:OS -match "Windows_NT") {
        $target_file = "$chezmoi_root_dir\AppData\Local\$template_file.tmpl"
    } else {
        $target_file = "$chezmoi_root_dir/dot_config/dot_$template_file.tmpl"
    }
    
    if (Test-Path $target_file) {
        Remove-Item -Path $target_file -Force
    }
}

# Load previous state if it exists
$previous_state = @{}
if (Test-Path $state_file) {
    $previous_state = Get-Content -Path $state_file | ConvertFrom-Json
}

# Get current state
$current_state = @{}
Get-ChildItem -Path $templates_dir -File -Recurse | ForEach-Object {
    $template_file = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    $template_file = $template_file.Replace("\", "/")
    if ($template_file.Contains("state.json")) {
        continue
    }
    $current_state[$template_file] = $_.LastWriteTime
}

# Detect added
foreach ($file in $current_state.Keys) {
    if (-not $previous_state.ContainsKey($file)) {
        Write-Host "Creating template for: $file"
        Create-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $file
    }
}

# Detect deleted files
foreach ($file in $previous_state.Keys) {
    if (-not $current_state.ContainsKey($file)) {
        Write-Host "Removing template for: $file"
        Remove-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $file
    }
}

# Save current state
$current_state | ConvertTo-Json | Set-Content -Path $state_file
