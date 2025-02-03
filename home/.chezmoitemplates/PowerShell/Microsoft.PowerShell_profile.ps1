# NOTE: Change Powershell default profile location
# https://stackoverflow.com/questions/61192049/powershell-profile-variable-pointing-to-wrong-location-where-is-profile-varia

# Check if module exists
# INFO: https://stackoverflow.com/questions/28740320/how-do-i-check-if-a-powershell-module-is-installed
# INFO: https://github.com/kelleyma49/PSFzf
if (Get-Module -ListAvailable -Name PSFzf)
{
  $env:FZF_DEFAULT_COMMAND="fd . --hidden --exclude .git"
  $env:FZF_CTRL_T_COMMAND="$env:FZF_DEFAULT_COMMAND"

  Import-Module PSFzf
  # replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
} else
{
  Write-Host "PSFzf module does not exist"
}

# Add ~/bin to user path
$env:PATH += ";$env:USERPROFILE\bin"

function Get-CommandPath
{
  param (
    [string]$Command
  )
    
  $commandPath = (Get-Command $Command -ErrorAction SilentlyContinue).Path
  return $commandPath
}

function Test-Command
{
  param (
    [string]$Command
  )
    
  $commandPath = Get-CommandPath $Command
  return $null -ne $commandPath
}

# https://yazi-rs.github.io/docs/installation/#windows
if (Test-Command yazi)
{
  $gitPath = Get-CommandPath "git"
  if ($null -ne $gitPath)
  {
    if ($gitPath.Contains("$env:PROGRAMFILES"))
    {
      $env:YAZI_FILE_ONE="$env:PROGRAMFILES\Git\usr\bin\file.exe"
    } elseif ($gitPath.Contains("$env:USERPROFILE\scoop"))
    {
      $env:YAZI_FILE_ONE="$env:USERPROFILE\scoop\apps\git\current\usr\bin\file.exe"
    }
  }
}

Set-Alias which Get-Command
if (Test-Command nvim)
{
  Set-Alias -Name v -Value nvim
}

if (Test-Command pnpm)
{
  Set-Alias -Name pn -Value pnpm
}

if (Test-Command eza)
{
  function Invoke-Eza
  {
    eza --icons
  }
  function Invoke-Eza-alF
  {
    eza -alF --icons
  }
  function Invoke-Eza-aF
  {
    eza -aF --icons
  }
  function Invoke-Eza-F
  {
    eza -F --icons
  }
  function Invoke-Eza-tree
  {
    eza -alF --tree --level=2 --git --icons
  }
  Set-Alias ls Invoke-Eza
  Set-Alias ll Invoke-Eza-alF
  Set-Alias la Invoke-Eza-aF
  Set-Alias l Invoke-Eza-F
  Set-Alias lt Invoke-Eza-tree
}

if (Test-Command bat)
{
  Set-Alias cat bat
}

if (Test-Command yazi)
{
  # INFO: https://yazi-rs.github.io/docs/quick-start#shell-wrapper
  function y {
    $tmp = [System.IO.Path]::GetTempFileName()
      yazi $args --cwd-file="$tmp"
      $cwd = Get-Content -Path $tmp -Encoding UTF8
      if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
      }
    Remove-Item -Path $tmp
  }
}

Invoke-Expression (&starship init powershell)
fnm env --use-on-cd | Out-String | Invoke-Expression
Invoke-Expression (& { (zoxide init powershell | Out-String) })
