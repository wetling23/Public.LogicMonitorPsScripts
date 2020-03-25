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
$cred = New-Object System.Management.Automation.PSCredential ('##wmi.user##', $('##wmi.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Remote_Desktop_Session-AD-$computerName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Connecting to {1}, to retieve logged-in users." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response = Invoke-Command -ComputerName $computerName -Credential $cred -ScriptBlock {
    $message = @"
{0}: Getting active RDP sessions on {1}.`r`n
"@ -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $env:COMPUTERNAME
    Set-Variable -Name message -Option AllScope
    $sessions = @()

    try {
        quser 2>&1 | Select-Object -Skip 1 | ForEach-Object {
            $CurrentLine = $_.Trim() -Replace '\s+', ' ' -Split '\s'
            $HashProps = @{
                UserName = $CurrentLine[0]
            }

            $sessions += New-Object -TypeName PSCustomObject -Property $HashProps | Select-Object -Property UserName
        }
    }
    catch {
        $sessions += New-Object -TypeName PSCustomObject -Property @{
            Error = $_.Exception.Message
        } | Select-Object -Property UserName
    }

    $message += ("{0}: Found {1} sessions ($).`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $sessions.Count, $HashProps.UserName)

    Return $sessions, $message
}

# Adding response to the DataSource log.
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $response[-1]; $response[-1] | Out-File -FilePath $logFile -Append } Else { $response[-1] | Out-File -FilePath $logFile -Append }

$response | ForEach-Object { If ($_.UserName -match '^>') { $_.UserName = $_.UserName.TrimStart('>') } }

$response | Foreach {
    Write-Host ("{0}##{1}" -f $_.UserName, $_.Username)
}

Return 0