Start-Transcript "c:\ProgramData\Microsoft\IntuneManagementExtension\Logs\lapsadmindetection.log"
$username = "clientadmin"
$userEnabled = $false
$user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
if ($user -and $user.Enabled) {
	$userEnabled = $true
      Write-Output ("User {0} present and enabled" -f $username)
}
If($userEnabled)
{
	Write-Output "User OK"
	exit 0
}
else
{
	Write-Ouput "Error with user"
	exit 1
}
   
Stop-Transcript