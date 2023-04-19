$file = "c:\windows\temp\epm.ps1"
Remove-Item $file -Force -EA SilentlyContinue
"Start-Transcript -Path 'c:\ProgramData\Microsoft\IntuneManagementExtension\epm.ps1.log'" >> $file
"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12" >> $file
"Install-PackageProvider -Name NuGet -Force" >> $file
"Install-Module -Name localmdm -Force -SkipPublisherCheck" >> $file

$test1 = "<SyncBody><Exec><CmdID>12</CmdID><Item><Target><LocURI>./Vendor/MSFT/DMClient/Provider/MS%20DM%20Server/LinkedEnrollment/Enroll</LocURI></Target></Item></Exec></SyncBody>"

"Import-Module localmdm" >> $file
"send-localmdmrequest -SyncML `"<SyncBody><Exec><CmdID>12</CmdID><Item><Target><LocURI>./Vendor/MSFT/DMClient/Provider/MS%20DM%20Server/LinkedEnrollment/Enroll</LocURI></Target></Item></Exec></SyncBody>`"" >> $file
"Stop-Transcript" >> $file

Start-Process powershell.exe -argumentlist "-MTA -ExecutionPolicy Bypass -File $file" -Wait
