

##############################
## Parameters
##############################

[CmdletBinding()]
Param
([object]$WebhookData) #this parameter name needs to be called WebHookData otherwise the webhook does not work as expected.
$VerbosePreference = 'Continue'

##############################
## Variables
##############################

$TenantID = Get-AutomationVariable -Name 'TenantID'
$ApplicationID = Get-AutomationVariable -Name 'Intune-Client-Id'
$AppSecret = Get-AutomationVariable -Name 'Intune-Client-Secret'

$WebhookPassword = Get-AutomationVariable -Name 'AutopilotWebhookPassword'

##############################
## Functions
##############################

Function Get-MSGraphAuthToken {
    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $true)]
        [pscredential]$Credential,
        [parameter(Mandatory = $true)]
        [string]$tenantID
    )
    
    #Get token
    $AuthUri = "https://login.microsoftonline.com/$TenantID/oauth2/token"
    $Resource = 'graph.microsoft.com'
    $AuthBody = "grant_type=client_credentials&client_id=$($credential.UserName)&client_secret=$($credential.GetNetworkCredential().Password)&resource=https%3A%2F%2F$Resource%2F"

    $Response = Invoke-RestMethod -Method Post -Uri $AuthUri -Body $AuthBody
    If ($Response.access_token) {
        return $Response.access_token
    }
    Else {
        Throw "Authentication failed"
    }
}

Function Invoke-MSGraphQuery {
    [CmdletBinding(DefaultParametersetname = "Default")]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Refresh')]
        [string]$URI,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Refresh')]
        [string]$Body,

        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Refresh')]
        [string]$token,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Refresh')]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$method = "GET",
    
        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Refresh')]
        [switch]$recursive,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'Refresh')]
        [switch]$tokenrefresh,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'Refresh')]
        [pscredential]$credential,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'Refresh')]
        [string]$tenantID
    )
    $authHeader = @{
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer $Token"
    }
    
    [array]$returnvalue = $()
    Try {
        If ($body) {
            $Response = Invoke-RestMethod -Uri $URI -Headers $authHeader -Body $Body -Method $method -ErrorAction Stop -ContentType "application/json"
        }
        Else {
            $Response = Invoke-RestMethod -Uri $URI -Headers $authHeader -Method $method -ErrorAction Stop
        }
    }
    Catch {
        If (($Error[0].ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.Message -eq 'Access token has expired.' -and $tokenrefresh) {
            $token = Get-MSGraphAuthToken -credential $credential -tenantID $TenantID

            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = $Token
            }
            $returnvalue = $()
            If ($body) {
                $Response = Invoke-RestMethod -Uri $URI -Headers $authHeader -Body $Body -Method $method -ErrorAction Stop
            }
            Else {
                $Response = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method $method
            }
        }
        Else {
            Throw $_
        }
    }

    $returnvalue += $Response
    If (-not $recursive -and $Response.'@odata.nextLink') {
        Write-Warning "Query contains more data, use recursive to get all!"
        Start-Sleep 1
    }
    ElseIf ($recursive -and $Response.'@odata.nextLink') {
        If ($PSCmdlet.ParameterSetName -eq 'default') {
            If ($body) {
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -body $body -method $method -recursive -ErrorAction SilentlyContinue
            }
            Else {
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -method $method -recursive -ErrorAction SilentlyContinue
            }
        }
        Else {
            If ($body) {
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -body $body -method $method -recursive -tokenrefresh -credential $credential -tenantID $TenantID -ErrorAction SilentlyContinue
            }
            Else {
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -method $method -recursive -tokenrefresh -credential $credential -tenantID $TenantID -ErrorAction SilentlyContinue
            }
        }
    }
    Return $returnvalue
}

##############################
## Scriptstart
##############################

# If ($WebHookData.RequestHeader.message -eq $WebhookPassword) {
# 	Write-Output "Webhook authenticated"
# }
# else {
# 	Write-Output "Got Unauthenticated Request" -ErrorAction Stop
# 	Exit 1001
# }

If ($WebHookData) {
	
	# Collect properties of WebhookData
	$WebhookName = $WebHookData.WebhookName
	$WebhookHeaders = $WebHookData.RequestHeader
	$WebhookBody = $WebHookData.RequestBody
	
	# Collect individual headers. Input converted from JSON.
	$From = $WebhookHeaders.From
	$Input = (ConvertFrom-Json -InputObject $WebhookBody)
	Write-Verbose "WebhookBody: $Input"
	Write-Output -InputObject ('Runbook started from webhook {0} by {1}.' -f $WebhookName, $From)
}
Else {
	Write-Error -Message 'Runbook was not started from Webhook' -ErrorAction Stop
}

#Format the input data and post it into the data stream
$DeviceHashData = $Input.HardwareHash
$SerialNumber = $Input.SerialNumber
$ProductKey = $Input.ProductKey
$GroupTag = $Input.OrderIdentifier
$UserPrincipalName = $Input.AssignedUser

Write-Output "Posting Input Data"
$DeviceHashData
$SerialNumber
$ProductKey
$GroupTag
$UserPrincipalName

#Getting rid of formatting errors
$DeviceHashData = $DeviceHashData -creplace "rn", "rrnn" -creplace "RN", "RRNN" -creplace "Rn", "RRnn" -creplace "rN", "rrNN"
$SerialNumber = $SerialNumber -creplace "rn", "rrnn" -creplace "RN", "RRNN" -creplace "Rn", "RRnn" -creplace "rN", "rrNN"
$ProductKey = $ProductKey -creplace "rn", "rrnn" -creplace "RN", "RRNN" -creplace "Rn", "RRnn" -creplace "rN", "rrNN"
$GroupTag = $GroupTag -creplace "rn", "rrnn" -creplace "RN", "RRNN" -creplace "Rn", "RRnn" -creplace "rN", "rrNN"


#Build a json for the creating of the autopilot device
Write-Output "Constructing required JSON body based upon parameter input data for device hash upload"
$AutopilotDeviceIdentity = [ordered]@{
	'@odata.type'	     = '#microsoft.graph.importedWindowsAutopilotDeviceIdentity'
	'groupTag'    		 = if ($GroupTag) { "$($GroupTag)" } else { "" }
	'serialNumber'	     = "$($SerialNumber)"
	'productKey'		 = if ($ProductKey) { "$($ProductKey)" } else { "" }
	'hardwareIdentifier' = "$($DeviceHashData)"
	'assignedUserPrincipalName' = if ($UserPrincipalName) { "$($UserPrincipalName)" } else { "" }
	'state'			     = @{
		'@odata.type'			  = 'microsoft.graph.importedWindowsAutopilotDeviceIdentityState'
		'deviceImportStatus'	  = 'pending'
		'deviceRegistrationId'    = ''
		'deviceErrorCode'		  = 0
		'deviceErrorRNName'		  = ''
	}
}

#Getting rid of formatting errors and converting to json
$AutopilotDeviceIdentityJSON = $($($AutopilotDeviceIdentity | ConvertTo-Json) -replace "rn", "" -replace " ", "")

Write-Output $AutopilotDeviceIdentityJSON

$Credential = New-Object System.Management.Automation.PSCredential($ApplicationID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force))
$Token = Get-MSGraphAuthToken -credential $Credential -TenantID $TenantID

Write-Output "Retrieving all azure Devices"
$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
$ExistingAutpilotDevices = Invoke-MSGraphQuery -method GET -URI $resourceURL -token $token -recursive

#Checking if device already exists in autopilot
If ($ExistingAutpilotDevices.Value.SerialNumber -contains $SerialNumber)
{
	Write-Output "Device already in Autopilot, Exiting"
	Exit 0
}

Try
{
	#Import the device into Autopilot
	Write-Output "Attempting to post data for hardware hash upload"
	$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
	Invoke-MSGraphQuery -method POST -URI $resourceURL -token $token -Body $AutopilotDeviceIdentityJSON
	Write-Output "Web Request Sent"
}
catch [System.Exception] {

	$_.Exception.Message
	Write-Output "Failed to create Autopilot device"
}

#Does this look like trash to you?
Start-Sleep -Seconds 15
$DeviceStatus = $null
$ImportStatus = $null

Try
{
	#Sync Autopilot
	$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotSettings/sync"
	Invoke-MSGraphQuery -method POST -URI $resourceURL -token $token
	Write-Output "Sync Request Sent"
}
catch [System.Exception] {

	$_.Exception.Message
	Write-Output "Failed to Sync Autopilot"
}

#Verify that the device as been uploaded, if not try again up to 5 times before throwing an error
For ($i = 1; $i -lt 5; $i++)
{
	Write-Output "Verifying Status of Autopilot Import"
	If ($i -ge 5)
	{
		Write-Error "Autopilot Import Error"
		Throw "Autopilot Import Error"
		Exit 1001
	}
	$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
	$GetImportedIdentity = Invoke-MSGraphQuery -method GET -URI $resourceURL -token $token -recursive
	
	$CurrentImport = $GetImportedIdentity.value | Where-Object { $_.Serialnumber -like $SerialNumber }
	If ($CurrentImport.State.deviceImportStatus -eq "complete") { Write-Output "Import job Status complete"; $ImportStatus = 1 }
	
	$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
	$GetDeviceIdentity = Invoke-MSGraphQuery -method GET -URI $resourceURL -token $token -recursive
	
	#$GetDeviceIdentity.value
	If ($GetDeviceIdentity.value | Where-Object { $_.Serialnumber -like $SerialNumber }) { Write-Output "Autopilot Device Found"; $DeviceStatus = 1 }
	If (($DeviceStatus -eq 1) -and ($ImportStatus -eq 1))
	{	
		Start-Sleep -Seconds 20
		
		Try
		{			
			$resourceURL = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotSettings/sync"
			Invoke-MSGraphQuery -method POST -URI $resourceURL -token $token
			Write-Output "Sync Request Sent"
		}
		catch [System.Exception] {

			$_.Exception.Message
			Write-Output "Failed to create Autopilot device"
		}
		
		Write-Output "Autopilot Import Completed Successfully"
		
		Exit 0
	}
	Start-Sleep -Seconds 100
}

Exit 0