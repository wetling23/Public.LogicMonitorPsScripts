<#
    .DESCRIPTION
        Use PowerCLI to query VMware (vCenter or host) for event events and return a count.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 20 July 2021
            - Initial release. Based on Get-VMotion from https://github.com/brianbunke/vCmdlets.

        Use the device property, custom.vmwareevent.lookbackminutes to control the maximum event age. If this property is ommitted, the default value is 1,440 minutes.
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
    $instance = "##WILDVALUE##"
    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-VMware_Event_Count-collection-$instance-$computerName.log"

    [int]$minutes = "##custom.vmwareevent.lookbackminutes##"
    $pw = @'
##esx.pass##
'@
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##esx.user##', ($pw | ConvertTo-SecureString -AsPlainText -Force))
    $exitCode = 0

    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile

    If ($minutes -le 0) {
        $message = ("{0}: No lookback defined, defaulting to 65 minutes." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $time = (Get-Date).AddMinutes(-1440).ToUniversalTime()
    } Else {
        $time = (Get-Date).AddMinutes(-$minutes).ToUniversalTime()
    }

    $message = ("{0}: Attempting to connect to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $session = Connect-VIServer -Server $computerName -Credential $credential -Force

    If ($session.Name) {
        $message = ("{0}: Successfully connected to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Connection failed, exiting. If available, the message is:`r`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $session)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
    #endregion Setup

    #region Main
    $Events = New-Object System.Collections.ArrayList
    $EventFilter = New-Object VMware.Vim.EventFilterSpec
    $EventFilter.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
    $EventFilter.Time = New-Object VMware.Vim.EventFilterSpecByTime
    $EventFilter.Time.BeginTime = $Time
    $EventFilter.DisableFullMessage = $true
    $EventFilter.EventTypeID = $instance
    $EventMgr = Get-View EventManager -Server $computerName -Verbose:$false -Debug:$false
    $InventoryObjects = Get-Datacenter -Server $computerName -Verbose:$false -Debug:$false

    ForEach ($object in $InventoryObjects) {
        $EventFilter.Entity.Entity = $object.ExtensionData.MoRef
        $EventFilter.Entity.Recursion = & {
            If ($object.ExtensionData.MoRef.Type -eq 'VirtualMachine') { 'self' } Else { 'all' }
        }

        $message = ("{0}: Calling Get-View to gather event results for object {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $($object.Name))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $CollectorSplat = @{
            Server  = $vCenter
            Verbose = $false
            Debug   = $false
        }

        $Collector = Get-View ($EventMgr).CreateCollectorForEvents($EventFilter) @CollectorSplat
        $Buffer = $Collector.ReadNextEvents(100)

        If (-not $Buffer) {
            $message = ("{0}: No events found." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Write-Host ("eventCount=0")

            Disconnect-VIServer -Confirm:$false
            Exit $exitCode
        }

        While ($Buffer) {
            $EventCount = ($Buffer | Measure-Object).Count
            $message = ("{0}: Found {1} events, processing." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventCount)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            # Append up to 100 results into the $Events array
            If ($EventCount -gt 1) {
                # .AddRange if more than one event
                $null = $Events.AddRange($Buffer)
            } Else {
                # .Add if only one event; should never happen since gathering begin & end events
                $null = $Events.Add($Buffer) | Out-Null
            }
            # Were there more than 100 results? Get the next batch and restart the While loop
            $Buffer = $Collector.ReadNextEvents(100)
        }
        # Destroy the collector after each entity to avoid running out of memory :)
        $Collector.DestroyCollector()
    }

    If ($events.Key.Count -gt 0) {
        $message = ("{0}: Event entries:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($events | Format-List -Property * | Out-String))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("eventCount={0}" -f $events.Key.Count)

        Disconnect-VIServer -Confirm:$false
        Exit $exitCode
    } Else {
        $message = ("{0}: No results." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("eventCount=0")

        Disconnect-VIServer -Confirm:$false
        Exit $exitCode
    }
    #endregion Main
} Catch {
    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile

    Exit 1
}