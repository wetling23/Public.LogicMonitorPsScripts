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
            - Fixed bug in how we use $ReportRecipient.
        V1.0.0.7 date: 5 March 2019
            - Fixed bug with newest-version identification.
        V1.0.0.8 date: 8 April 2019
            - Fixed another bug with newest-version identification.
        V1.0.0.9 date: 9 September 2019
        V1.0.0.10 date: 25 September 2019
        V1.0.0.11 date: 21 October 2019
        V1.0.0.12 date: 22 October 2019
        V1.0.0.13 date: 11 December 2019
        V1.0.0.14 date: 8 April 2020
        V1.0.0.15 date: 15 May 2020
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
    .PARAMETER ReportRecipient
        Represents the comma-separated list of e-mail addresses, to which the report will be sent.
    .PARAMETER CollectorCount
        Default value is 50. Represents the number of collectors, for which, and upgrade will be scheduled.
    .PARAMETER InstallWaitTime
        Represents the amount of time, in minutes, that the script should wait between the upgrade trigger and when it tries to determine the result.
    .PARAMETER SkipVersion
        Represents the build version to skip, if a known, bad or troubling version is released.
    .PARAMETER EventLogSource
        When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
    .PARAMETER LogPath
        When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
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
#Requires -Modules LogicMonitor
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
    [string[]]$ReportRecipient,

    [int]$CollectorCount = 50,

    [int]$SkipVersion,

    [Parameter(Mandatory = $True)]
    [int]$InstallWaitTime,

    [string]$EventLogSource,

    [string]$LogPath
)

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType First -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Info -Message $message }

Try {
    # Initialize variables.
    $timer = [system.diagnostics.stopwatch]::startNew()
    [timespan]$timeout = New-TimeSpan -Minutes $InstallWaitTime
    $header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #ed7864;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@ # Formatting for the e-mail.

    If ($PSBoundParameters['Verbose']) {
        $cmdParams = @{AccessId = $AccessId; AccessKey = $AccessKey; AccountName = $AccountName; Verbose = $True }
    }
    Else {
        $cmdParams = @{AccessId = $AccessId; AccessKey = $AccessKey; AccountName = $AccountName }
    }
    If ($EventLogSource -and (-NOT $LogPath)) {
        $cmdParams.Add('EventLogSource', $EventLogSource)
    }
    ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $cmdParams.Add('LogPath', $LogPath)
    }

    #region In-line functions.
    <#
    #deprecated, to be removed later: 
    Function Get-RelevantHistory {
        $message = ("{0}: Searching update histories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Foreach ($history in $recentHistories) {
            Foreach ($collector in $downlevelCollectors) {
                If ($collector.id -eq $history.collectorId) {
                    $message = ("{0}: Found a matching history for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $collector.hostname)
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $relevantHistory = [PSCustomObject]@{
                        "CollectorId" = $collector.id;
                        "HappenedOn"  = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($($history.happenedOn)));
                        "Notes"       = $history.notes;
                        "Status"      = If ($history.Status -eq 1) { "Upgrade failure" } Else { "Upgrade success" };
                    }

                    $relevantHistory
                }
            }
        }
    }#>
    #endregion in-line functions.

    $message = ("{0}: Attempting to retrieve the most recent collector version, from LogicMonitor." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Retrieve the most recent stable version (major and minor) of the collector software.
    $newestVersion = Get-LogicMonitorCollectorAvailableVersion @cmdParams | Where-Object { $_.stable -eq $true } | Sort-Object -Property releaseEpoch -Descending | Select-Object -First 1

    If ($newestVersion) {
        # LogicMonitor uses XX.00X for GA collector releases and XX.X0X for EA collectors. I pad to the left, so that we get three places after the dot.
        $message = ("{0}: The most recent collector version is {1}.{2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $newestVersion.MajorVersion, ($newestVersion.minorVersion.ToString()).PadLeft(3, "0"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    Else {
        $message = ("{0}: Unable to determine the most recent collector version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Failure: Collector Upgrade-Script Failure (version retrieval)' -To $ReportRecipient -Body ("Consult the Windows Application log on {1} for details." -f $env:COMPUTERNAME)
        }
        Catch {
            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }

    If (($SkipVersion) -and ($SkipVersion -eq ([string]($newestVersion.MajorVersion) + [string]($newestVersion.MinorVersion)))) {
        $message = ("{0}: The user requested that {1} is skipped and the current version matches. No further action to take." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $SkipVersion)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Exit 0
    }

    $message = ("{0}: Attempting to retrieve downlevel collectors." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Get the downlevel collectors.
    # Need to pad here, so that the build number is correct (e.g. 28005 vs. 285).
    $downlevelCollectors = Get-LogicMonitorCollectors @cmdParams | Where-Object { ($_.Build -lt "$($newestVersion.majorVersion)$(($newestVersion.minorVersion.ToString()).PadLeft(3, "0"))") -and ($_.isDown -eq $false) } | Select-Object -First $CollectorCount

    If (($downlevelCollectors) -and ($downlevelCollectors -ne "Error")) {
        $message = ("{0}: Found {1} downlevel collectors." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $downlevelCollectors.Count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    ElseIf (-NOT($downlevelCollectors)) {
        $message = ("{0}: All collectors appear to be at the current version. No further action to take." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Success: Collector Upgrade-Script' -To $ReportRecipient -Body "All collectors are running the current version."

            Exit 0
        }
        Catch {
            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }
    Else {
        $message = ("{0}: Unable to identify any downlevel collectors. No further action to take." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Failure: Collector Upgrade-Script Failure (collector retrieval)' -To $ReportRecipient -Body ("Consult the Windows Application log on {0} for details." -f $env:COMPUTERNAME)

            Exit 0
        }
        Catch {
            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }

    $message = ("{0}: Attempting to send a pre-upgrade e-mail to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($ReportRecipient -join ', '))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Sending pre-upgrade notification to the e-mail recipients.
    Try {
        Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Information: Collector Upgrade-Script beginning' -To $ReportRecipient -Body ("The following collectors are being upgraded:`r`n{0}" -f ($($downlevelCollectors.hostname | Out-String) -join '`r`n'))
    }
    Catch {
        $message = ("{0}: Unexpected error sending the e-mail message to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Exit 1
    }

    If ($newestVersion.minorVersion.ToString().Length -eq 1) {
        $newestVersion.minorVersion = ($newestVersion.minorVersion.ToString()).PadLeft(3, "0")
    }

    $downlevelCollectors | ForEach-Object {
        $message = ("{0}: Attempting to schedule the upgrade of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.hostname)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $status = Update-LogicMonitorCollectorVersion @cmdParams -Id $_.id -MajorVersion $newestVersion.MajorVersion -MinorVersion $newestVersion.MinorVersion | Select-Object onetimeUpgradeInfo

        If (-NOT($status.onetimeUpgradeInfo.startEpoch)) {
            $message = ("{0}: It appears that the upgrade of {1} was not scheduled." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.hostname)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
        }
        Else {
            $message = ("{0}: Scheduled upgrade of {1} at {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.hostname, [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($($status.onetimeUpgradeInfo.startEpoch))))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
        }
    }

    $message = ("{0}: Waiting for {1} minutes, for the collectors to download and install the update." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $timeout.Minutes)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $stopwatch = [diagnostics.stopwatch]::StartNew()
    While ($stopwatch.elapsed -lt $timeout) {
        Start-Sleep -Seconds (($timeout.Minutes / 4) * 60)

        $message = ("{0}: Elapsed time: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $stopwatch.elapsed)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    $null = $stopwatch.Stop()

    $message = ("{0}: Attempting to retrieve upgrade histories for the recently upgraded collectors." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Check for upgrade statuses. Get histories that are for the current version, and are in the list of downlevel collectors and happened in the last "$InstallWaitTime + 5" minutes ago.
    $relevantHistory = (Get-LogicMonitorCollectorUpgradeHistory @cmdParams -Version "$($newestVersion.MajorVersion).$($newestVersion.MinorVersion)").Where( { ($_.collectorId -in $downlevelCollectors.Id) -and ($_.happenedOn -gt ([Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end ((Get-Date).AddMinutes( - ($InstallWaitTime + 120))).ToUniversalTime()).TotalSeconds))) })

    If (($relevantHistory.Count -ge 1) -and ($relevantHistory -ne "Error")) {
        $message = ("{0}: Retrieved upgrade histories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Success: Collector Upgrade-Script' -To $ReportRecipient `
                -Body (($relevantHistory | Select-Object @{label = 'CollectorId'; expression = { $_.CollectorId } }, @{label = 'Status'; expression = { $_.Status } }, @{label = 'HappenedOn'; expression = { $_.HappenedOn } }, @{label = 'Notes'; expression = { $_.Notes } } | ConvertTo-Html -Head $header -Property 'CollectorId', 'Status', 'HappenedOn', 'Notes') | Out-String)

            $timer.Stop()

            $message = ("{0}: {1} completed successfully. The script took {2} minutes to run." -f [datetime]::Now, $MyInvocation.MyCommand, $timer.Elapsed.TotalMinutes)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Info -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Info -Message $message }

            Exit 0
        }
        Catch {
            $timer.Stop()

            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The script took {2} minutes to run. The specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $timer.Elapsed.TotalMinutes, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }
    ElseIf ($relevantHistory) {
        $message = ("{0}: Error identifying histories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Unknown: Collector Upgrade-Script' -To $ReportRecipient -Body "Error retrieving collector upgrade histories."

            $timer.Stop()

            $message = ("{0}: {1} completed successfully. The script took {2} minutes to run." -f [datetime]::Now, $MyInvocation.MyCommand, $timer.Elapsed.TotalMinutes)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Info -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Info -Message $message }

            Exit 0
        }
        Catch {
            $timer.Stop()

            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The script took {2} minutes to run. The specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $timer.Elapsed.TotalMinutes, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }
    Else {
        $message = ("{0}: Unable to retrieve any upgrade histories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message } }

        Try {
            Send-MailMessage -BodyAsHtml -From $SenderEmail -SmtpServer $MailRelay -Subject 'Unknown: Collector Upgrade-Script' -To $ReportRecipient -Body "Unable to retrieve collector upgrade histories."

            $timer.Stop()

            $message = ("{0}: {1} completed successfully. The script took {2} minutes to run." -f [datetime]::Now, $MyInvocation.MyCommand, $timer.Elapsed.TotalMinutes)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Info -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Info -Message $message }

            Exit 0
        }
        Catch {
            $timer.Stop()

            $message = ("{0}: Unexpected error sending the e-mail message to {1}. The script took {2} minutes to run. The specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ReportRecipient, $timer.Elapsed.TotalMinutes, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Exit 1
        }
    }
}
Catch {
    $timer.Stop()

    $message = ("{0}: Unexpected error somewhere in {1}, which ran for {2} minutes. The specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $timer.Elapsed.TotalMinutes, $_.Exception.Message)
    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

    Exit 1
}
