<#
    .DESCRIPTION
        Use the Meraki REST API to get uplink history for monitored interface(s) + IP address(es)
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
$interfaceName = ("##wildvalue##" -split '-')[0]
$monitorIp = ("##wildvalue##" -split '-')[1]
$apiKey = '##meraki.api.key##'
$serialNumber = '##auto.serialnumber##'
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
$logFile = "$logDirPath\propertySource-Get_Meraki_Uplink_Stats-ad-$name.log"
#endregion Logging file setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile
#endregion Setup

#region Get uplink loss and latency
$message = ("{0}: Attempting to get the device's uplink status(es)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

$i = 0
# Defining the URI here, because the API was giving me trouble (no response) when I tried to define it with variables in the string, in the Invoke-RestMethod command.
$uri = ("https://dashboard.meraki.com/api/v1/devices/{0}/lossAndLatencyHistory?ip={1}&uplink={2}&timespan=60" -f $serialNumber, $monitorIp, $interfaceName)
Do {
    Try {
        $lossAndLatency = Invoke-RestMethod -Method "GET" -Uri $uri -Headers $headers -ErrorAction Stop
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit reached. Waiting 12 seconds before re-try." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

            $i++
            Start-Sleep -Seconds 12
        } Else {
            $message = ("{0}: Unexpected error getting loss and latency history. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

            Exit
        }
    }
} Until ($lossAndLatency -or ($i -ge 3))

If ($lossAndLatency.startTs) {
    $message = ("{0}: Retrieved data." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

    # Sometimes we get back multiple entries (For a timespan=60, I have noticed up to two entries). Every time I have seen that, the first one (index 0) has a startTs and endTs, but no other data. In those cases, grab the last instance in the array.
    If ($lossAndLatency.startTs.Count -gt 1) {
        $lossAndLatency = $lossAndLatency[-1]
    } Else {
        $lossAndLatency = $lossAndLatency[0]
    }
} Else {
    $message = ("{0}: No data retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($debug) { Write-Error $message }; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get uplink loss and latency

#region Output
$message = ("{0}: Returning: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($lossAndLatency | Out-String).Trim())
If ($debug) { Write-Host $message }; $message | Out-File -FilePath $logFile -Append

Write-Host ("LossPercent={0}" -f $lossAndLatency.lossPercent)
Write-Host ("LatencyMs={0}" -f $lossAndLatency.latencyMs)
Write-Host ("Goodput={0}" -f [System.Math]::Round(($lossAndLatency.goodput / 1000), 2))
Write-Host ("Jitter={0}" -f $lossAndLatency.jitter)
#endregion Output

Exit 0