$winLogon = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\'
$autoAdminSet = $false
$defaultUserNameSet = $false
$autoLogonSet = $false

if($winLogon.AutoAdminLogon -eq "1")
{
	$autoAdminSet = $true
}
$autoAdminSet
if($winLogon.DefaultUserName -eq "kioskUser0")
{
	$defaultUserNameSet = $true
}
$defaultUserNameSet
if($winLogon.IsConnectedAutoLogon -eq 0)
{
	$autoLogonSet = $true
}
$autoLogonSet
if($autoAdminSet -and $defaultUserNameSet -and $autoLogonSet)
{
	Write-Host "Auto Logon Setup"
	exit 0
}
else
{
	exit 1
}
