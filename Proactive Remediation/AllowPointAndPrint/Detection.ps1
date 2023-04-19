if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'RestrictDriverInstallationToAdministrators') -eq 0)
{ Write-Output $true }
else
{ Write-Output $false }