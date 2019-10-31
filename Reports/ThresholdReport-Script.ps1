<#
    .DESCRIPTION
        Effectively duplicates the "Threshold Report" in LogicMonitor's GUI.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 3 September 2019
            - Initial release.
        V1.0.0.1 date: 31 October 2019
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
        Default value is "LogicMonitorThresholdReport" Represents the name of the desired source, for Event Log logging.
    .PARAMETER BlockLogging
        When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name>

        In this example, the script gets all devices from LogicMonitor and generates a threshold report for them. Output is written to the Windows Application log with the default event source.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Acme Inc" -BlockLogging -Verbose

        In this example, the script gets all devices from LogicMonitor, in the "Acme Inc" group and generates a threshold report for them. Verbose output is written only to the console host.
    .EXAMPLE
        PS C:\> DeviceThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Customer/Servers" -OutputPath C:\temp

        In this example, the script gets all devices from LogicMonitor, in the "Acme Inc" servers group and generates a threshold report for them. Output is written to the Windows Application log with the default event source. The results are written to C:\temp.
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

    [string]$EventLogSource = 'LogicMonitorThresholdReport',

    [switch]$BlockLogging
)

#Requires -RunAsAdministrator
#Requires -Modules LogicMonitor

If (-NOT($BlockLogging)) {
    $return = Add-EventLogSource -EventLogSource $EventLogSource

    If ($return -ne "Success") {
        $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
        Write-Host $message

        $BlockLogging = $True
    }
}

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

# Initialize variables.
$group = [System.Collections.Generic.List[PSObject]]::new()
$progressCounter = 0
$httpVerb = 'GET'

If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') {
    $commandParams = @{
        Verbose        = $true
        EventLogSource = $EventLogSource
    }
}
Else {
    $commandParams = @{EventLogSource = $EventLogSource }
}

$allLmDevices = Get-LogicMonitorDevice -AccessId $AccessId -AccessKey $AccessKey -AccountName $AccountName @commandParams

If ($allLmDevices -eq "Error") {
    $message = ("{0}: Too few devices retrieved. To prevent errors, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

    Exit 1
}

If ($GroupName) {
    $message = ("{0}: Filtering for devices in group {1}." -f [datetime]::Now, $GroupName)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    $devices = ($allLmDevices).Where({ ($_.systemProperties.name -eq 'system.groups') -and ($_.systemProperties.value -match $GroupName) })

    $message = ("{0}: Found {1} devices in group {2}." -f [datetime]::Now, $devices.Count, $GroupName)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }
}
Else {
    $message = ("{0}: No device filter applied. There are {1} devices." -f [datetime]::Now, $allLmDevices.Count)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    $devices = $allLmDevices

    Remove-Variable allLmDevices -Force
}

Foreach ($device in $devices) {
    $progressCounter++
    $message = ("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++`r`n{0}: Working on {1}. This is device {2} of {3}." -f [datetime]::Now, $device.displayName, $progressCounter, $filteredDeviceList.count)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

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
    $file = "thresholdReport-$GroupName.csv"
    Try {
        $group | Export-Csv -Path "$OutputPath\$file" -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f [datetime]::Now, $OutputPath, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f [datetime]::Now, "$OutputPath\$file")
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Exit 0
}
Else {
    $group
}

Exit 0