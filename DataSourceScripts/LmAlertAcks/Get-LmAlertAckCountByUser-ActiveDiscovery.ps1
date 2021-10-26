<#
    .DESCRIPTION
        Get acked alerts via the LogicMonitor API, looking back a configured number of minutes (defaults to 60) and returns a list of users who have acked them.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 26 October 2021
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/LmAlertAcks
#>
#Requires -Version 1.0.1.83 -Module LogicMonitor
[CmdletBinding()]
param ()

Try {
    #region Setup
    # Initialize variables.
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    $accessId = '##lmaccess.id##'
    $accessKey = '##lmaccess.key##' | ConvertTo-SecureString -AsPlainText -Force
    $accountName = '##lmaccount##'
    $collectionInterval = '##ackalertinterval##' # Value, in minutes, that the DataSource should look back (from the current time).

    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-Lm_Alert_Ack_Count_By_User-ad-$computerName.log"

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile

    If (($collectionInterval -is [int]) -and ($collectionInterval -gt 0)) {
        $message = ("{0}: Setting the alert start time to {1} minutes ago." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $collectionInterval)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $startTime = (Get-Date).AddMinutes(-$collectionInterval)

        $message = ("{0}: Start time is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $startTime)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
    Else {
        $message = ("{0}: No collection interval defined, defaulting to 60 minutes." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $startTime = (Get-Date).AddMinutes(-60)

        $message = ("{0}: Start time is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $startTime)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to get acked alerts, acked since {1}. Logging in as {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $startTime, $accessId)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Try {
        $alerts = Get-LogicMonitorAlert -AccessId $accessId -AccessKey $accesskey -AccountName $accountName -Filter @{ acked = "true" } -StartDate $startTime -EndDate (Get-Date) -LogPath $logFile -Verbose
    } Catch {
        $message = ("{0}: Unexpected error getting alerts via the LogicMonitor API. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    If ($alerts.id.Count -gt 0) {
        $message = ("{0}: Retrieved {1} acked alerts from {2} users." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $alerts.id.Count, ($alerts.ackedby | Select-Object -Unique).Count)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: No alerts retrieved, exiting." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 0
    }

    $users = ($alerts.ackedby | Select-Object -Unique)

    $message = ("{0}: Returning instances for the following users:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($users | Out-String))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Foreach ($user in $users) {
        ("{0}##{0}" -f $user.Split('@')[0])
    }

    Exit 0
    #endregion Main
} Catch {
    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile

    Exit 1
}