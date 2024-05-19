# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"

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
    $template_string = $template_string.Replace("\", "/")
    #
    $template_string | Set-Content -Path $target_file
}

# Create the chezmoi managed files to use the templates
Get-ChildItem -Path $templates_dir -File -Recurse | ForEach-Object {
    $template_file = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    Create-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $template_file
}

# Apply chezmoi configuration
#chezmoi apply
