# Determine the operating system
if ($env:OS -match "Windows_NT") {
    # Windows OS
    $nvim_config_dir = "$env:USERPROFILE\AppData\Local\nvim"
} else {
    Write-Host "Unsupported OS: $($PSVersionTable.OS)"
    exit 1
}

# Define chezmoi directories
$chezmoi_config_dir = "$env:USERPROFILE\.local\share\chezmoi"
$templates_dir = "$chezmoi_config_dir\.chezmoitemplates\nvim"

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

function Create-Template {
    param (
        [string]$chezmoi_config_dir,
        [string]$template_file
    )

    if ($env:OS -match "Windows_NT") {
        $target_file = "$chezmoi_config_dir\AppData\Local\$template_file.tmpl"
    } else {
        $target_file = "$chezmoi_config_dir/dot_config/dot_$template_file.tmpl"
    }
    $target_dir = [System.IO.Path]::GetDirectoryName($target_file)
    if (-not (Test-Path $target_dir)) {
        New-Item -ItemType Directory -Force -Path $target_dir
    }
    if (-not (Test-Path $target_file)) {
        New-Item -ItemType File -Force -Path $target_file
    }
    # Avoid chezmoi template checking
    $template_string = " template `"$template_file`" . "
    $template_string = "{$template_string}"
    $template_string = "{$template_string}"
    $template_string = $template_string.Replace("\", "/")
    #
    $template_string | Set-Content -Path $target_file
}

# Create the chezmoi managed files to use the templates
Get-ChildItem -Path $templates_dir -File -Recurse | ForEach-Object {
    $template_file = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    Create-Template -chezmoi_config_dir $chezmoi_config_dir -template_file $template_file
}

# Apply chezmoi configuration
# chezmoi apply
