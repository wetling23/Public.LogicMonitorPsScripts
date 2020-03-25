<#
    .DESCRIPTION

    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 19 March 2020
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-RemoteDesktopSession
#>

# Initialize variables.
$computerName = '##system.hostname##'
$userName = '##WILDVALUE##'
$cred = New-Object System.Management.Automation.PSCredential ('##wmi.user##', $('##wmi.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Remote_Desktop_Session-collection-$computerName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Connecting to {1}, to retieve logged-in users." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response = Invoke-Command -ComputerName $computerName -Credential $cred -ScriptBlock {
    param(
        $user
    )
    $message = @"
{0}: Getting active RDP sessions on {1}, for {2}.`r`n
"@ -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $env:COMPUTERNAME, $user
    Set-Variable -Name message -Option AllScope
    $sessions = @()

    try {
        quser "$user" 2>&1 | Select-Object -Skip 1 | ForEach-Object {
            $CurrentLine = $_.Trim() -Replace '\s+', ' ' -Split '\s'
            $HashProps = @{
                UserName = $CurrentLine[0]
            }

            # If session is disconnected different fields will be selected
            if ($CurrentLine[2] -eq 'Disc') {
                $HashProps.SessionName = $null
                $HashProps.Id = $CurrentLine[1]
                $HashProps.State = $CurrentLine[2]
                $HashProps.IdleMinutes = $CurrentLine[3]
                $HashProps.LogonTime = $CurrentLine[4..6] -join ' '
                $HashProps.LogonTime = $CurrentLine[4..($CurrentLine.GetUpperBound(0))] -join ' '
                $HashProps.SessionMinutes = (New-Timespan –Start $([datetime]($HashProps.LogonTime)) –End (Get-Date)).TotalMinutes
            }
            else {
                $HashProps.SessionName = $CurrentLine[1]
                $HashProps.Id = $CurrentLine[2]
                $HashProps.State = $CurrentLine[3]
                $HashProps.IdleMinutes = $CurrentLine[4]
                $HashProps.LogonTime = $CurrentLine[5..($CurrentLine.GetUpperBound(0))] -join ' '
                $HashProps.SessionMinutes = (New-Timespan –Start $([datetime]($HashProps.LogonTime)) –End (Get-Date)).TotalMinutes
            }

            $sessions += New-Object -TypeName PSCustomObject -Property $HashProps | Select-Object -Property UserName, SessionName, Id, State, IdleMinutes, LogonTime, SessionMinutes, Error
        }
    }
    catch {
        $sessions += New-Object -TypeName PSCustomObject -Property @{
            Error = $_.Exception.Message
        } | Select-Object -Property UserName, SessionName, Id, State, IdleMinutes, LogonTime, SessionMinutes, Error
    }

    $message += ("{0}: Found {1} sessions for {2}.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $sessions.Count, $user)

    Return $sessions, $message
} -ArgumentList $userName

# Adding response to the DataSource log.
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $response[-1]; $response[-1] | Out-File -FilePath $logFile -Append } Else { $response[-1] | Out-File -FilePath $logFile -Append }

$response[0] | ForEach-Object { If ($_.IdleMinutes -eq '.') { $_.IdleMinutes = 0 } }
$response[0] | ForEach-Object { $_.IdleMinutes = (New-TimeSpan -Hours (($_.IdleMinutes).Split(':')[0]) -Minutes (($_.IdleMinutes).Split(':')[1])).TotalMinutes }
$response[0] | ForEach-Object { If ($_.UserName -match '^>') { $_.UserName = $_.UserName.TrimStart('>') } }

$message = ("{0}: There are {1} sessions. The session data is:`r`n{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response[0].Count, ($response | Out-String))
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$message = ("{0}: Returning sessions info to LogicMonitor." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

"IdleMinutes={0}" -f $response.IdleMinutes
"SessionMinutes={0}" -f $response.SessionMinutes
"Username={0}" -f $response.UserName

Return 0