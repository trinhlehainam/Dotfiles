param (
    [Parameter(Mandatory = $false, Position=0)]
    [AllowEmptyString()]
    [string]$ChezmoiArgs
)

# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comparison_operators?view=powershell-7.5#matching-operators
# https://www.chezmoi.io/reference/command-line-flags/global/
$isVerbose = $ChezmoiArgs -match "--verbose|-v"

function Write-Log
{
    param (
        [ValidateSet("Info", "Warn", "Err")]
        [string]$Level = "Info",
        [string]$Message
    )
    
    switch ($Level)
    {
        "Info"
        { Write-Host "INFO: $Message" 
        }
        "Warn"
        { 
            if (!$isVerbose)
            { return 
            }
            Write-Warning "WARN: $Message" 
        }
        "Err"
        { 
            Write-Error "ERROR: $Message" 
        }
    }
}

# NOTE: Required tools:
# - chezmoi: Template processor
$REQUIRED_TOOLS = @("chezmoi")

# Function to check if a command is available
function Test-Command
{
    param (
        [string]$Command
    )
    
    $commandPath = (Get-Command $Command -ErrorAction SilentlyContinue).Path
    return $null -ne $commandPath
}

foreach ($tool in $REQUIRED_TOOLS)
{
    if (-not (Test-Command -Command $tool))
    {
        Write-Log -Level "Err" -Message "$tool is not installed."
        exit 1
    }
}

# Determine the operating system
if ($env:OS -match "Windows_NT")
{
    $nvim_config_dir = "$env:USERPROFILE\AppData\Local\nvim"
} else
{
    Write-Log -Level "Err" -Message "Unsupported OS $($PSVersionTable.OS)"
    exit 1
}

# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"
$state_file = "$templates_dir\state.json"

function Confirm-TemplateFile
{
    param (
        [string]$File,
        [switch]$Verbose
    )

    if ($null -eq $File)
    {
        Write-Log -Level "Warn" -Message "Template file is empty"
        return $false
    }

    if (-not (Test-Path $File))
    {
        Write-Log -Level "Warn" -Message "Template file not found: $File"
        return $false
    }

    # file not inside $chezmoi_root_dir"/.chezmoitemplates/ folder
    if (-not $File.StartsWith("$chezmoi_root_dir\.chezmoitemplates\"))
    {
        Write-Log -Level "Warn" -Message "Template file is not inside $chezmoi_root_dir/.chezmoitemplates/ folder $File"
        return $false
    }
    
    $baseName = [System.IO.Path]::GetFileName($File)
    
    # File start with "."
    if ($baseName[0] -eq ".")
    {
        Write-Log -Level "Warn" -Message "Template file $baseName starts with ."
        return $false
    }

    if ($baseName -eq "state.json")
    {
        Write-Log -Level "Warn" -Message "Template file is state.json"
        return $false
    }

    return $true
}

function New-Template
{
    param (
        [string]$chezmoi_root_dir,
        [string]$template_file
    )

    if (-not (Confirm-TemplateFile -File $template_file))
    {
        Write-Log -Level "Warn" -Message "Skip creating template: $template_file"
        return $false
    }

    if ($env:OS -match "Windows_NT")
    {
        $target_file = "$chezmoi_root_dir\AppData\Local\$template_file.tmpl"
    } else
    {
        $target_file = "$chezmoi_root_dir/dot_config/dot_$template_file.tmpl"
    }
    $target_dir = [System.IO.Path]::GetDirectoryName($target_file)
    if (-not (Test-Path $target_dir))
    {
        New-Item -ItemType Directory -Force -Path $target_dir
    }
    if (-not (Test-Path $target_file))
    {
        New-Item -ItemType File -Force -Path $target_file
    }
    # Avoid chezmoi template checking
    $template_string = "- template `"$template_file`" . -"
    $template_string = "{$template_string}"
    $template_string = "{$template_string}"
    $template_string = $template_string.Replace("\", "/")
    #
    $template_string | Set-Content -Path $target_file
    
    return $true
}

function Remove-Template
{
    param (
        [string]$chezmoi_root_dir,
        [string]$template_file
    )

    if ($env:OS -match "Windows_NT")
    {
        $target_file = "$chezmoi_root_dir\AppData\Local\$template_file.tmpl"
    } else
    {
        $target_file = "$chezmoi_root_dir/dot_config/$template_file.tmpl"
    }
    
    if (-not (Test-Path $target_file))
    {
        Write-Log -Level "Warn" -Message "Skipping removing non-existing template file $template_file"
        return $false
    }

    $destination_file = $template_file.Substring("nvim".Length + 1) 
    $destination_file = "$nvim_config_dir\$destination_file"
    chezmoi destroy --force $destination_file
    
    return $true
}

# Load previous state if it exists
$previous_state = @{}
if (Test-Path $state_file)
{
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
    if (-not (Confirm-TemplateFile -file $_.FullName))
    {
        Write-Log -Level "Warn" -Message "Ignoring tracking template file `"$_`" in `"state.json`""
        return
    }
    $template_file = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    $timestamp = Get-Date $_.LastWriteTime
    $timestamp = ([DateTimeOffset]$timestamp).ToUnixTimeSeconds()
    $timestamp = "Date($timestamp)"
    $current_state.Add($template_file, $timestamp)
}

# Detect added files
foreach ($file in $current_state.Keys)
{
    if (-not $previous_state.ContainsKey($file))
    {
        $template_file = "$chezmoi_root_dir\.chezmoitemplates\$file"
        if (New-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $template_file)
        {
            Write-Log -Level "Info" -Message "Template file $file created"
        }
    }
}

# Detect deleted files
foreach ($file in $previous_state.Keys)
{
    if (-not $current_state.ContainsKey($file))
    {
        if (Remove-Template -chezmoi_root_dir $chezmoi_root_dir -template_file $file)
        {
            Write-Log -Level "Info" -Message "Template file $file removed"
        }
    }
}

# Save current state
$current_state | ConvertTo-Json -Compress | Set-Content -Path $state_file
