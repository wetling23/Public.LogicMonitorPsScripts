<#
    .DESCRIPTION
        Query sensor data from Nimble Storage controllers.
    .NOTES
        V1.0.0.0 date: 28 July 2020
            - Note that this DataSource requires the HPENimblePowerShellToolkit, which is available in the PowerShell Gallery.
        V1.0.0.1 date: 9 December 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/NimbleStorage/Get-NimbleSensorInfo
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables.
# Need the computer for the log file name.
$computer = '##system.hostname##'
$pass = "##nim.pass##"
[pscredential]$credential = New-Object System.Management.Automation.PSCredential('##nim.user##', ($pass | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-NimbleSensors-ad-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

Try {
    Import-Module -Name 'HPENimblePowerShellToolkit' -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error importing module. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Setup

#region Main
$message = ("{0}: Attempting to connect to {1} as {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer, $credential.UserName)
$message | Out-File -FilePath $logFile -Append

Try {
    Connect-NSGroup -Group $computer -Credential $credential -IgnoreServerCertificate -ErrorAction Stop

    $message = ("{0}: Connected to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer)
    $message | Out-File -FilePath $logFile -Append
}
Catch {
    $message = ("{0}: Error connecting to {1}. Error: {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Getting shelf info." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$shelves = Get-NSShelf

If ($shelves.ctrlrs) {
    $message = ("{0}: Returning instance data." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Foreach ($shelf in $shelves.ctrlrs) {
        Write-Host ("Side{0}-{1}##Side{0}-{1}" -f $shelf.'cid', $shelf.'ctrlr_side')
    }

    Exit 0
}
Else {
    $message = ("{0}: No shelf data returned." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Main