# Initialize variables
$DRY_RUN = $false
$LOG_LEVEL = "info"

# Parse CHEZMOI_ARGS environment variable
if ($env:CHEZMOI_ARGS) {
    $args = $env:CHEZMOI_ARGS -split ' '

    # Skip the first argument (chezmoi executable path)
    if ($args.Length -gt 1) {
        $args = $args[1..($args.Length - 1)]
    } else {
        $args = @()
    }

    # Parse remaining arguments
    foreach ($arg in $args) {
        switch ($arg) {
            {$_ -in "-v", "--verbose"} {
                $LOG_LEVEL = "debug"
            }
            {$_ -in "-n", "--dry-run"} {
                $DRY_RUN = $true
            }
            "--debug" {
                Write-Host "Debug mode enabled"
                $LOG_LEVEL = "debug"
            }
        }
    }
}

# Function to check if a log level should be displayed
function Test-LogLevel
{
    param (
        [string]$Level
    )

    switch ($LOG_LEVEL)
    {
        "debug" {
            return $true  # Log everything
        }
        "warn" {
            return ($Level -in "ERROR", "WARN")
        }
        "info" {
            return ($Level -in "ERROR", "WARN", "INFO")
        }
        default {
            return $false
        }
    }
}

# Main logging function
function Write-Log
{
    param (
        [ValidateSet("ERROR", "WARN", "INFO", "DEBUG")]
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if (-not (Test-LogLevel -Level $Level)) {
        return
    }

    switch ($Level)
    {
        "ERROR" {
            Write-Error "[$timestamp] ERROR: $Message"
        }
        "WARN" {
            Write-Warning "[$timestamp] WARN: $Message"
        }
        "INFO" {
            Write-Host "[$timestamp] INFO: $Message"
        }
        "DEBUG" {
            Write-Host "[$timestamp] DEBUG: $Message" -ForegroundColor Gray
        }
    }
}

# Dedicated logging methods
function Write-LogError
{
    param ([string]$Message)
    Write-Log -Level "ERROR" -Message $Message
}

function Write-LogWarn
{
    param ([string]$Message)
    Write-Log -Level "WARN" -Message $Message
}

function Write-LogInfo
{
    param ([string]$Message)
    Write-Log -Level "INFO" -Message $Message
}

function Write-LogDebug
{
    param ([string]$Message)
    Write-Log -Level "DEBUG" -Message $Message
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
        Write-LogError "$tool is not installed"
        exit 1
    }
}

# Determine the operating system
if ($env:OS -match "Windows_NT")
{
    $nvim_config_dir = "$env:USERPROFILE\AppData\Local\nvim"
} else
{
    Write-LogError "Unsupported OS $($PSVersionTable.OS)"
    exit 1
}

# Define chezmoi directories
$CHEZMOI_ROOT_DIR = "$env:USERPROFILE\.local\share\chezmoi\home"
$TEMPLATES_DIR = "$CHEZMOI_ROOT_DIR\.chezmoitemplates\nvim"
$STATE_FILE = "$TEMPLATES_DIR\state.json"

Write-LogDebug "Configuration loaded: LOG_LEVEL=$LOG_LEVEL, DRY_RUN=$DRY_RUN"
Write-LogDebug "Chezmoi root dir: $CHEZMOI_ROOT_DIR"
Write-LogDebug "Templates dir: $TEMPLATES_DIR"
Write-LogDebug "State file: $STATE_FILE"

function Confirm-TemplateFile
{
    param (
        [string]$File,
        [switch]$Verbose
    )

    if ($null -eq $File)
    {
        Write-LogDebug "No template file provided"
        return $false
    }

    if (-not (Test-Path $File))
    {
        Write-LogDebug "Template file does not exist"
        return $false
    }

    # file not inside $CHEZMOI_ROOT_DIR"/.chezmoitemplates/ folder
    if (-not $File.StartsWith("$CHEZMOI_ROOT_DIR\.chezmoitemplates\"))
    {
        Write-LogDebug "Template file is not inside $CHEZMOI_ROOT_DIR/.chezmoitemplates/ folder $File"
        return $false
    }

    $baseName = [System.IO.Path]::GetFileName($File)

    # File start with "."
    if ($baseName[0] -eq ".")
    {
        Write-LogDebug "Template file $baseName starts with ."
        return $false
    }

    if ($baseName -eq "state.json")
    {
        Write-LogDebug "Template file name is state.json"
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

    if (-not (Confirm-TemplateFile -File $TemplateFile)) {
        Write-LogWarn "Invalid template file $TemplateFile"
        Write-LogDebug "Skip creating template for $TemplateFile"
        return $false
    }

    # Strip the chezmoi templates prefix path
    $templateFile = $TemplateFile.Substring("$ChezmoiRootDir\.chezmoitemplates\".Length)

    if ($env:OS -match "Windows_NT")
    {
        $targetFile = "$ChezmoiRootDir\AppData\Local\$templateFile.tmpl"
    } else
    {
        $targetFile = "$ChezmoiRootDir/dot_config/$templateFile.tmpl"
    }

    Write-LogDebug "Creating template: $templateFile -> $targetFile"

    if ($DRY_RUN) {
        Write-LogInfo "[DRY RUN] Would create template: $targetFile"
        return $true
    }

    $targetDir = [System.IO.Path]::GetDirectoryName($targetFile)
    if (-not (Test-Path $targetDir))
    {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    if (-not (Test-Path $targetFile))
    {
        New-Item -ItemType File -Force -Path $targetFile | Out-Null
    }
    # Avoid chezmoi template checking
    $templateString = "- template `"$templateFile`" . -"
    $templateString = "{$templateString}"
    $templateString = "{$templateString}"
    $templateString = $templateString.Replace("\", "/")
    #
    $templateString | Set-Content -Path $targetFile

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
        $targetFile = "$ChezmoiRootDir\AppData\Local\$TemplateFile.tmpl"
    } else
    {
        $targetFile = "$ChezmoiRootDir/dot_config/$TemplateFile.tmpl"
    }

    if (-not (Test-Path $targetFile))
    {
        return $false
    }

    $destinationFile = $TemplateFile.Substring("nvim\".Length)
    $destinationFile = "$nvim_config_dir\$destinationFile"

    Write-LogDebug "Removing template: $TemplateFile -> $targetFile"

    if ($DRY_RUN) {
        Write-LogInfo "[DRY RUN] Would remove template: $targetFile and destroy: $destinationFile"
        return $true
    }

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
        Write-LogDebug "Ignoring tracking template file `"$($_.FullName)`" state in `"state.json`""
        return
    }
    # Strip the chezmoi templates prefix path
    $templateFile = $_.FullName.Substring("$CHEZMOI_ROOT_DIR\.chezmoitemplates\".Length)
    $timestamp = Get-Date $_.LastWriteTime
    $timestamp = ([DateTimeOffset]$timestamp).ToUnixTimeSeconds()
    $CURRENT_STATE.Add($templateFile, $timestamp)
}

# Detect added files
foreach ($file in $CURRENT_STATE.Keys)
{
    if (-not $PREVIOUS_STATE.ContainsKey($file))
    {
        $templateFile = "$CHEZMOI_ROOT_DIR\.chezmoitemplates\$file"
        if (New-Template -ChezmoiRootDir $CHEZMOI_ROOT_DIR -TemplateFile $templateFile)
        {
            Write-LogInfo "Template for $file created"
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
            Write-LogInfo "Template for $file removed"
        }
    }
}

# Save current state
$CURRENT_STATE | ConvertTo-Json -Compress | Set-Content -Path $STATE_FILE
