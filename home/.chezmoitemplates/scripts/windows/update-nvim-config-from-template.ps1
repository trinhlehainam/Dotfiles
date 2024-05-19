# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"
$state_file = "$templates_dir\state.json"

function New-Template {
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
    $template_string = $template_string.Replace("\", "/")
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
    $json = Get-Content -Path $state_file | ConvertFrom-Json
    # ConvertFrom-Json -AsHashtable somehow doesn't work
    # Add properties manually to hashtable
    $json.psobject.properties | ForEach-Object {
        $previous_state.Add($_.Name, $_.Value)
    }
}

# Get current state
$current_state = @{}
Get-ChildItem -Path $templates_dir -File -Recurse | ForEach-Object {
    $template_file = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    # Ignore create template for state.json file
    if ($template_file.Contains("state.json")) {
        return
    }
    $timestamp = Get-Date $_.LastWriteTime
    $timestamp = ([DateTimeOffset]$timestamp).ToUnixTimeSeconds()
    $timestamp = "Date($timestamp)"
    $current_state.Add($template_file, $timestamp)
}

# Detect added files
foreach ($file in $current_state.Keys) {
    if (-not $previous_state.ContainsKey($file)) {
        Write-Host "Creating template for: $file"
        New-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $file
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
