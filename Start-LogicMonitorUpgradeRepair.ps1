<#
    .DESCRIPTION
        Workaround script for LogicMonitor agent upgrade errors. In some situations, copying the sbwinproxy and sbwinshutdown.exe files from the new version's tmp folder resolves upgrade failure.

        Run the script after a failure, when the new agent files have been copied to the target device.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 12 November 2019
            - Initial release
        V1.0.0.1 date: 18 June 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/Start-LogicMonitorUpgradeRepair.ps1
    .EXAMPLE
        PS C:\> Start-LogicMonitorUpgradeRepair.ps1

        There are no parameters.
#>

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
Write-Host $message

If (-NOT(Get-Service -Name logicmonitor* -ErrorAction SilentlyContinue)) {
    $message = ("{0}: No LogicMonitor collector installation found. No further action to take." -f [datetime]::Now)

    Exit 0
}

# Initialize variables.
$paths = @('C:\Program Files (x86)\LogicMonitor\Agent\bin\sbshutdown.exe', 'C:\Program Files (x86)\LogicMonitor\Agent\lib\sbwinproxy.exe')

Try {
    $message = ("{0}: Attempting to stop the LogicMonitor watchdog and agent services." -f [datetime]::Now)
    Write-Host $message

    Get-Service -Name logicmonitor* | Stop-Service -Force -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error stopping LogicMonitor services. To prevent errors, {1} will exit. The specific error is: {2}." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
    Write-Host $message
    
    Get-Service -Name logicmonitor* | Start-Service

    Exit 1
}

If (Get-ChildItem -Path 'C:\Program Files (x86)\LogicMonitor\Agent\tmp') {
    Foreach ($path in $paths) {
        $message = ("{0}: Attempting to remove {1} from the lib directory, before copying in a new version." -f [datetime]::Now, (Split-Path -Path $path -Leaf))
        Write-Host $message

        Try {
            Remove-Item -Path $path -Force -ErrorAction Stop
        } Catch {
            $message = ("{0}: Unexpected error removing the file. To prevent errors, {1} will exit. The specific error is: {2}." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
            Write-Host $message

            Exit 1
        }

        $message = ("{0}: Attempting to copy {1} from the tmp directory, to the lib directory." -f [datetime]::Now, (Split-Path -Path $path -Leaf))
        Write-Host $message

        Try {
            Get-ChildItem -Path 'C:\Program Files (x86)\LogicMonitor\Agent\tmp' -Include (Split-Path -Path $path -Leaf) -Recurse | Copy-Item -Destination (Split-Path -Path $path -Parent) -Force -ErrorAction Stop
        } Catch {
            $message = ("{0}: Unexpected error copying the file. To prevent errors, {1} will exit. The specific error is: {2}." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
            Write-Host $message

            Exit 1
        }
    }

    Try {
        $message = ("{0}: Attempting to restart the LogicMonitor services." -f [datetime]::Now)
        Write-Host $message

        Get-Service -Name logicmonitor* | Start-Service -ErrorAction Stop

        Exit 0
    }
    Catch {
        $message = ("{0}: Unexpected error starting LogicMonitor services. To prevent errors, {1} will exit. The specific error is: {2}." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
        Write-Host $message

        Exit 1
    }
}