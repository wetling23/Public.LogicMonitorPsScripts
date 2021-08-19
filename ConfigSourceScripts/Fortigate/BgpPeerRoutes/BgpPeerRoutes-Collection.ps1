<#
    .DESCRIPTION
        Collect BGP peer information.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 15 February 2021
            - Requires the Posh-SSH PowerShell module (Install-Module -Name Posh-SSH).
        V1.0.0.1 date: 26 February 2021
        V1.0.0.2 date: 31 March 2021
        V1.0.0.3 date: 18 August 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Fortigate/BgpPeerRoutes/
    .EXAMPLE
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param ()

Try {
    #region Setup
    # Initialize variables.
    $pw = @'
##ssh.pass##
'@
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##ssh.user##', ($pw | ConvertTo-SecureString -AsPlainText -Force))
    $exitCode = 0
    $ip = "##wildvalue##"
    $vdom = "##wildalias##"
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\configsource-bgp_peer_routes-collection-$ip-$computerName.log"

    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile

    $message = ("{0}: Defining command." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    If ($vdom -eq $ip) {
        $message = ("{0}: No virtual domains configured." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        $message | Out-File -FilePath $logFile -Append

        $command = "get router info bgp neighbors $ip"
    } Else {
        $command = "config vdom`r`nedit $vdom`r`nget router info bgp neighbors $ip" # Need double quotes here, so PS will parse the hidden characters correctly.
    }
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to establish an SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    Try {
        $session = New-SSHSession -ComputerName $computerName -Credential $credential -ErrorAction Stop -AcceptKey -Force
    } Catch {
        $message = ("{0}: Unexpected error establishing an SSH session to {1}. The error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    If ($session) {
        $message = ("{0}: SSH session established." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Unable to establish the SSH session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    $message = ("{0}: Running:`r`n`t{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$command")
    $message | Out-File -FilePath $logFile -Append

    Try {
        $routes = Invoke-SSHCommand -SSHSession $session -Command $command -ErrorAction Stop
    } Catch {
        $message = ("{0}: Unexpected error running the received-routes command. The error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        $exitCode = 1
    }

    If ($routes.Output) {
        $message = ("{0}: Routes for {1}:`r`n{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ip.Split(' ')[0], ($routes.Output | Out-String))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: No routes returned." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }

    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    Exit $exitCode
}
Catch {
    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}