# NOTE: need to add below block code to $PROFILE if $PROFILE is not located in ~/Documents/WindowsPowerShell
# if (Test-Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
#     . "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
# }

# NOTE: install chocolatey as non-admistrative user
# https://docs.chocolatey.org/en-us/choco/setup#non-administrative-install

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/gruvbox.omp.json" | Invoke-Expression

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
  function Invoke-Eza-alF
  {
    eza -alF
  }
  function Invoke-Eza-aF
  {
    eza -aF
  }
  function Invoke-Eza-F
  {
    eza -F
  }
  function Invoke-Eza-tree
  {
    eza -alF --tree --level=2 --git
  }
  Set-Alias ls eza
  Set-Alias ll Invoke-Eza-alF
  Set-Alias la Invoke-Eza-aF
  Set-Alias l Invoke-Eza-F
  Set-Alias lt Invoke-Eza-tree
}

Invoke-Expression (& { (zoxide init powershell | Out-String) })
