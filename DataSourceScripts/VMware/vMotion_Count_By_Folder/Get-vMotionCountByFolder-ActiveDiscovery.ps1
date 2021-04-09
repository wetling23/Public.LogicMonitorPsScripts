<#
    .DESCRIPTION
        Use PowerCLI to query VMware (vCenter or host) for virtual machines in a folder.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 9 April 2021
            - Initial release. Based on Get-VMotion from https://github.com/brianbunke/vCmdlets.

        The device property, vmotion.foldername is required. Enter the full folder name, of "All" (to get VMs from all folders).
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/VMware/vMotion_Count_By_Folder
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
    $logFile = "$logDirPath\datasource-vMotion_Count_By_Folder-ad-$computerName.log"

    $i = 1
    $folders = '##vmotion.foldername##'
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

    #region Parse folders
    If ($folders -eq "All") {
        $message = ("{0}: No folders specified, attempting to get all VM folders." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $folders = (Get-Folder).Where( { $_.Type -eq "VM" } ) | Select-Object -ExpandProperty Name
    }
    Else {
        $folders = $folders.Split(',').Trim('"').TrimStart(' ').TrimEnd(' ')
    }
    #endregion Parse folders

    #region Main
    Foreach ($folder in $folders) {
        $message = ("{0}: Attempting to get virtual machines in folder: {1}. This is folder {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $folder, $i, $folders.Count)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $i++

        Try {
            $vms = Get-Folder -Location $folder -Server $computerName | Get-VM
        } Catch {
            $message = ("{0}: Unexpected error discovering virtual machines. If available, the error is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Exit 1
        }

        If ($vms) {
            $message = ("{0}: Returning {1} virtual machines:`r`n{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $vms.Id.Count, ($vms.Name | Out-String))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Foreach ($vm in $vms) {
                "$($vm.Name)##$($vm.Name)"
            }
        }
        Else {
            $message = ("{0}: No virtual machines in folder: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $folder)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append
        }
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