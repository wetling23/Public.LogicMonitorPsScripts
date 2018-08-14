<#
.SYNOPSIS
    Sum the results of a CPU-utilization query, to display total CPU used by a user-defined list of processes.
.NOTES
    Author: Mike Hashemi
    V1.0.0.0 date: 7 December 2017
        - Initial release.
#>
[CmdletBinding()]
Param (
    [string[]]$ProcessName = ("PCCNTmon","ntrtscan","TMBMSRV")
)

# Multile-process monitor for DYN.
Function Get-CpuUsage {
    Param (
        $Process
    )

    $CPUPercent = @{
        Name = 'CPUPercent'
        Expression = {
            $TotalSec = (New-TimeSpan -Start $_.StartTime).TotalSeconds
            [Math]::Round(($_.CPU * 100 / $TotalSec), 2)
        }
    }
 
    Get-Process -Name $process* -ComputerName $hostname -ErrorAction SilentlyContinue | Select-Object -Property $CPUPercent,Name
}

# Initialize variables.
$hostname="##HOSTNAME##" # Target host for the script to query.
[string]$query = "select * from Win32_PerfRawData_PerfProc_Process"
[array]$counterData = $null # Will contain the process name and CPU utilization for each process.
[decimal]$totalCpu = 0 # Will contain the sum of the CPU utilization.

$processes = Get-WmiObject -Query $query

Foreach ($process in $processName) {
    Write-Debug ("Checking CPU utilization of: {0}" -f $process)
    $counterData += Get-CpuUsage -Process $process
}

Foreach ($item in $counterData) {
    $totalCpu += $item.CPUPercent
}

Write-Host $totalCpu