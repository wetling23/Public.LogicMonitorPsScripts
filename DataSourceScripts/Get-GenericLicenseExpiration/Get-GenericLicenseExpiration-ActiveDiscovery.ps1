<#
    .DESCRIPTION
        Use LogicMonitor auto or manual "genericexpirationdata" LM properties and return days until expiration.
    .NOTES
        Author: Mike Hashemi
        V2022.12.17.0
        V2022.12.18.0
        V2023.01.09.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-GenericLicenseExpiration
#>
[CmdletBinding()]
param()

#region Setup
#region Initialize variables
$autoExpirationList = '##auto.genericexpirationdata##'
$manualExpirationList = '##manual.genericexpirationdata##'
$computerName = '##hostname##'

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource_Get_Generic_Item_Expiration_Date_AD-$computerName.log"
#endregion Initialize variables
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Parse LM property strings
#region Generate array
If (($autoExpirationList -match 'Expiration\=') -and -NOT($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.installedlicences populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $autoExpirationList -split ','
} ElseIf (-NOT($autoExpirationList -match 'Expiration\=') -and ($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.installedlicences populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $manualExpirationList -split ','
} ElseIf (-NOT($autoExpirationList -match 'Expiration\=') -and -NOT($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: No properly-formatted licenses detected. Verify that the property is formatted correctly (e.g. @{Name=Hardware; Expiration=Sun Dec 17 2023},@{Name=AV Engine; Expiration=Sun Dec 17 2023})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
} ElseIf (($autoExpirationList -match 'Expiration\=') -and ($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found both auto and manual.genericexpirationdata populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $autoExpirationList -split ','
    $discoveredExpirations += $manualExpirationList -split ','
}
#endregion Generate array

#region Parse array
If ($discoveredExpirations) {
    $message = ("{0}: Converting string data to an array of objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $expirationObjects = Foreach ($item in $discoveredExpirations) {
        [pscustomObject][Management.Automation.Language.Parser]::ParseInput(
            $item,
            [ref] $null,
            [ref] $null).
        EndBlock.Statements[0].PipelineElements[0].Expression.SafeGetValue()
    }
}
#endregion Parse array
#endregion Parse LM property strings

#region Output
Foreach ($item in $expirationObjects) {
    $message = ("{0}: Returning instance: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $item.Name)
    $message | Out-File -FilePath $logFile -Append

    Write-Host ("{0}##{1}" -f ($item.Name -replace '\s+'), $item.Name)
}
#endregion Output

Exit 0