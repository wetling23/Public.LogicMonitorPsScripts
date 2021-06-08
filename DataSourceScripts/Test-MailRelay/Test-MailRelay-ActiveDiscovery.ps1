<#
    .DESCRIPTION
        Active Discovery script to create monitored instances for each configured SMTP port.
    .NOTES
        V1.0.0.0 date: 8 June 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Test-MailRelay
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
$ports = "##custom.mailrelay.ports##"
$ports = $ports.Split(',')
$relayUrls = "##custom.mailrelay.urls##"
$relayUrls = $relayUrls.Split(',')

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Test-MailRelay-activediscovery-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile
#endregion Setup

#region Main
Foreach ($port in $ports) {
    Foreach ($url in $relayUrls) {
        $message = ("{0}: Returning {1} and {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $port, $url)
        Write-Host $message; $message | Out-File -FilePath $logFile

        "$port##$url($port)"
    }
}

$message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile

Exit 0
#endregion Main