<#
    .DESCRIPTION
        Connect to a mail relay to test authentication against SMTP ports.
    .NOTES
        V1.0.0.0 date: 28 May 2021
        V1.0.0.1 date: 8 June 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
[pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##custom.mailrelay.user##', ('##custom.mailrelay.pass##' | ConvertTo-SecureString -AsPlainText -Force))
$relayUrl = "##wildalias##"
$relayUrl = $relayUrl.Split('(')[0]
$port = "##wildvalue##"

$mailParams = @{
    Body       = 'Testing body'
    From       = '##custom.mailrelay.user##'
    To         = '##custom.mailrelay.user##'
    SmtpServer = $relayUrl
    Subject    = 'Testing port {0} to {1}' -f $port, $relayUrl
    Port       = $port
    Credential = $credential
}

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Test-MailRelay-collect-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile
#endregion Setup

#region Main
$message = ("{0}: Testing {1} on port {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $relayUrl, $port)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    Send-MailMessage @mailParams -ErrorAction Stop

    Write-Host ("RelayStatus=0")
} Catch {
    Write-Host ("RelayStatus=1")

    $message = ("{0}: Unexpected error testing {1} on port {2}. Error: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $relayUrl, $port, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append
}

$message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Exit 0
#endregion Main