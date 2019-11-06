<#
    .DESCRIPTION
        Accepts a comma-separated list of user accounts.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 22 October 2019
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-UserAccountPasswordAge
#>

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get_UserAccountPasswordAge-ad.log"

Try {
    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    # Initialize variables.
    $accounts = '##custom.userPwAgeCheck##'

    If ($accounts -match ',') {
        $message = ("{0}: The account list contains a comma, separating into an array." -f [datetime]::Now)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        $accounts = $accounts.Split(',')
    }

    $accounts | ForEach-Object {
        $message = ("{0}: Returning {1}." -f [datetime]::Now, $_)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Write-Host "$_##$_"
    }

    Exit 0
}
Catch {
    $message = ("{0}: Unexpected error in {1}. The command was `"{2}`" and the specific error is: {3}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

    Exit 1
}
