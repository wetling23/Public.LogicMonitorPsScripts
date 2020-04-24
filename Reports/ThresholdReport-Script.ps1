<#
    .DESCRIPTION
        Effectively duplicates the "Threshold Report" in LogicMonitor's GUI.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 3 September 2019
            - Initial release.
        V1.0.0.1 date: 31 October 2019
        V1.0.0.2 date: 24 April 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/Reports/ThresholdReport-Script.ps1
    .PARAMETER AccessId
        Mandatory parameter. Represents the access ID used to connected to LogicMonitor's REST API.
    .PARAMETER AccessKey
        Mandatory parameter. Represents the access key used to connected to LogicMonitor's REST API.
    .PARAMETER AccountName
        Mandatory parameter. Represents the subdomain of the LogicMonitor customer.
    .PARAMETER GroupName
        When included, the script will filter the list or retrieved devices, to include only those in the specified device group.
    .PARAMETER OutputPath
        When provided, the script will output the report to this path.
    .PARAMETER EventLogSource
        When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
    .PARAMETER LogPath
        When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Verbose -EventLogSource LmReport

        In this example, the script gets all devices from LogicMonitor and generates a threshold report for them. Verbose logging is written to the console host and Windows Application log with the "LmReport" event source.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Acme Inc" -Verbose -LogPath C:\Temp\log.txt

        In this example, the script gets all devices from LogicMonitor, in the "Acme Inc" group and generates a threshold report for them. Verbose logging is written to the console host and C:\Temp\log.txt.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Customer/Servers" -OutputPath C:\temp

        In this example, the script gets all devices from LogicMonitor, in the "Customers/Servers" servers group and generates a threshold report for them. Limited logging is written to the console host only. The results are written to C:\temp.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$AccessId,

    [Parameter(Mandatory)]
    [securestring]$AccessKey,

    [Parameter(Mandatory)]
    [string]$AccountName,

    [string]$GroupName,

    [ValidateScript( {
            If (-NOT ($_ | Test-Path) ) {
                Throw "Folder does not exist."
            }
            If (-NOT ($_ | Test-Path -PathType Container) ) {
                Throw "The Path argument must be a folder."
            }
            Return $true
        })]
    [System.IO.DirectoryInfo]$OutputPath,

    [string]$EventLogSource,

    [string]$LogPath
)
#Requires -Modules LogicMonitor

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType First -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType First -Message $message }

# Initialize variables.
$group = [System.Collections.Generic.List[PSObject]]::new()
$progressCounter = 0
$httpVerb = 'GET'

If ($PSBoundParameters['Verbose']) {
    $commandParams = @{
        Verbose     = $true
        AccessId    = $AccessId
        AccessKey   = $AccessKey
        AccountName = $AccountName
    }

    If ($EventLogSource -and (-NOT $LogPath)) {
        $CommandParams.Add('EventLogSource', $EventLogSource)
    }
    ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $CommandParams.Add('LogPath', $LogPath)
    }
}
Else {
    If ($EventLogSource -and (-NOT $LogPath)) {
        $commandParams = @{
            EventLogSource = $EventLogSource
            AccessId       = $AccessId
            AccessKey      = $AccessKey
            AccountName    = $AccountName
        }
    }
    ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $commandParams = @{
            LogPath     = $LogPath
            AccessId    = $AccessId
            AccessKey   = $AccessKey
            AccountName = $AccountName
        }
    }
}

$allLmDevices = Get-LogicMonitorDevice @commandParams

If ($allLmDevices -eq "Error") {
    $message = ("{0}: Too few devices retrieved. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

    Exit 1
}

If ($GroupName) {
    $message = ("{0}: Filtering for devices in group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $devices = ($allLmDevices).Where({ ($_.systemProperties.name -eq 'system.groups') -and ($_.systemProperties.value -match $GroupName) })

    Remove-Variable allLmDevices -Force

    $message = ("{0}: Found {1} devices in group {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $devices.Count, $GroupName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
}
Else {
    $message = ("{0}: No device filter applied. There are {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $allLmDevices.Count)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $devices = $allLmDevices

    Remove-Variable allLmDevices -Force
}

Foreach ($device in $devices) {
    $progressCounter++

    $message = ("{0}: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Working on {1}. This is device {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName, $progressCounter, $devices.count)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $resourcePath = "/device/devices/$($device.id)/instances"
    $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath"
    $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)

    # Concatenate Request Details
    $requestVars = $httpVerb + $epoch + $resourcePath

    # Construct Signature
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto(([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))))
    $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
    $signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
    $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))

    # Create the web client object and add headers
    $headers = @{
        "Authorization" = "LMv1 $AccessId`:$signature`:$epoch"
        "Content-Type"  = "application/json"
        "X-Version"     = 2
    }

    $instances = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

    Foreach ($instance in $instances.items) {
        $resourcePath = "/setting/datasources/$($instance.dataSourceId)"
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath"

        $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)

        # Concatenate Request Details
        $requestVars = $httpVerb + $epoch + $resourcePath

        # Construct Signature
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto(([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))))
        $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
        $signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
        $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))

        # Create the web client object and add headers
        $headers = @{
            "Authorization" = "LMv1 $AccessId`:$signature`:$epoch"
            "Content-Type"  = "application/json"
            "X-Version"     = 2
        }

        $datasource = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        $resourcePath = "/device/devices/$($device.id)/devicedatasources/$($instance.deviceDataSourceId)/instances/$($instance.id)/alertsettings"
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath"
        $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)

        # Concatenate Request Details
        $requestVars = $httpVerb + $epoch + $resourcePath

        # Construct Signature
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto(([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))))
        $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
        $signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
        $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))

        # Create the web client object and add headers
        $headers = @{
            "Authorization" = "LMv1 $AccessId`:$signature`:$epoch"
            "Content-Type"  = "application/json"
            "X-Version"     = 2
        }

        $datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        Foreach ($datapoint in $datapoints.items) {
            $group.Add(
                [PSCustomObject]@{
                    DeviceName                 = $device.displayName
                    DataSource                 = ($instance.name -split '-', 2)[0]
                    Instance                   = ($instance.name -split '-', 2)[-1]
                    Datapoint                  = $datapoint.dataPointName
                    EffectiveThreshold         = $datapoint.globalAlertExpr
                    CollectMethod              = If (($instance.name -split '-', 2)[0] -eq $datasource.name.TrimEnd('-')) { $datasource.collectMethod } Else { $null }
                    CollectionInterval_Minutes = If (($instance.name -split '-', 2)[0] -eq $datasource.name.TrimEnd('-')) { $datasource.collectInterval / 60 } Else { $null }
                    AlertTriggerInterval       = $datasource.dataPoints | Where-Object { $_.name -eq $datapoint.dataPointName } | Select-Object -ExpandProperty alertTransitionInterval
                }
            )
        }
    }
}

If ($OutputPath) {
    Try {
        $group | Export-Csv -Path "$OutputPath\thresholdReport-$GroupName.csv" -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OutputPath, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$OutputPath\$file")
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Exit 0
}
Else {
    $group
}

Exit 0