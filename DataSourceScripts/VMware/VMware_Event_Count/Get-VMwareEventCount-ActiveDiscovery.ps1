<#
    .DESCRIPTION
        Return instnaces based on the value of the LogicMonitor device property, custom.vmwareevent.eventlist.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 20 July 2021
            - Initial release. Based on Get-VMotion from https://github.com/brianbunke/vCmdlets.

        The device property, custom.vmwareevent.eventlist (a comma-separated list of event type IDs), is required.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/VMware/VMware_Event_Count
#>
#Requires -Version 3 -Module VMware.VimAutomation.Core
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
    $logFile = "$logDirPath\datasource-VMware_Event_Count-activediscovery-$computerName.log"

    [array]$eventArray = "##custom.vmwareevent.eventlist##" -join ','
    $pw = @'
##esx.pass##
'@
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##esx.user##', ($pw | ConvertTo-SecureString -AsPlainText -Force))

    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile

    $message = ("{0}: Attempting to connect to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $session = Connect-VIServer -Server $computerName -Credential $credential -Force

    If ($session.Name) {
        $message = ("{0}: Successfully connected to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
    Else {
        $message = ("{0}: Connection failed, exiting. If available, the message is:`r`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $session)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
    #endregion Setup

    #region Main
    Foreach ($eventTypeId in $eventArray) {
        $message = ("{0}: Returning instance." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        "$eventTypeId##$eventTypeId"
    }

    Disconnect-VIServer -Confirm:$false

    Exit 0
    #endregion Main
} Catch {
    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile

    Exit 1
}