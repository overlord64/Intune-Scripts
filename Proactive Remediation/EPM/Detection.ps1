$epmAgentPath = "$env:programfiles\Microsoft EPM Agent"
if(Test-Path -Path $epmAgentPath)
{
	Write-Host "Installed"
	exit 0
}
else
{
	exit 1
}