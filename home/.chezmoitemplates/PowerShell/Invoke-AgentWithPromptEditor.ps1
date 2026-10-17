$agent = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$command = @(Get-Command $agent -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)[0]
if ($null -eq $command)
{
	Write-Error "Agent executable was not found: $agent"
	exit 127
}
# Quote a literal '--' argument; PowerShell consumes bare -- when invoking scripts.
$previousVisual, $previousEditor = $env:VISUAL, $env:EDITOR
try
{
	$env:VISUAL = $env:EDITOR = 'nvim --cmd let[g:dotfiles_minimal]=[v:true]'
	if ($MyInvocation.ExpectingInput)
	{
		# Script pipelines use PowerShell's text conversion.
		$input | & $command.Source @args
	}
	else
	{
		& $command.Source @args
	}
}
finally
{
	$env:VISUAL, $env:EDITOR = $previousVisual, $previousEditor
}
exit $LASTEXITCODE
