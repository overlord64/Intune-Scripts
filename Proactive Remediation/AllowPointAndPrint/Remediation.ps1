$PrintReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
if(!(Test-Path $PrintReg)) { New-Item $PrintReg }
$rpckey = (Get-ItemProperty -Path $PrintReg | Select-Object -ExpandProperty 'RestrictDriverInstallationToAdministrators' -ErrorAction Ignore)
if($rpckey -ne $null) { Set-ItemProperty -Path $PrintReg -Name 'RestrictDriverInstallationToAdministrators' -Value 0 -Force}
else
{ New-ItemProperty -Path $PrintReg -Name 'RestrictDriverInstallationToAdministrators' -Value 0 -PropertyType "DWORD" -Force}
