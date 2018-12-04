<#
    .DESCRIPTION
        Retrieves the current stable LogicMonitor collector version and the list of downlevel collectors, then attempts to initiate an upgrade.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 18 October 2018
            - Initial release.
        V1.0.0.1 date: 24 October 2018
            - Added e-mail notification before the upgrades begin.
        V1.0.0.2 date: 31 October 2018
            - Changed $AccessKey to secure string.
            - Fixed mis-identified event log entry. Changed from error to information.
        V1.0.0.3 date: 31 October 2018
            - Added #Requires for LogicMonitor module.
        V1.0.0.4 date: 1 November 2018
            - Updated output so errors are always written.
        V1.0.0.5 date: 2 November 2018
            - Added logging output.
        V1.0.0.6 date: 4 December 2018
            - Fixed bug in how we use $ReportRecipients.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts
    .PARAMETER AccessId
        Represents the access ID used to connected to LogicMonitor's REST API.
    .PARAMETER AccessKey
        Represents the access key used to connected to LogicMonitor's REST API.
    .PARAMETER AccountName
        Represents the subdomain of the LogicMonitor customer.
    .PARAMETER MailRelay
        Represents the DNS name or IP of the desired mail relay.
    .PARAMETER SenderEmail
        Represnts the "from" e-mail address for the script's output.
    .PARAMETER ReportRecipients
        Represents the comma-separated list of e-mail addresses, to which the report will be sent.
    .PARAMETER CollectorCount
        Default value is 50. Represents the number of collectors, for which, and upgrade will be scheduled.
    .PARAMETER InstallWaitTime
        Represents the amount of time, in minutes, that the script should wait between the upgrade trigger and when it tries to determine the result.
    .PARAMETER SkipVersion
        Represents the build version to skip, if a known, bad or troubling version is released.
    .PARAMETER EventLogSource
        Default value is "LogicMonitorCollectorUpgradeScript" Represents the name of the desired source, for Event Log logging.
    .PARAMETER BlockLogging
        When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
    .EXAMPLE
        PS C:\> .\scheduleCollectorupgrade.ps1 -AccessID <access ID> -AccessKey <access key> -AccountName <account name> -MailRelay emailrelay.company.com -SenderEmail scheduledTask@company.com -ReportRecipients user1@company.com

        Attempts to upgrade 50 collectors and sends the output to user1 and user2@company.com.
    .EXAMPLE
        PS C:\> .\scheduleCollectorupgrade.ps1 -AccessID <access ID> -AccessKey (<access key> | ConvertTo-SecureString -AsPlainText -Force) -AccountName <account name> -MailRelay emailrelay.company.com -SenderEmail scheduledTask@company.com -ReportRecipients "user1@company.com,user2@company.com" -CollectorCount 100

        Attempts to upgrade 100 collectors and sends the output to user1@company.com.
    .EXAMPLE
        PS C:\> .\scheduleCollectorupgrade.ps1 -AccessID <access ID> -AccessKey (<access key> | ConvertTo-SecureString -AsPlainText -Force) -AccountName <account name> -MailRelay emailrelay.company.com -SenderEmail scheduledTask@company.com -ReportRecipients user1@company.com -SkipVersion 27003

        Attempts to upgrade 50 collectors and sends the output to user1 and user2@company.com. If the most current stable build number is 27003, the script will exit without attempting to install any updates.
#>
#Requires –Modules LogicMonitor
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [string]$AccessId,

    [Parameter(Mandatory = $True)]
    [SecureString]$AccessKey,

    [Parameter(Mandatory = $True)]
    [string]$AccountName,

    [Parameter(Mandatory = $True)]
    [string]$MailRelay,

    [Parameter(Mandatory = $True)]
    [string]$SenderEmail,

    [Parameter(Mandatory = $True)]
    [string]$ReportRecipients,

    [int]$CollectorCount = 50,

    [int]$SkipVersion,

    [Parameter(Mandatory = $True)]
    [int]$InstallWaitTime,

    [string]$EventLogSource = 'LogicMonitorCollectorUpgradeScript',

    [switch]$BlockLogging
)

$message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
If ($BlockLogging) {Write-Host $message -ForegroundColor White} Else {Write-Host $message -ForegroundColor White; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

# Initialize variables.
[timespan]$timeout = New-TimeSpan -Minutes $InstallWaitTime
$header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #ed7864;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@ # Formatting for the e-mail.

If ($PSBoundParameters['Verbose']) {
    $cmdParams = @{EventLogSource = $EventLogSource; AccessId = $AccessId; AccessKey = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))); AccountName = $AccountName; Verbose = $True}
}
Else {
    $cmdParams = @{EventLogSource = $EventLogSource; AccessId = $AccessId; AccessKey = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))); AccountName = $AccountName}
}
If ($BlockLogging) {
    $cmdParams.Add("BlockLogging", $True)
}

#region In-line functions.
Function Get-RelevantHistory {
    $message = ("{0}: Searching update histories." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    Foreach ($history in $recentHistories) {
        Foreach ($collector in $downlevelCollectors) {
            If ($collector.id -eq $history.collectorId) {
                $message = ("{0}: Found a matching history for {1}." -f (Get-Date -Format s), $collector.hostname)
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

                $relevantHistory = [PSCustomObject]@{
                    "CollectorId" = $collector.id;
                    "HappenedOn"  = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($($history.happenedOn)));
                    "Notes"       = $history.notes;
                    "Status"      = If ($history.Status -eq 1) {"Upgrade failure"} Else {"Upgrade success"};
                }

                $relevantHistory
            }
        }
    }
}
#endregion in-line functions.

$message = ("{0}: Attempting to retrieve the most recent collector version, from LogicMonitor." -f (Get-Date -Format s))
If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

# Retrieve the most recent stable version (major and minor) of the collector software.
$newestVersion = Get-LogicMonitorCollectorAvailableVersions @cmdParams | Where-Object {$_.stable -eq $true} | Select-Object -Last 1

If ($newestVersion) {
    $message = ("{0}: The most recent collector version is {1}.{2}." -f (Get-Date -Format s), $newestVersion.MajorVersion, (($newestVersion.minorVersion).ToString()).PadLeft(3, '0'))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}
}
Else {
    $message = ("{0}: Unable to determine the most recent collector version." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

    Try {
        Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Failure: Collector Upgrade-Script Failure (version retrieval)' -To ($ReportRecipients -split ",") -Body ("Consult the Windows Application log on {1} for details." -f $env:COMPUTERNAME)
    }
    Catch {
        $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f (Get-Date -Format s), $ReportRecipients, $_.Exception.Message)
        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

        Return
    }
}

If (($SkipVersion) -and ($SkipVersion -eq ([string]($newestVersion.MajorVersion) + [string]$($(($newestVersion.minorVersion).ToString()).PadLeft(3, '0'))))) {
    $message = ("{0}: The user requested that {1} is skipped and the current version matches. No further action to take." -f (Get-Date -Format s), $SkipVersion)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    Return
}

$message = ("{0}: Attempting to retrieve downlevel collectors." -f (Get-Date -Format s))
If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

# Get the downlevel collectors.
$downlevelCollectors = Get-LogicMonitorCollectors @cmdParams | Where-Object {($_.Build -lt "$($newestVersion.majorVersion)$($($newestVersion.minorversion).tostring().PadLeft(3,'0'))") -and ($_.isDown -eq $false)} | Select-Object -First $CollectorCount

If (($downlevelCollectors) -and ($downlevelCollectors -ne "Error")) {
    $message = ("{0}: Found {1} downlevel collectors." -f (Get-Date -Format s), $downlevelCollectors.Count)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}
}
Else {
    $message = ("{0}: Unable to identify any downlevel collectors. No further action to take." -f (Get-Date -Format s), $downlevelCollectors.Count)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

    Try {
        Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Failure: Collector Upgrade-Script Failure (collector retrieval)' -To ($ReportRecipients -split ",") -Body ("Consult the Windows Application log on {1} for details." -f $env:COMPUTERNAME)
    }
    Catch {
        $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f (Get-Date -Format s), $ReportRecipients, $_.Exception.Message)
        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

        Return
    }
}

$message = ("{0}: Attempting to send a pre-upgrade e-mail to {1}." -f (Get-Date -Format s), $ReportRecipients)
If ($BlockLogging) {Write-Host $message -ForegroundColor White} Else {Write-Host $message -ForegroundColor White; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

# Sending pre-upgrade notification to the e-mail recipients.
Try {
    Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Information: Collector Upgrade-Script beginning' -To ($ReportRecipients -split ",") -Body ("The following collectors are being upgraded:`n{0}." -f ($($downlevelCollectors.hostname) -join ', '))
}
Catch {
    $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f (Get-Date -Format s), $ReportRecipients, $_.Exception.Message)
    If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

    Return
}

Foreach ($collector in $downlevelCollectors) {
    $message = ("{0}: Attempting to schedule the upgrade of {1}." -f (Get-Date -Format s), $collector.hostname)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    $status = Update-LogicMonitorCollectorVersion @cmdParams -Id $collector.id -MajorVersion $newestVersion.MajorVersion -MinorVersion $newestVersion.MinorVersion | Select-Object onetimeUpgradeInfo

    If (-NOT($status.onetimeUpgradeInfo.startEpoch)) {
        $message = ("{0}: It appears that the upgrade of {1} was not scheduled." -f (Get-Date -Format s), $collector.hostname)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}
    }
    Else {
        $message = ("{0}: Scheduled upgrade of {1} at {2}." -f (Get-Date -Format s), $collector.hostname, [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($($status.onetimeUpgradeInfo.startEpoch))))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}
    }
}

$message = ("{0}: Waiting for {1} minutes, for the collectors to download and install the update." -f (Get-Date -Format s), $timeout.Minutes)
If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

$stopwatch = [diagnostics.stopwatch]::StartNew()
While ($stopwatch.elapsed -lt $timeout) {
    Start-Sleep -Seconds (($timeout.Minutes / 4) * 60)

    $message = ("{0}: Elapsed time: {1}." -f (Get-Date -Format s), $stopwatch.elapsed)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}
}
$null = $stopwatch.Stop()

$message = ("{0}: Attempting to retrieve upgrade histories for the recently upgraded collectors." -f (Get-Date -Format s))
If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

# Check for upgrade statuses.
$recentHistories = Get-LogicMonitorCollectorUpgradeHistory @cmdParams | Sort-Object happenedOn | Select-Object -Last ($downlevelCollectors).count

If ($recentHistories) {
    $message = ("{0}: Retrieved upgrade histories." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}
}
Else {
    $message = ("{0}: Unable to retrieve any upgrade histories." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}
}

$reportContent = Get-RelevantHistory

Try {
    Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Success: Collector Upgrade-Script' -To ($ReportRecipients -split ",") `
        -Body (($reportContent | Select-Object @{label = 'CollectorId'; expression = {$_.CollectorId}}, @{label = 'Status'; expression = {$_.Status}}, @{label = 'HappenedOn'; expression = {$_.HappenedOn}}, @{label = 'Notes'; expression = {$_.Notes}} | ConvertTo-HTML -Head $header -Property 'CollectorId', 'Status', 'HappenedOn', 'Notes') | Out-String)
}
Catch {
    $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f (Get-Date -Format s), $ReportRecipients, $_.Exception.Message)
    If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

    Return
}
