<#
    .DESCRIPTION
        Use LogicMonitor auto or manual "installedlicenses" LM properties and return days until expiration.
    .NOTES
        Author: Mike Hashemi
        V2022.12.17.0
        V2022.12.18.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-GenericLicenseExpiration
#>
[CmdletBinding()]
param()

#region Setup
#region Initialize variables
$autoLicenseList = '##auto.installedlicenses##'
$manualLicenseList = '##manual.installedlicenses##'
$computerName = '##hostname##'
$today = Get-Date
$i = 0

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource_Generic_License_Expiration_Collection-$computerName.log"
#endregion Initialize variables
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Parse LM property strings
#region Generate array
If (($autoLicenseList -match 'Expiration\=') -and -NOT($manualLicenseList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.installedlicences populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredLicenses = $autoLicenseList -split ','
} ElseIf (-NOT($autoLicenseList -match 'Expiration\=') -and ($manualLicenseList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.installedlicences populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredLicenses = $manualLicenseList -split ','
} ElseIf (-NOT($autoLicenseList -match 'Expiration\=') -and -NOT($manualLicenseList -match 'Expiration\=')) {
    $message = ("{0}: No properly-formatted licenses detected. Verify that the property is formatted correctly (e.g. @{Name=Hardware; Expiration=Sun Dec 17 2023},@{Name=AV Engine; Expiration=Sun Dec 17 2023})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
} ElseIf (($autoLicenseList -match 'Expiration\=') -and ($manualLicenseList -match 'Expiration\=')) {
    $message = ("{0}: Found both auto and manual.installedlicenses populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredLicenses = $autoLicenseList -split ','
    $discoveredLicenses += $manualLicenseList -split ','
}
#endregion Generate array
#region Parse LM property strings

#region Parse array
If ($discoveredLicenses) {
    $message = ("{0}: Converting string data to an array of objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $licenseObjects = Foreach ($license in $discoveredLicenses) {
        [pscustomObject][Management.Automation.Language.Parser]::ParseInput(
            $license,
            [ref] $null,
            [ref] $null).
        EndBlock.Statements[0].PipelineElements[0].Expression.SafeGetValue()
    }
}
#endregion Parse array

#region Calculate days remaining
If ($licenseObjects) {
    $message = ("{0}: Calculating days until expiration." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Foreach ($license in $licenseObjects) {
        $daysUntilExpiration = $null
        $i++

        $message = ("{0}: Parsing `"{1}`". This is license {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($license.Name -replace '\s+'), $i, $licenseObjects.Name.Count)
        $message | Out-File -FilePath $logFile -Append

        $daysUntilExpiration = (New-TimeSpan -Start $today -End $license.Expiration).Days

        $message = ("{0}: {1} expires in {2} days." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($license.Name -replace '\s+'), $daysUntilExpiration)
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("{0}.DaysUntilExpiration={1}" -f ($license.Name -replace '\s+'), $daysUntilExpiration)
    }

    Exit 0
} Else {
    $message = ("{0}: No licenses retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Calculate days remaining