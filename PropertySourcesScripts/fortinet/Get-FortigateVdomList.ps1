<#
    .DESCRIPTION
        Check if VDOMs are configured and return a list of names.
    .NOTES
        Author: Mike Hashemi
        V2023.06.20.0
            - Requires the Posh-SSH PowerShell module (Install-Module -Name Posh-SSH).
        V2023.06.21.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/fortinet
    .EXAMPLE
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param ()

Try {
    #region Setup
    #region Initialize variables
    $vdoms = [System.Collections.Generic.List[PSObject]]::new()
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    $pw = @'
##ssh.pass##
'@
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##ssh.user##', ($pw | ConvertTo-SecureString -AsPlainText -Force))
    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue
    $regex = '(?<=\=)(.*?)(?=\/)'
    $exitCode = 0
    #endregion Initialize variables

    #region Logging
    If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\propsource-get_fortigatevdomlist-$computerName.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile
    #endregion Setup

    #region Main
    #region Initial connection
    $message = ("{0}: Attempting to establish an SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    Try {
        $session = New-SSHSession -ComputerName $computerName -Credential $credential -ConnectionTimeout 120 -ErrorAction Stop -AcceptKey
    } Catch {
        $message = ("{0}: Unexpected error establishing an SSH session to {1}. The error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist=unknown")

        Exit 1
    }

    If ($session) {
        $message = ("{0}: SSH session established." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Unable to establish the SSH session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist=unknown")

        Exit 1
    }
    #endregion Initial connection

    #region Create SSHShellStream
    $message = ("{0}: Creating SSH shell stream." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $stream = New-SSHShellStream -Index 0
    #endregion Create SSHShellStream

    #region Check system status
    $message = ("{0}: Sending 'get system status'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "get system status | grep Virtual.domain.configuration"
    #endregion Check system status

    If ($response -match 'disable') {
        $message = ("{0}: No VDOMs configured." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        #region Output
        Write-Host ("fortinet.vdomlist={0}" -f "disabled")
        #endregion Output
    } ElseIf ($response) {
        #region Get VDOM list
        $message = ("{0}: Sending 'config global' and 'diagnose sys vd list | grep name='." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Invoke-SSHStreamShellCommand -ShellStream $stream -Command "config global" -PrompPattern "(global)"

        $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "diagnose sys vd list | grep name="

        If ($response) {
            $message = ("{0}: The diagnose command returned: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String))
            $message | Out-File -FilePath $logFile -Append

            Foreach ($item in $response) {
                $vdoms.Add($([regex]::matches($item, $regex).value | Where-Object { $_ -notmatch '^vsys' }))
            }
        } Else {
            $message = ("{0}: No VDOMs retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            #region Output
            Write-Host ("fortinet.vdomlist=unknown")
            #endregion Output

            $exitCode = 1
        }
        #endregion Get VDOM list

        #region Output
        $message = ("{0}: Returning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "fortinet.vdomlist=$((($vdoms -join ',').Trim(',') | Out-String).Trim())")
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist={0}" -f (($vdoms -join ',').Trim(',') | Out-String).Trim())
        #endregion Output
    } Else {
        $message = ("{0}: No response to the 'get system status' command." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist=unknown")
    }

    #region Cleanup
    $message = ("{0}: Attempting to cleanup the SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue
    #endregion Cleanup

    $message = ("{0}: {1} is complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile -Append

    Exit $exitCode
} Catch {
    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    $message | Out-File -FilePath $logFile

    Write-Host ("fortinet.vdomlist=unknown")

    Exit 1
}