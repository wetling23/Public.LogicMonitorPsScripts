<#
    .DESCRIPTION
        Connects to the Meraki API, to retrieve device serial numbers.

        Requires the meraki.api.orgname (representing the organization name defined in the Meraki portal) and meraki.api.key (API key with rights to access the defined organization) properties.
    .NOTES
        V1.0.0.0 date: 1 May 2020
            - Initial release.
        V2022.06.11.0
        V2022.11.11.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/meraki
#>
[CmdletBinding()]
param ()
#Requires -Version 5.0

#region Setup
#region Variables
$name = '##system.hostname##'
$orgName = "##meraki.api.orgname##"
$apiKey = "##meraki.api.key##"
$hostname = "##system.displayname##"
$discoveredSerial = "##auto.serialnumber##"

$headers = @{
    "X-Cisco-Meraki-API-Key" = $apiKey
    "Content-Type"           = "application/json"
}
#endregion Variables

#region Logging file setup
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\propertySource-Meraki_API_Serial_Number-collection-$name.log"
#endregion Logging file setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Verbose $message; $message | Out-File -FilePath $logFile

If ($discoveredSerial -match '[a-zA-Z0-9]{4}-(?:[a-zA-Z0-9]{4}-)(?:[a-zA-Z0-9]{4})') {
    $message = ("{0}: The serial number has already been discovered, nothing else to do." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append
}
#endregion Setup

#region Get Meraki Orgs
$message = ("{0}: Attempting to get the Meraki organization ID for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $orgId = ((Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v0/organizations" -Headers $headers -ErrorAction Stop).Where({ $_.name -eq "$OrgName" })).id
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 60 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 60
        } Else {
            $message = ("{0}: Unexpected error getting org ID. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

            Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

            Exit
        }
    }
} Until ($orgId -or ($i -ge 3))

If ($orgId) {
    $message = ("{0}: Found org ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $orgId)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append
} Else {
    $message = ("{0}: No org ID retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get Meraki Orgs

#region Get Meraki networks
$message = ("{0}: Attempting to get the Meraki network list for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $nwIds = (Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/organizations/$orgId/networks" -Headers $headers -ErrorAction Stop).id
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 60 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 60
        } Else {
            $message = ("{0}: Unexpected error getting network list. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

            Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

            Exit
        }
    }
} Until ($nwIds -or ($i -ge 3))

If ($nwIds) {
    $message = ("{0}: Found {1} networks." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($nwIds | Measure-Object).Count)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append
} Else {
    $message = ("{0}: No networks retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get Meraki networks

#region Get Meraki devices
$deviceList = $nwIds | ForEach-Object {
    $message = ("{0}: Attempting to get the Meraki devices on network: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    $i = 0
    Do {
        Try {
            $temp = Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/networks/$_/devices" -Headers $headers -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match '429') {
                $message = ("{0}: Rate limit reached. Waiting 60 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

                $i++
                Start-Sleep -Seconds 60
            } Else {
                $message = ("{0}: Unexpected error getting devices. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

                Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

                Exit 1
            }
        }
    } Until ($temp -or ($i -ge 3))

    $temp | Select-Object -Property name, serial
}

If ($deviceList) {
    Write-Host ("auto.serialnumber={0}" -f ($deviceList | Where-Object { $_.name -eq $hostname }).serial)
} Else {
    $message = ("{0}: No devices retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get Meraki devices

Exit 0