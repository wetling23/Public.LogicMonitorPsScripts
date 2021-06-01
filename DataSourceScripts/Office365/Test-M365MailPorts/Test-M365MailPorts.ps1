<#
    .DESCRIPTION
        Connect to Micrsoft 365 to test mail authentication against SMTP ports.
    .NOTES
        V1.0.0.0 date: 28 May 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
[pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##custom.m365.mail.user##', ('##custom.m365.mail.pass##' | ConvertTo-SecureString -AsPlainText -Force))
$relayUrls = "##custom.m365.mail.relayUrls##"
[array]$relayUrls = $relayUrls.Split(',')
$ports = @(25,587)

$mailParams = @{
    Body       = 'Testing body'
    From       = '##custom.m365.mail.user##'
    To         = '##custom.m365.mail.user##'
    Credential = $credential
}

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Test-M365MailPorts-collect-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile
#endregion Setup

#region Main
Foreach ($url in $relayUrls) {
    Foreach ($port in $ports) {
        $message = ("{0}: Testing {1} on port {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url, $port)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            Send-MailMessage -SmtpServer $url -Subject "Testing port $port" @mailParams -ErrorAction Stop

            Write-Host ("Port{0}Status=0" -f $port)
        } Catch {
            Write-Host ("Port{0}Status=1" -f $port)

            $message = ("{0}: Unexpected error testing {1} on port {2}. Error: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url, $port, $_.Exception.Message)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append
        }
    }
}

Exit 0
#endregion Main