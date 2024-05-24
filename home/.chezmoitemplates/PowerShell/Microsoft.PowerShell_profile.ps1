# NOTE: need to add below block code to $PROFILE if $PROFILE is not located in ~/Documents/WindowsPowerShell
# if (Test-Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
#     . "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
# }

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/gruvbox.omp.json" | Invoke-Expression

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Add ~/bin to user path
$env:PATH += ";$env:USERPROFILE\bin"

Set-Alias -Name v -Value nvim
Set-Alias -Name ll -Value Get-ChildItem
