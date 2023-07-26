<#
    .DESCRIPTION
        Connects to the Meraki API, to retrieve device properties.

        Requires the meraki.api.orgname (representing the organization name defined in the Meraki portal) and meraki.api.key (API key with rights to access the defined organization) properties.
    .NOTES
        V2023.07.25.0
            - Initial release.
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
$debug = $false

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
$logFile = "$logDirPath\propertySource-Meraki_API_Device_Property-collection-$name.log"
#endregion Logging file setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile
#endregion Setup

#region Get Meraki Orgs
$message = ("{0}: Attempting to get the Meraki organization ID for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $orgId = ((Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/organizations" -Headers $headers -ErrorAction Stop).Where({ $_.name -eq "$OrgName" })).id
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 60 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 60
        } Else {
            $message = ("{0}: Unexpected error getting org ID. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

            Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

            Exit
        }
    }
} Until ($orgId -or ($i -ge 3))

If ($orgId) {
    $message = ("{0}: Found org ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $orgId)
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append
} Else {
    $message = ("{0}: No org ID retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get Meraki Orgs

#region Get device
$message = ("{0}: Attempting to get the Meraki network list for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $data = Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/organizations/$orgId/devices?name=CLEBAK-MX64-FW1" -Headers $headers -ErrorAction Stop
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 5 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 5
        } Else {
            $message = ("{0}: Unexpected error getting device data. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

            Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")
            Write-Host ("auto.meraki.api.networkid=Retrieve Error. See log: $logFile")
            Write-Host ("auto.manufacturer=Retrieve Error. See log: $logFile")
            Write-Host ("auto.model=Retrieve Error. See log: $logFile")
            Write-Host ("auto.meraki.api.orgid=Retrieve Error. See log: $logFile")
            Write-Host ("auto.meraki.firmware.version=Retrieve Error. See log: $logFile")

            Exit
        }
    }
} Until ($data.name -or ($i -ge 3))

If ($data) {
    $message = ("{0}: Found device. Returning:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($data | Out-String).Trim())
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

    Write-Host ("auto.serialnumber={0}" -f $data.serial)
    Write-Host ("auto.meraki.api.networkid={0}" -f $data.networkId)
    Write-Host ("auto.manufacturer=Meraki")
    Write-Host ("auto.model={0}" -f $data.model)
    Write-Host ("auto.meraki.api.orgid={0}" -f $orgId)
    Write-Host ("auto.meraki.firmware.version={0}" -f $data.firmware)
    Write-Host ("auto.network.mac_address={0}" -f $data.mac)
    Write-Host ("auto.location={0}" -f ($data | Select-Object -ExpandProperty Address)) # This one is different because "address()" is a method on the object.
    Write-Host ("auto.latitude={0}" -f $data.lat)
    Write-Host ("auto.longitude={0}" -f $data.lng)
} Else {
    $message = ("{0}: No device retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get device

Exit 0