<#
    .DESCRIPTION
        Using the LogicMonitor API, retrieves resources (devices/websites), for which alerting is disabled.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 18 September 2019
            - Initial release
        V1.0.0.1 date: 14 October 2019
        V1.0.0.2 date: 10 May 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/ResourcesWithDisabledAlerting
    .EXAMPLE
        PS C:> .\Get-ResourcesWithDisabledAlerting -AccessId <access ID> -AccessKey <access key> -AccountName <account name>

        In this example, the script will get all devices and websites, returning a comma-separated list of them, with alerting disabled. If the custom.GroupAlertingDisabled property is defined on the device in LogicMonitor, then only devices/websites in that group (and sub-groups) will be returned.
#>
Function Get-ResourceAlertingDisabled {
    <#
        .DESCRIPTION
            Using the LogicMonitor API, retrieves resources (devices/websites), for which alerting is disabled.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 16 September 2019
                - Initial release
            V1.0.0.1 date: 10 May 2021
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
        [string]$DeviceFilter,

        [Parameter(Mandatory)]
        [string]$WebsiteFilter,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    If ([Console]::InputEncoding -is [Text.UTF8Encoding] -and [Console]::InputEncoding.GetPreamble().Length -ne 0) {
        [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    }

    #region Get data
    $message = ("{0}: Starting job to retrieve all devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $null = Start-Job -Name GetDevices -ScriptBlock {
        param(
            $AccessId,
            $AccessKey,
            $AccountName,
            $DeviceFilter,
            $LogFile
        )

        $devices = (Get-LogicMonitorDevice -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName -Filter $DeviceFilter -Verbose -LogPath $LogFile).Where( { $_.alertDisableStatus -ne 'none-none-none' } )

        $message = ("{0}: `$devices contains {1} objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $devices.id.count)
        Write-Host $message; $message | Out-File -FilePath $LogFile -Append

        $devices
    } -ArgumentList $AccessId, $AccessKey, $AccountName, $DeviceFilter, $LogFile

    $message = ("{0}: Starting job to retrieve all websites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $null = Start-Job -Name GetWebsites -ScriptBlock {
        param(
            $AccessId,
            $AccessKey,
            $AccountName,
            $WebsiteFilter,
            $LogFile
        )

        $websites = (Get-LogicMonitorWebsite -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName -Filter $WebsiteFilter -LogPath $LogFile).Where( { $_.alertDisableStatus -ne 'none-none-none' } )

        $message = ("{0}: `$websites contains {1} objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $websites.id.count)
        Write-Host $message; $message | Out-File -FilePath $LogFile -Append

        $websites
    } -ArgumentList $AccessId, $AccessKey, $AccountName, $WebsiteFilter, $LogFile

    Do {
        $getDevicesRunning = Get-Job -Name GetDevices -ErrorAction SilentlyContinue | Where-Object { $_.state -eq 'Running' }
        $getWebsitesRunning = Get-Job -Name GetWebsites -ErrorAction SilentlyContinue | Where-Object { $_.state -eq 'Running' }

        If (($getDevicesRunning -is [system.array]) -or ($getWebsitesRunning -is [system.array])) {
            $message = ("{0}: Looks like there are too many copies of GetDevices ({1}) or GetWebsites ({2}). To prevent errors, {3} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $getDevicesRunning.Count, $getWebsitesRunning.Count, $MyInvocation.MyCommand)
            Write-Error $message; $message | Out-File -FilePath $LogFile -Append

            Exit 1
        }

        If (($getDevicesRunning -is [system.array]) -or ($getWebsitesRunning -is [system.array])) {
            $message = ("{0}: Looks like there are too many copies of GetDevices ({1}) or GetWebsites ({2}). To prevent errors, {3} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $getDevicesRunning.Count, $getWebsitesRunning.Count, $MyInvocation.MyCommand)
            Write-Error $message; $message | Out-File -FilePath $LogFile -Append

            Exit 1
        }

        $message = ("{0}: Job(s) not done, waiting 15 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $LogFile -Append

        Start-Sleep -Seconds 15
    }
    While ($getDevicesRunning -or $getWebsitesRunning)

    $message = ("{0}: Retrieving data from the jobs." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $alertingDisabledDevices = [System.Collections.Generic.List[PSObject]]@(Receive-Job -Name GetDevices; Remove-Job -Name GetDevices)
    $alertingDisabledWebsites = [System.Collections.Generic.List[PSObject]]@(Receive-Job -Name GetWebsites; Remove-Job -Name GetWebsites)

    If (($alertingDisabledDevices -eq "Error") -or ($alertingDisabledWebsites -eq "Error")) {
        $message = ("{0}: Error retrieving devices or websites. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Error $message; $message | Out-File -FilePath $LogFile -Append

        Exit 1
    }
    Else {
        $message = ("{0}: Retrieved a total of {1} (filtered) devices and {2} (filtered) websites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $alertingDisabledDevices.id.Count, $alertingDisabledWebsites.id.Count)
        Write-Host $message; $message | Out-File -FilePath $LogFile -Append
    }
    #endregion Get data

    #region Process data
    $message = ("{0}: Generating output for devices with disabled alerting." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $deviceOutput = $alertingDisabledDevices | ForEach-Object {
        $alertingStatus = $_.alertDisableStatus -split '-'

        $_ | Select-Object id, name, displayName, @{ Name = 'groupAlertingStatus'; Expression = { If ($alertingStatus[0] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'resourceAlertingStatus'; Expression = { If ($alertingStatus[1] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'instanceAlertingStatus'; Expression = { If ($alertingStatus[2] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'Type'; Expression = { 'Device' } }
    }

    $message = ("{0}: Generating output for websites with disabled alerting." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $websiteOutput = $alertingDisabledWebsites | ForEach-Object {
        $alertingStatus = $_.alertDisableStatus -split '-'

        $_ | Select-Object id, name, displayName, @{ Name = 'groupAlertingStatus'; Expression = { If ($alertingStatus[0] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'resourceAlertingStatus'; Expression = { If ($alertingStatus[1] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'instanceAlertingStatus'; Expression = { If ($alertingStatus[2] -eq 'none') { 'Enabled' } Else { 'Disabled' } } }, @{ Name = 'Type'; Expression = { 'Website' } }
    }
    #endregion Process data

    $message = ("{0}: Found {1} devices and {2} websites. Returning data." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $deviceOutput.Count, $websiteOutput.Count)
    Write-Host $message; $message | Out-File -FilePath $LogFile -Append

    $deviceOutput
    $websiteOutput
}

# Initialize variables.
If ([Console]::InputEncoding -is [Text.UTF8Encoding] -and [Console]::InputEncoding.GetPreamble().Length -ne 0) {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
}
$timer = [system.diagnostics.stopwatch]::startNew()
$server = "##system.hostname##"
$accountName = '##custom.lmApiAcctName##'
$accessId = '##lmaccess.id##'
$accessKey = '##lmaccess.key##' | ConvertTo-SecureString -AsPlainText -Force
$customerName = '##custom.GroupAlertingDisabled##'
$DeviceFilter = "filter=name~`"*`""
$WebsiteFilter = "filter=name~`"*`""

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the collector will write the log file.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Resources_With_Disabled_Alerting-collection-$server.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

If (-NOT (Get-Module -Name LogicMonitor -ListAvailable)) {
    $message = ("{0}: The required LogicMonitor PowerShell module is not installed, attempting to install it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    Try {
        Install-Module -Name LogicMonitor -Force -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error installing the LogicMonitor PowerShell module. To prevent errors, {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}

$message = ("{0}: Calling Get-ResourceAlertingDisabled with {1} for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $accessId, $accountName)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

If ($customerName) {
    $deviceFilter = "filter=systemProperties.value~`"$customerName`""
    $websiteGroupId = (Get-LogicMonitorWebsiteGroup -AccessId $accessId -AccessKey $accessKey -AccountName $accountName -Filter "filter=name:`"$CustomerName`"" -LogPath $logFile).id

    If ($websiteGroupId) {
        $websiteFilter = "filter=groupId:$websiteGroupId"
    }
}

$message = ("{0}: Device filter:`r`n`t{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $deviceFilter)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$message = ("{0}: Website filter:`r`n`t{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $websiteFilter)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$output = Get-ResourceAlertingDisabled -AccessId $accessId -AccessKey $accessKey -AccountName $accountName -DeviceFilter $deviceFilter -WebsiteFilter $websiteFilter -LogFile $logFile

If ($output.id.Count -gt 0) {
    $message = ("{0}: A total of {1} resources found." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $output.Count)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $output | ConvertTo-Csv -NoTypeInformation
}
Else {
    $message = ("{0}: Zero resources found." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $output.Count)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append
}

$timer.Stop()

$message = ("{0}: {1} completed successfully. The script took {2}:{3}:{4} (hours:minutes:seconds) to run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $timer.Elapsed.Hour, $timer.Elapsed.Minutes, $timer.Elapsed.Seconds)
$message | Out-File -FilePath $logFile -Append

Exit 0