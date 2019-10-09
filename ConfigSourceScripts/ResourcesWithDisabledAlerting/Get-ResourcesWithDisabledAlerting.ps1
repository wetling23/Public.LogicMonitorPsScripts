<#
    .DESCRIPTION
        Using the LogicMonitor API, retrieves resources (devices/websites), for which alerting is disabled.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 18 September 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/ResourcesWithDisabledAlerting
#>
Function Get-ResourceAlertingDisabled {
    <#
        .DESCRIPTION
            Using the LogicMonitor API, retrieves resources (devices/websites), for which alerting is disabled.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 16 September 2019
                - Initial release
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AccessId,

        [Parameter(Mandatory)]
        [securestring]$AccessKey,

        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    #region Get data
    $message = ("{0}: Starting job to retrieve all devices." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $null = Start-Job -Name GetDevices -ScriptBlock { param($AccessId, $AccessKey, $AccountName) (Get-LogicMonitorDevice -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName -BlockLogging).Where( { $_.alertDisableStatus -ne 'none-none-none' } ) } -ArgumentList $AccessId, $AccessKey, $AccountName

    $message = ("{0}: Starting job to retrieve all websites." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $null = Start-Job -Name GetWebsites -ScriptBlock { param($AccessId, $AccessKey, $AccountName) (Get-LogicMonitorWebsite -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName -BlockLogging).Where( { $_.alertDisableStatus -ne 'none-none-none' } ) } -ArgumentList $AccessId, $AccessKey, $AccountName

    Do {
        $getDevicesRunning = Get-Job -Name GetDevices -ErrorAction SilentlyContinue | Where-Object { $_.state -eq 'Running' }
        $getWebsitesRunning = Get-Job -Name GetWebsites -ErrorAction SilentlyContinue | Where-Object { $_.state -eq 'Running' }

        If (($getDevicesRunning -is [system.array]) -or ($getWebsitesRunning -is [system.array])) {
            $message = ("{0}: Looks like there are too many copies of GetDevices ({1}) or GetWebsites ({2}). To prevent errors, {3} will exit." -f [datetime]::Now, $getDevicesRunning.Count, $getWebsitesRunning.Count, $MyInvocation.MyCommand)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }

            Exit 1
        }

        If (($getDevicesRunning -is [system.array]) -or ($getWebsitesRunning -is [system.array])) {
            $message = ("{0}: Looks like there are too many copies of GetDevices ({1}) or GetWebsites ({2}). To prevent errors, {3} will exit." -f [datetime]::Now, $getDevicesRunning.Count, $getWebsitesRunning.Count, $MyInvocation.MyCommand)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }

            Exit 1
        }

        $message = ("{0}: Job(s) not done, waiting 15 seconds." -f [datetime]::Now)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Start-Sleep -Seconds 15
    }
    While ($getDevicesRunning -or $getWebsitesRunning)

    $alertingDisabledDevices = [System.Collections.Generic.List[PSObject]]@(Receive-Job -Name GetDevices; Remove-Job -Name GetDevices)
    $alertingDisabledWebsites = [System.Collections.Generic.List[PSObject]]@(Receive-Job -Name GetWebsites; Remove-Job -Name GetWebsites)

    If (($alertingDisabledDevices -eq "Error") -or ($alertingDisabledWebsites -eq "Error")) {
        $message = ("{0}: Error retrieving devices or websites. To prevent errors, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }

        Exit 1
    }
    Else {
        $message = ("{0}: Retrieved a total of {1} (filtered) devices and {2} (filtered) websites." -f [datetime]::Now, $alertingDisabledDevices.Count, $alertingDisabledWebsites.Count)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    }
    #endregion Get data

    #region Process data
    $message = ("{0}: Generating output for devices with disabled alerting." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $deviceOutput = $alertingDisabledDevices | ForEach-Object {
        $alertingStatus = $_.alertDisableStatus -split '-'

        $_ | Select-Object id, name, displayName, @{ Name = 'groupAlertingStatus'; Expression = { If ($alertingStatus[0] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'resourceAlertingStatus'; Expression = { If ($alertingStatus[1] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'instanceAlertingStatus'; Expression = { If ($alertingStatus[2] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'Type'; Expression = { 'Device' } }
    }

    $message = ("{0}: Generating output for websites with disabled alerting." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $websiteOutput = $alertingDisabledWebsites | ForEach-Object {
        $alertingStatus = $_.alertDisableStatus -split '-'

            $_ | Select-Object id, name, displayName, @{ Name = 'groupAlertingStatus'; Expression = { If ($alertingStatus[0] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'resourceAlertingStatus'; Expression = { If ($alertingStatus[1] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'instanceAlertingStatus'; Expression = { If ($alertingStatus[2] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'Type'; Expression = { 'Website' } }
    }
    #endregion Process data

    $message = ("{0}: Found {1} devices and {2} websites. Returning data" -f [datetime]::Now, $deviceOutput.Count, $websiteOutput.Count)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $deviceOutput
    $websiteOutput
}

# Initialize variables.
$timer = [system.diagnostics.stopwatch]::startNew()
$server = "##system.hostname##"
$accountName = '##custom.lmApiAcctName##'
$accessId = '##lmaccess.id##'
$accessKey = '##lmaccess.key##' | ConvertTo-SecureString -AsPlainText -Force

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the collector will write the log file.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Resources_With_Disabled_Alerting-collection-$server.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

If (-NOT (Get-Module -Name LogicMonitor -ListAvailable)) {
    $message = ("{0}: The required LogicMonitor PowerShell module is not installed, attempting to install it." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    Try {
        Install-Module -Name LogicMonitor -Force -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error installing the LogicMonitor PowerShell module. To prevent errors, {1} will exit. The specific error is: {2}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }

        Exit 1
    }
}

$message = ("{0}: Calling Get-ResourceAlertingDisabled with {1}, for {2}." -f [datetime]::Now, $accessId, $accountName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$output = Get-ResourceAlertingDisabled -AccessId $accessId -AccessKey $accessKey -AccountName $accountName -LogFile $logFile

If ($output.Count -gt 0) {
    $message = ("{0}: A total of {1} resources found." -f [datetime]::Now, $output.Count)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $output | ConvertTo-Json
}
Else {
    $message = ("{0}: Zero resources found." -f [datetime]::Now, $output.Count)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
}

$timer.Stop()

$message = ("{0}: {1} completed successfully. The script took {2}:{3}:{4} (hours:minutes:seconds) to run." -f [datetime]::Now, $MyInvocation.MyCommand, $timer.Elapsed.Hour, $timer.Elapsed.Minutes, $timer.Elapsed.Seconds)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Exit 0