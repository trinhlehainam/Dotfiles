# Determine the operating system
if ($env:OS -match "Windows_NT") {
    $nvim_config_dir = "$env:USERPROFILE\AppData\Local\nvim"
} else {
    Write-Host "Unsupported OS: $($PSVersionTable.OS)"
    exit 1
}

# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"

# Ensure the templates directory exists
if (-not (Test-Path $templates_dir)) {
    New-Item -ItemType Directory -Force -Path $templates_dir
}

function Copy-And-Rename {
    param (
        [string]$src_dir,
        [string]$dest_dir
    )

    Get-ChildItem -Path $src_dir -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            # Create corresponding directory in the destination
            $subdir = $_.Name
            if (-not (Test-Path "$dest_dir\$subdir")) {
                New-Item -ItemType Directory -Force -Path "$dest_dir\$subdir"
            }
            # Recursively copy and rename inside the subdirectory
            Copy-And-Rename -src_dir $_.FullName -dest_dir "$dest_dir\$subdir"
        } else {
            $filename = $_.Name
            if ($filename -match "^\.") {
                $new_filename = "dot_$($filename.Substring(1))"
                Copy-Item -Path $_.FullName -Destination "$dest_dir\$new_filename"
                Write-Host "Copied and renamed $filename to $new_filename"
            } else {
                Copy-Item -Path $_.FullName -Destination "$dest_dir\$filename"
                Write-Host "Copied $filename"
            }
        }
    }
}

Copy-And-Rename -src_dir $nvim_config_dir -dest_dir $templates_dir
