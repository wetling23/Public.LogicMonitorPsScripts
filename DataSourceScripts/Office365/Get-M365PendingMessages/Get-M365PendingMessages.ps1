<#
    .DESCRIPTION
        Connect to Microsoft 365 to retrieve message trace metrics. If the required PowerShell module (ExchangeOnlineManagement) is not installed, the script will attempt to install it.
    .NOTES
        V1.0.0.0 date: 25 May 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
[pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##custom.m365.user##', ('##custom.m365.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get-M365PendingMessages-collect-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

If (-NOT(Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    $message = ("{0}: The ExchangePowerShell PowerShell module is not installed, attempting to install it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Try {
        Install-Module -Name ExchangeOnlineManagement -Force -ErrorAction Stop
    } Catch {
        $message = ("{0}: Unexpected error installing the ExchangePowerShell PowerShell module. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
} Else {
    $message = ("{0}: The required module is installed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $message = ("{0}: Attempting to load the ExchangePowerShell module." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Try {
        Import-Module -Name ExchangeOnlineManagement -ErrorAction Stop
    } Catch {
        $message = ("{0}: Unexpected error importing the ExchangePowerShell module. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
#endregion Setup

#region Main
$message = ("{0}: Attempting to connect to Exchange Online." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

Try {
    $null = Connect-ExchangeOnline -Credential $credential -ShowBanner:$false -ErrorAction Stop

    If (-NOT (Get-PSSession).Availability -eq 'Available') {
        $message = ("{0}: No session connected. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Catch {
    $message = ("{0}: Unexpected error connecting to Exchange Online. To prevent errors {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to get pending messages." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Try {
    $pendingMessages = Get-MessageTrace -StartDate ((Get-Date).AddMinutes(-62)).ToUniversalTime() -EndDate (Get-Date).ToUniversalTime() -Status Pending -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error retrieving message trace information. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If ($pendingMessages.Received) {
    $message = ("{0}: Found {1} pending messages." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $pendingMessages.Received.Count)
    $message | Out-File -FilePath $logFile -Append

    Write-Host ("PendingMessages={0}" -f $pendingMessages.Received.Count)
}
Else {
    $message = ("{0}: No pending messages detected." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Write-Host ("PendingMessages=0")
}

$message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Exit 0
#endregion Main