$agent = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$previousVisual, $previousEditor = $env:VISUAL, $env:EDITOR
try
{
	$env:VISUAL = $env:EDITOR = 'nvim --cmd let[g:dotfiles_minimal]=[v:true]'
	& @(Get-Command $agent -CommandType Application)[0].Source @args
}
finally
{
	$env:VISUAL, $env:EDITOR = $previousVisual, $previousEditor
}
exit $LASTEXITCODE
