<#
    .DESCRIPTION
        Use PowerCLI to query VMware (vCenter or host) for vMotion events and return a count of vMotions.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 9 April 2021
            - Initial release. Based on Get-VMotion from https://github.com/brianbunke/vCmdlets.

        Use the device property, vmotion.lookbackminutes to control the maximum event age. If this property is ommitted, the default value is 65 minutes.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/VMware/vMotion_Count
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
    $logFile = "$logDirPath\datasource-vMotion_Count-collection-$computerName.log"

    [int]$minutes = "##vmotion.lookbackminutes##"
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

        $time = (Get-Date).AddMinutes(-65).ToUniversalTime()
    }
    Else {
        $time = (Get-Date).AddMinutes(-$minutes).ToUniversalTime()
    }

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
    $Events = New-Object System.Collections.ArrayList
    $EventFilter = New-Object VMware.Vim.EventFilterSpec
    $EventFilter.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
    $EventFilter.Time = New-Object VMware.Vim.EventFilterSpecByTime
    $EventFilter.Time.BeginTime = $Time
    $EventFilter.DisableFullMessage = $true
    $EventFilter.EventTypeID = @(
        'com.vmware.vc.vm.VmHotMigratingWithEncryptionEvent',
        'DrsVmMigratedEvent',
        'VmBeingHotMigratedEvent',
        'VmBeingMigratedEvent',
        'VmMigratedEvent'
    )
    $EventMgr = Get-View EventManager -Server $vCenter -Verbose:$false -Debug:$false
    $InventoryObjects = Get-Datacenter -Server $vCenter -Verbose:$false -Debug:$false

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
            $message = ("{0}: No vMotion events found." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Write-Host ("vMotionCount=0")

            Disconnect-VIServer -Confirm:$false
            Exit $exitCode
        }

        While ($Buffer) {
            $EventCount = ($Buffer | Measure-Object).Count
            $message = ("{0}: Found {1} events, processing for vMotion." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventCount)
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

    $Results = New-Object System.Collections.Generic.List[object]

    ForEach ($vMotion in ($Events | Sort-Object CreatedTime | Group-Object ChainID)) {
        # Each vMotion should have start and finish events
        # "% 2" correctly processes duplicate vMotion results
        # (duplicate results can occur, for example, if you have duplicate vCenter connections open)
        If ($vMotion.Group.Count % 2 -eq 0) {
            # New 6.5 migration event type is changing fields around on me
            If ($vMotion.Group[0].EventTypeID -eq 'com.vmware.vc.vm.VmHotMigratingWithEncryptionEvent') {
                $DstDC = ($vMotion.Group[0].Arguments | Where-Object { $_.Key -eq 'destDatacenter' }).Value
                $DstDS = ($vMotion.Group[0].Arguments | Where-Object { $_.Key -eq 'destDatastore' }).Value
                $DstHost = ($vMotion.Group[0].Arguments | Where-Object { $_.Key -eq 'destHost' }).Value
            } Else {
                $DstDC = $vMotion.Group[0].DestDatacenter.Name
                $DstDS = $vMotion.Group[0].DestDatastore.Name
                $DstHost = $vMotion.Group[0].DestHost.Name
            } #If 'com.vmware.vc.vm.VmHotMigratingWithEncryptionEvent'

            # Mark the current vMotion as vMotion / Storage vMotion / Both
            If ($vMotion.Group[0].Ds.Name -eq $DstDS) {
                $Type = 'vMotion'
            } ElseIf ($vMotion.Group[0].Host.Name -eq $DstHost) {
                $Type = 's-vMotion'
            } Else {
                $Type = 'Both'
            }

            # Add the current vMotion into the $Results list
            $Results.Add([PSCustomObject][Ordered]@{
                    PSTypeName = 'vMotion.Object'
                    Name       = $vMotion.Group[0].Vm.Name
                    Type       = $Type
                    SrcHost    = $vMotion.Group[0].Host.Name
                    DstHost    = $DstHost
                    SrcDS      = $vMotion.Group[0].Ds.Name
                    DstDS      = $DstDS
                    SrcCluster = $vMotion.Group[0].ComputeResource.Name
                    DstCluster = $vMotion.Group[1].ComputeResource.Name
                    SrcDC      = $vMotion.Group[0].Datacenter.Name
                    DstDC      = $DstDC
                    # Hopefully people aren't performing vMotions that take >24 hours, because I'm ignoring days in the string
                    Duration   = (New-TimeSpan -Start $vMotion.Group[0].CreatedTime -End $vMotion.Group[1].CreatedTime).ToString('hh\:mm\:ss')
                    StartTime  = $vMotion.Group[0].CreatedTime.ToLocalTime()
                    EndTime    = $vMotion.Group[1].CreatedTime.ToLocalTime()
                    # Making an assumption that all events with an empty username are DRS-initiated
                    Username   = & { If ($vMotion.Group[0].UserName) { $vMotion.Group[0].UserName } Else { 'DRS' } }
                    ChainID    = $vMotion.Group[0].ChainID
                })
        } #If vMotion Group % 2
        ElseIf ($vMotion.Group.Count % 2 -eq 1) {
            $message = ("{0}: vMotion chain ID {1} had an odd number of events; cannot match start/end times. Inspect `$vMotion for more details." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $($vMotion.Group[0].ChainID -join ', '))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            $exitCode = 1
        }
    }

    If ($results.Name.Count -gt 0) {
        $message = ("{0}: vMotion entries:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($results | Format-List -Property * | Out-String))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("vMotionCount={0}" -f $results.Name.Count)

        Disconnect-VIServer -Confirm:$false
        Exit $exitCode
    }
    Else {
        $message = ("{0}: No results." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("vMotionCount=0")

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