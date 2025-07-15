# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to log messages with timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Green
}

# Function to log errors
function Write-ErrorLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red
}

# Function to handle errors and exit
function Exit-WithError {
    param([string]$Message)
    Write-ErrorLog $Message
    exit 1
}

# Determine the operating system
Write-Log "Detecting operating system..."

# Check if we're on Windows using multiple methods for compatibility
$isWindowsOS = $false
if ($env:OS -match "Windows_NT") {
    $isWindowsOS = $true
} elseif ($PSVersionTable.PSVersion.Major -ge 6) {
    # PowerShell Core 6+ has $IsWindows variable
    if (Get-Variable -Name "IsWindows" -ErrorAction SilentlyContinue) {
        $isWindowsOS = $IsWindows
    }
} elseif ($PSVersionTable.Platform -eq "Win32NT") {
    $isWindowsOS = $true
}

if ($isWindowsOS) {
    $nvim_config_dir = "$env:USERPROFILE\AppData\Local\nvim"
    Write-Log "Detected Windows system"
} else {
    # Try to get OS info safely
    $osInfo = "Unknown"
    try {
        if ($PSVersionTable.OS) {
            $osInfo = $PSVersionTable.OS
        } elseif ($PSVersionTable.Platform) {
            $osInfo = $PSVersionTable.Platform
        }
    } catch {
        $osInfo = "Unable to determine"
    }
    Exit-WithError "Unsupported OS: $osInfo"
}

# Validate source directory exists
if (-not (Test-Path $nvim_config_dir)) {
    Exit-WithError "Neovim configuration directory not found: $nvim_config_dir"
}

Write-Log "Source directory: $nvim_config_dir"

# Define chezmoi directories
$chezmoi_root_dir = "$env:USERPROFILE\.local\share\chezmoi\home"
$templates_dir = "$chezmoi_root_dir\.chezmoitemplates\nvim"

Write-Log "Target directory: $templates_dir"

# Ensure the templates directory exists
try {
    if (-not (Test-Path $templates_dir)) {
        New-Item -ItemType Directory -Force -Path $templates_dir | Out-Null
        Write-Log "Created templates directory: $templates_dir"
    }
} catch {
    Exit-WithError "Failed to create templates directory: $templates_dir - $($_.Exception.Message)"
}

function Copy-And-Rename {
    param (
        [string]$src_dir,
        [string]$dest_dir
    )

    $fileCount = 0
    $errorCount = 0

    if (-not (Test-Path $src_dir)) {
        Write-Log "WARNING: Source directory does not exist: $src_dir"
        return $false
    }

    try {
        Get-ChildItem -Path $src_dir -Force -ErrorAction Stop | ForEach-Object {
            try {
                if ($_.PSIsContainer) {
                    # Create corresponding directory in the destination
                    $subdir = $_.Name
                    $subdirPath = "$dest_dir\$subdir"
                    
                    if (-not (Test-Path $subdirPath)) {
                        New-Item -ItemType Directory -Force -Path $subdirPath | Out-Null
                        Write-Log "Created directory: $subdir"
                    }
                    
                    # Recursively copy and rename inside the subdirectory
                    $result = Copy-And-Rename -src_dir $_.FullName -dest_dir $subdirPath
                    if (-not $result) {
                        $errorCount++
                    }
                } else {
                    $filename = $_.Name
                    $destinationPath = ""
                    
                    if ($filename -match "^\.") {
                        $new_filename = "dot_$($filename.Substring(1))"
                        $destinationPath = "$dest_dir\$new_filename"
                        Copy-Item -Path $_.FullName -Destination $destinationPath -ErrorAction Stop
                        Write-Log "Copied and renamed $filename to $new_filename"
                    } else {
                        $destinationPath = "$dest_dir\$filename"
                        Copy-Item -Path $_.FullName -Destination $destinationPath -ErrorAction Stop
                        Write-Log "Copied $filename"
                    }
                    
                    $fileCount++
                }
            } catch {
                Write-ErrorLog "Failed to process $($_.Name): $($_.Exception.Message)"
                $errorCount++
            }
        }
    } catch {
        Write-ErrorLog "Failed to access source directory: $($_.Exception.Message)"
        return $false
    }

    Write-Log "Processed $fileCount files with $errorCount errors"
    return ($errorCount -eq 0)
}

Write-Log "Starting copy operation..."
$result = Copy-And-Rename -src_dir $nvim_config_dir -dest_dir $templates_dir

if ($result) {
    Write-Log "Copy operation completed successfully"
    exit 0
} else {
    Exit-WithError "Copy operation failed"
}
