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
$CHEZMOI_ROOT_DIR = "$env:USERPROFILE\.local\share\chezmoi\home"
$TEMPLATES_DIR = "$CHEZMOI_ROOT_DIR\.chezmoitemplates\nvim"
$STATE_FILE = "$templates_dir\state.json"

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

    # file not inside $CHEZMOI_ROOT_DIR"/.chezmoitemplates/ folder
    if (-not $File.StartsWith("$CHEZMOI_ROOT_DIR\.chezmoitemplates\"))
    {
        Write-Log -Level "Warn" -Message "Template file is not inside $CHEZMOI_ROOT_DIR/.chezmoitemplates/ folder $File"
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
        [string]$ChezmoiRootDir,
        [string]$TemplateFile
    )

    if ($env:OS -match "Windows_NT")
    {
        $targetFile = "$ChezmoiRootDir\AppData\Local\$TemplateFile.tmpl"
    } else
    {
        $targetFile = "$ChezmoiRootDir/dot_config/dot_$TemplateFile.tmpl"
    }

    $targetDir = [System.IO.Path]::GetDirectoryName($targetFile)
    if (-not (Test-Path $targetDir))
    {
        New-Item -ItemType Directory -Force -Path $targetDir
    }
    if (-not (Test-Path $targetFile))
    {
        New-Item -ItemType File -Force -Path $targetFile
    }
    # Avoid chezmoi template checking
    $templateString = "- template `"$TemplateFile`" . -"
    $templateString = "{$templateString}"
    $templateString = "{$templateString}"
    $templateString = $templateString.Replace("\", "/")
    #
    if (-not ($templateString | Set-Content -Path $targetFile))
    {
        Write-Log -Level "Warn" -Message "Failed to create template file $targetFile"
        return $false
    }

    return $true
}

function Remove-Template
{
    param (
        [string]$ChezmoiRootDir,
        [string]$TemplateFile
    )

    if ($env:OS -match "Windows_NT")
    {
        $targetFile = "$CHEZMOI_ROOT_DIR\AppData\Local\$TemplateFile.tmpl"
    } else
    {
        $targetFile = "$CHEZMOI_ROOT_DIR/dot_config/$TemplateFile.tmpl"
    }
    
    if (-not (Test-Path $targetFile))
    {
        Write-Log -Level "Warn" -Message "Skipping removing non-existing template file $targetFile"
        return $false
    }

    $destinationFile = $template_file.Substring("nvim".Length + 1) 
    $destinationFile = "$nvim_config_dir\$destinationFile"
    chezmoi destroy --force $destinationFile
    
    return $true
}

# Load previous state if it exists
$PREVIOUS_STATE = @{}
if (Test-Path $STATE_FILE)
{
    $json = Get-Content -Path $STATE_FILE | ConvertFrom-Json
    # ConvertFrom-Json -AsHashtable somehow doesn't work
    # Add properties manually to hashtable
    $json.psobject.properties | ForEach-Object {
        $PREVIOUS_STATE.Add($_.Name, $_.Value)
    }
}

# Get current state
$CURRENT_STATE = @{}
Get-ChildItem -Path $TEMPLATES_DIR -File -Recurse | ForEach-Object {
    if (-not (Confirm-TemplateFile -file $_.FullName))
    {
        Write-Log -Level "Warn" -Message "Ignoring tracking template file `"$_`" in `"state.json`""
        return
    }
    $templateFile = $_.FullName.Substring($templates_dir.Length - "nvim".Length)
    $timestamp = Get-Date $_.LastWriteTime
    $timestamp = ([DateTimeOffset]$timestamp).ToUnixTimeSeconds()
    $timestamp = "Date($timestamp)"
    $CURRENT_STATE.Add($templateFile, $timestamp)
}

# Detect added files
foreach ($file in $CURRENT_STATE.Keys)
{
    if (-not $PREVIOUS_STATE.ContainsKey($file))
    {
        if (New-Template -ChezmoiRootDir $CHEZMOI_ROOT_DIR -TemplateFile $file)
        {
            Write-Log -Level "Info" -Message "Template file $file created"
        }     
    }
}

# Detect deleted files
foreach ($file in $PREVIOUS_STATE.Keys)
{
    if (-not $CURRENT_STATE.ContainsKey($file))
    {
        if (Remove-Template -ChezmoiRootDir $CHEZMOI_ROOT_DIR -TemplateFile $file)
        {
            Write-Log -Level "Info" -Message "Template file $file removed"
        }
    }
}

# Save current state
$CURRENT_STATE | ConvertTo-Json -Compress | Set-Content -Path $STATE_FILE
