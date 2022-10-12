<#
    .DESCRIPTION
        Collect OSPF neighbor information.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 23 August 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Fortigate/OspfNeighbors/
    .EXAMPLE
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param ()

Try {
    #region Setup
    # Initialize variables.
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\configsource-ospf_neighbors-activediscovery-$computerName.log"

    $exitCode = 0
    $vdoms = "##AUTO.FORTINET.VDOMLIST##"
    If ($vdoms -match ",") { $vdoms = $vdoms.Split(',') }

    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile
    #endregion Setup

    #region Main
    If ($vdoms) {
        $message = ("{0}: Returning vdoms." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Foreach ($vdom in $vdoms) {
            Write-Host "$vdom##$vdom"
        }
    }
    Else {
        Write-Host "novdoms##novdoms"
    }
    #endregion Main

    $message = ("{0}: {1} is complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile -Append

    Exit $exitCode
} Catch {
    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    $message | Out-File -FilePath $logFile

    Exit 1
}