<#
    .DESCRIPTION
        Query Fortigate devices for License expiration and identify those expiring in 30-or-fewer/7-or-fewer days.
    .NOTES
        Author: Mike Hashemi
        V2022.2.7.0
        V2022.02.22.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Fortigate/LicenseExpiration
#>
[CmdletBinding()]
param()

#region Setup
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource_Fortigate_License_Expiration-$computerName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

# Initialize variables
$autoLicenseList = '##auto.installedlicenses##'
$manualLicenseList = '##manual.installedlicenses##'

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
}
ElseIf (($autoLicenseList -match 'Expiration\=') -and ($manualLicenseList -match 'Expiration\=')) {
    $message = ("{0}: Found both auto and manual.installedlicenses populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredLicenses = $autoLicenseList -split ','
    $discoveredLicenses += $manualLicenseList -split ','
}
#endregion Setup

#region Main
If ($discoveredLicenses) {
    $regex = '(\d{2}):(\d{2}):(\d{2})\s'
    $today = Get-Date
    $i = 0

    $message = ("{0}: Converting string data to an array of objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $licenseObjects = Foreach ($license in $discoveredLicenses) {
        [pscustomObject][Management.Automation.Language.Parser]::ParseInput(
            $license,
            [ref] $null,
            [ref] $null).
        EndBlock.Statements[0].PipelineElements[0].Expression.SafeGetValue()
    }

    $message = ("{0}: Calculating days until expiration." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Foreach ($license in $licenseObjects) {
        $i++

        $message = ("{0}: Parsing `"{1}`". This is license {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $license.Name, $i, $discoveredLicenses.Name.Count)
        $message | Out-File -FilePath $logFile -Append

        $license | Add-Member -MemberType NoteProperty -Name DaysUntilExpiration -Value (New-TimeSpan -Start $today -End $license.Expiration).Days -Force

        If ($license.DaysUntilExpiration -le 30) {
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value True -Force
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value False -Force
        } ElseIf ($license.DaysUntilExpiration -le 7) {
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value True -Force
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value False -Force
        } Else {
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value False -Force
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value False -Force
        }
    }

    ($licenseObjects | Out-String)

    Exit 0
}
Else {
    $message = ("{0}: No licenses retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 0
}
#endregion Main