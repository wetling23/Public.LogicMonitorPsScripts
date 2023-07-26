<#
    .DESCRIPTION
        Use the Meraki REST API to identify monitored uplink ports, and the IP address(es) they test against.
    .NOTES
        V2023.07.25.0
            - Initial release.
        V2023.07.26.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourcesScripts/Meraki/Get-MerakiUplinkStats
#>
[CmdletBinding()]
param ()
#Requires -Version 5.0

#region Setup
#region Variables
$name = '##system.hostname##'
$orgId = '##auto.meraki.api.orgid##'
$apiKey = '##meraki.api.key##'
$serialNumber = '##auto.serialnumber##'
$debug = $false
$uplinks = [System.Collections.Generic.List[object]]::new()

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
$logFile = "$logDirPath\datasource-Get_Meraki_Uplink_Stats-ad-$name.log"
#endregion Logging file setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile
#endregion Setup

#region Get uplink status
$message = ("{0}: Attempting to get the device's uplink status(es)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $response = Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/organizations/$orgId/uplinks/statuses?serials[]=$serialNumber" -Headers $headers -ErrorAction Stop

        Foreach ($item in $response) {
            Foreach ($uplink in $item.Uplinks) {
                If ($uplink.status -in @('active', 'ready')) {
                    $uplinks.Add($([PsCustomObject]@{
                                networkId        = $item.networkId
                                serial           = $item.serial
                                model            = $item.model
                                highAvailability = $item.highAvailability
                                lastReportedAt   = $item.lastReportedAt
                                uplink           = @{
                                    interface    = $uplink.interface
                                    status       = $uplink.status
                                    ip           = $uplink.ip
                                    gateway      = $uplink.gateway
                                    publicIp     = $uplink.publicIp
                                    primaryDns   = $uplink.primaryDns
                                    secondaryDns = $uplink.secondaryDns
                                    ipAssignedBy = $uplink.ipAssignedBy
                                }
                            }))
                }
            }
        }
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 12 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 12
        } Else {
            $message = ("{0}: Unexpected error getting uplink statuses. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

            Exit
        }
    }
} Until ($response -or ($i -ge 3))

If ($uplinks) {
    $message = ("{0}: Found {1} uplink interfaces." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $uplinks.uplink.ip.Count)
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append
} Else {
    # Not exiting in error, because maybe this is a valid condition.
    $message = ("{0}: No active uplink interfaces identified. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append
}
#endregion Get uplink status

#region Get uplink loss and latency
$message = ("{0}: Attempting to get the device's loss and latency data." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

$i = 0
Do {
    Try {
        $lossAndLatency = (Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v1/organizations/$orgId/devices/uplinksLossAndLatency" -Headers $headers -ErrorAction Stop).Where({ $_.serial -eq $serialNumber })
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 12 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 12
        } Else {
            $message = ("{0}: Unexpected error getting uplink loss and latency data. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

            Exit
        }
    }
} Until ($lossAndLatency -or ($i -ge 3))

If ($lossAndLatency) {
    $message = ("{0}: Found {1} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $lossAndLatency.serial.Count)
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append
} Else {
    $message = ("{0}: No data retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get uplink loss and latency

#region Parse data
Foreach ($item in @($lossAndLatency | Where-Object { $_.uplink -in $uplinks.uplink.interface })) {
    $message = ("{0}: Returning instance: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$($item.uplink)-$($item.ip)")
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

    Write-Host ("{0}##{0}" -f "$($item.uplink)-$($item.ip)")
}
#endregion Parse data

Exit 0