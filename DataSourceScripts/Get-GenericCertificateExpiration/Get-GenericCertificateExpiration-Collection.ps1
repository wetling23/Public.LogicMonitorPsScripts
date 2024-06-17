<#
    .DESCRIPTION
        Use LogicMonitor manual "genericcertexpirationdata" LM properties and return days until expiration.
    .NOTES
        Author: Mike Hashemi
        V2024.06.17.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-GenericCertificateExpiration
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param()

Try {
    #region Setup
    #region Initialize variables
    #region Creds
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If ('##ssh.user##' -and '##ssh.pass##') {
        $user = '##ssh.user##'
        $pw = @'
##ssh.pass##
'@
    } ElseIf ('##config.user##' -and '##config.pass##') {
        $user = '##config.user##'
        $pw = @'
##config.pass##
'@
    }

    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($user, ($pw | ConvertTo-SecureString -AsPlainText -Force))
    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue
    #endregion Creds

    $debug = $false
    $instance = "##wildvalue##"
    $computerName = '##hostname##'
    $exitCode = 0
    $port = "##ssh.port##"
    If ($port -as [int]) {
        # No change, use the value from LM.
    } Else {
        $port = 22
    }

    $deviceType = "##custom.genericcertexpirationdata.deviceType##"
    If (-NOT ($adCommand.Length -gt 1)) {
        $deviceType = 'fortigate'
    }

    Switch ($deviceType) {
        "fortigate" {
            $discoCommand = "get vpn certificate local details $instance"
            $dateRegex = 'Valid to:\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
        }
    }
    #endregion Initialize variables

    #region Logging
    If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-Get_Generic_Certificate_Expiration_collection-$computerName.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile
    #endregion Setup

    #region Main
    #region Initial connection
    $message = ("{0}: Attempting to establish an SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName); $message | Out-File -FilePath $logFile -Append

    Try {
        $session = New-SSHSession -ComputerName $computerName -Credential $credential -Port $port -ConnectionTimeout 120 -ErrorAction Stop -Force -WarningAction SilentlyContinue
    } Catch {
        If ($_.Exception.Message -match 'Key exchange negotiation failed') {
            $message = ("{0}: SSH failed due to key exchange negotiation failure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
        } Else {
            $message = ("{0}: Unexpected error establishing an SSH session to {1}. The error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }

    If ($session) {
        $message = ("{0}: SSH session established." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Unable to establish the SSH session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
    }
    #endregion Initial connection

    #region Create SSHShellStream
    $message = ("{0}: Creating SSH shell stream." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

    $stream = New-SSHShellStream -Index 0
    #endregion Create SSHShellStream

    #region Get expiration
    $message = ("{0}: Sending '{1}'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $discoCommand); $message | Out-File -FilePath $logFile -Append

    $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command $discoCommand

    $message = ("{0}: The value in `$response (if present) is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append
    #endregion Get expiration

    #region Parse response
    If ($response) {
        Switch ($deviceType) {
            "fortigate" {
                $message = ("{0}: Parsing data for Fortigate device." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

                $match = [regex]::Match($response, $dateRegex)

                If ($match.Success) {
                    $validToDateString = $match.Groups[1].Value
                    $dateFormat = "yyyy-MM-dd HH:mm:ss"
                    $validToDate = [datetime]::ParseExact($validToDateString, $dateFormat, $null)
                    $daysDifference = ($validToDate - $(Get-Date)).Days
                } Else {
                    $message = ("{0}: Unable to calculate the expiration data." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

                    $exitCode = 1
                }
            }
        }

        $daysDifference = ($validToDate - $(Get-Date)).Days
    } Else {
        $exitCode = 1
    }
    #endregion Parse response
    #endregion Main

    #region Output
    $message = ("{0}: Certificate, `"{1}`", expires in {2} days." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $instance, $daysDifference); $message | Out-File -FilePath $logFile -Append

    Write-Host ("DaysUntilExpiration={0}" -f $daysDifference)
    #endregion Output

    $message = ("{0}: {1} is complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile -Append

    Exit $exitCode
} Catch {
    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    $message | Out-File -FilePath $logFile

    Exit 1
}