# NOTE: need to add below block code to $PROFILE if $PROFILE is not located in ~/Documents/WindowsPowerShell
# if (Test-Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
#     . "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
# }

# NOTE: install chocolatey as non-admistrative user
# https://docs.chocolatey.org/en-us/choco/setup#non-administrative-install

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile))
{
  Import-Module "$ChocolateyProfile"
}

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

function Test-Command
{
  param (
    [string]$Command
  )
    
  $commandPath = (Get-Command $Command -ErrorAction SilentlyContinue).Path
  return $null -ne $commandPath
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

Invoke-Expression (& { (zoxide init powershell | Out-String) })
Invoke-Expression (&starship init powershell)
