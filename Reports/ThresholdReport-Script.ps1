<#
    .DESCRIPTION
        Effectively duplicates the "Threshold Report" in LogicMonitor's GUI.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 3 September 2019
            - Initial release.
        V1.0.0.1 date: 31 October 2019
        V1.0.0.2 date: 24 April 2020
        V1.0.0.3 date: 28 October 2020
        V1.0.0.4 date: 13 May 2021
        V1.0.0.5 date: 30 July 2021
        V2022.03.25.0
        V2022.04.14.0
        V2022.12.14.0
        V2023.03.28.0
        V2023.04.01.0
        V2023.09.05.0
        V2024.04.12.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/Reports/ThresholdReport-Script.ps1
    .PARAMETER AccessId
        Mandatory parameter. Represents the access ID used to connected to LogicMonitor's REST API.
    .PARAMETER AccessKey
        Mandatory parameter. Represents the access key used to connected to LogicMonitor's REST API.
    .PARAMETER AccountName
        Mandatory parameter. Represents the subdomain of the LogicMonitor customer.
    .PARAMETER GroupName
        Represents the name of the desired LogicMonitor resource group. When included, the script will filter the list of retrieved devices, to include only those in the specified device group.
    .PARAMETER GroupId
        Represents the ID of the desired LogicMonitor resource group. When included, the script will filter the list of retrieved devices, to include only those in the specified device group.
    .PARAMETER GroupFilter
        Represents a string matching the API's filter format. This parameter can be used to filter for groups matching certain criteria (e.g. "wmi.user" appears in customProperties).

        See https://www.logicmonitor.com/support/rest-api-developers-guide/v1/devices/get-devices#Example-Request-5--GET-all-devices-that-have-a-spe
    .PARAMETER DeviceFilter
        Represents a string matching the API's filter format. This parameter can be used to filter for devices matching certain criteria (e.g. "Microsoft Windows Server 2012 R2 Standard" appears in systemProperties).

        See https://www.logicmonitor.com/support/rest-api-developers-guide/v1/devices/get-devices#Example-Request-5--GET-all-devices-that-have-a-spe
    .PARAMETER Recursive
        When included, the script will identify all subgroups of the provided group (GroupName or GroupId) and will retrieve threshold data for devices in all of them. When ommitted, only data for devices in the identified group will be returned.
    .PARAMETER DataSourceId
        Represents the LogicMonitor ID of the desired DataSource. when included, the script will filter the list of retrieved devices, to include only those matching the "AppliesTo" of the selected DataSource.
    .PARAMETER OutputPath
        When provided, the script will output the report to this path.
    .PARAMETER EventLogSource
        When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
    .PARAMETER LogPath
        When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Verbose -EventLogSource LmReport

        In this example, the script gets all devices from LogicMonitor and generates a threshold report for them. Verbose logging is written to the console host and Windows Application log with the "LmReport" event source.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Acme Inc" -Verbose -LogPath C:\Temp\log.txt

        In this example, the script gets all devices from LogicMonitor, in the "Acme Inc" group and generates a threshold report for them. Verbose logging is written to the console host and C:\Temp\log.txt.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupName "Customer/Servers" -OutputPath C:\temp

        In this example, the script gets all devices from LogicMonitor, in the "Customers/Servers" group and generates a threshold report for them. Limited logging is written to the console host only. The results are written to C:\temp.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupId 12345

        In this example, the script gets all devices from LogicMonitor, in the group with ID 12345 and its sub-groups, and generates a threshold report for them. This is useful for cloud monitoring groups. Limited logging is written to the console host only. Output is sent only to the host.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupFilter 'filter=fullPath:location/servers/exchange'

        In this example, the script gets all devices from LogicMonitor, with "location/servers/exchange" in the fullPath property, and generates a threshold report for them. Limited logging is written to the console host only. Output is sent only to the host.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -DeviceFilter 'filter=systemProperties.value:"Microsoft Windows Server 2012 R2 Standard"'

        In this example, the script gets all devices from LogicMonitor, with "Microsoft Windows Server 2012 R2 Standard" in the system propreties, and generates a threshold report for them. Limited logging is written to the console host only. Output is sent only to the host.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -DeviceFilter 'filter=id:10'

        In this example, the script gets device with ID 10 from LogicMonitor, and generates a threshold report for it. Limited logging is written to the console host only. Output is sent only to the host.
    .EXAMPLE
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -DataSourceId 24

        In this example, the script gets all devices matching the AppliesTo of DataSource 24, and generates a threshold report for them. Limited logging is written to the console host only. Output is sent only to the host.
#>
#Requires -Modules LogicMonitor
[CmdletBinding(DefaultParameterSetName = 'AllDevices')]
Param (
    [Parameter(Mandatory)]
    [String]$AccessId,

    [Parameter(Mandatory)]
    [SecureString]$AccessKey,

    [Parameter(Mandatory)]
    [String]$AccountName,

    [Parameter(Mandatory, ParameterSetName = 'GroupFilter')]
    [String]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'IdFilter')]
    [String]$GroupId,

    [Parameter(Mandatory, ParameterSetName = 'GroupStringFilter')]
    [String]$GroupFilter,

    [Parameter(Mandatory, ParameterSetName = 'DeviceStringFilter')]
    [String]$DeviceFilter,

    [Parameter(ParameterSetName = 'GroupFilter')]
    [parameter(ParameterSetName = 'IdFilter')]
    [parameter(ParameterSetName = 'GroupStringFilter')]
    [Switch]$Recursive,

    [Parameter(Mandatory, ParameterSetName = 'DataSourceFilter')]
    [Int]$DataSourceId,

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

    [String]$EventLogSource,

    [String]$LogPath
)
#Requires -Modules LogicMonitor

#region Setup
#region Initialized variables
$reportList = [System.Collections.Generic.List[PSObject]]::new()
$reportDevices = [System.Collections.Generic.List[PSObject]]::new()
$searchedGroups = [System.Collections.Generic.List[PSObject]]::new()
$groupsToCheckForSubGroups = [System.Collections.Generic.List[PSObject]]::new()
$progressCounter = 0
$fileId = $GroupId
$httpVerb = 'GET'
$commandParams = @{
    AccessId    = $AccessId
    AccessKey   = $AccessKey
    AccountName = $AccountName
}
#endregion Initialized variables

#region Logging splatting
If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
    If ($EventLogSource -and (-NOT $LogPath)) {
        $loggingParams = @{
            Verbose        = $true
            EventLogSource = $EventLogSource
        }
    } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $loggingParams = @{
            Verbose = $true
            LogPath = $LogPath
        }
    } Else {
        $loggingParams = @{
            Verbose = $true
        }
    }
} Else {
    If ($EventLogSource -and (-NOT $LogPath)) {
        $loggingParams = @{
            EventLogSource = $EventLogSource
        }
    } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $loggingParams = @{
            LogPath = $LogPath
        }
    } Else {
        $loggingParams = @{}
    }
}
#endregion Logging splatting

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType First -Message $message

#region Import PowerShell modules
Try {
    Import-Module -Name LogicMonitor -ErrorAction Stop
} Catch {
    $message = ("{0}: Error importing the LogicMonitor module. To prevent errors, {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

    Exit 1
}
#endregion Import PowerShell modules
#endregion Setup

#region Get devices
Switch ($PsCmdlet.ParameterSetName) {
    "GroupStringFilter" {
        $GroupId = (Get-LogicMonitorDeviceGroup -Filter $Filter @commandParams @loggingParams).id
    }
    "GroupFilter" {
        $GroupId = (Get-LogicMonitorDeviceGroup -Name $GroupName @commandParams @loggingParams).id
    }
    { $_ -in "GroupFilter", "IdFilter", "GroupStringFilter" } {
        If ($GroupId.Count -eq 1) {
            $message = ("{0}: Proceeding with GroupId: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
        } ElseIf ($GroupId.Count -gt 1) {
            $message = ("{0}: Found {1} group IDs, selecting one and adding the other to the list of groups to check." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Foreach ($id in $GroupId) {
                $groupsToCheckForSubGroups.Add($id)
            }

            $GroupId = $groupProps[0]
        } Else {
            $message = ("{0}: Unable to locate the desired group(s). {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Error -Message $message

            Exit 1
        }

        If ($Recursive) {
            $message = ("{0}: Attempting to get all sub-groups of group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Do {
                $groupProps = (Get-LogicMonitorDeviceGroup -Id $GroupId @commandParams @loggingParams)
                $searchedGroups.Add($groupProps)

                If ($groupProps.subGroups.id.Count -gt 0) {
                    Foreach ($group in $groupProps.subGroups.id) {
                        $groupsToCheckForSubGroups.Add($group)
                    }
                }

                $GroupId = $groupsToCheckForSubGroups | Where-Object { $_ -notin $searchedGroups } | Select-Object -First 1

                $null = $groupsToCheckForSubGroups.Remove($GroupId)

            } While ($GroupId)
        } Else {
            Foreach ($group in $GroupId) {
                # Filling $searchedGroups this way, in case GroupId is an array. If it is, $searchedGroups considers that one item, which will cause problems when we gry to get devices in the foreach loop below.
                $searchedGroups.Add($group)
            }
        }

        $i
        Foreach ($group in $searchedGroups) {
            $i++
            $groupDevices = $null

            $message = ("{0}: Attempting to get devices from group {1}. This is group {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $group, $i, $searchedGroups.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $groupDevices = Get-LogicMonitorDevice @commandParams @loggingParams -Filter "filter=systemProperties.value:`"$($group.fullPath)`""

            Foreach ($device in $groupDevices) {
                $reportDevices.Add($device)
            }
        }
    }
    "AllDevices" {
        $reportDevices = Get-LogicMonitorDevice @commandParams @loggingParams
    }
    "DeviceStringFilter" {
        $reportDevices = Get-LogicMonitorDevice -Filter $DeviceFilter @commandParams @loggingParams
    }
    "DataSourceFilter" {
        $reportDevices = Get-LogicMonitorDataSourceDevice -Id 24 @commandParams @loggingParams
    }
}

If (($reportDevices -eq "Error") -or ($reportDevices.id.Count -lt 1)) {
    $message = ("{0}: Too few devices retrieved. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

    Exit 1
}

$message = ("{0}: Retrieved a total of {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $reportDevices.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
#endregion Get devices

#region Create report
Foreach ($device in $reportDevices) {
    $progressCounter++

    $message = ("{0}: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $message = ("{0}: Working on {1}. This is device {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName, $progressCounter, $reportDevices.count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $resourcePath = "/device/devices/$($device.id)/instances"
    $url = ("https://$AccountName.logicmonitor.com/santaba/rest$resourcePath{0}" -f $(If ($PsCmdlet.ParameterSetName -eq 'DataSourceFilter') { "?filter=dataSourceId:$DataSourceId" }))
    $epoch = [Math]::Round((New-TimeSpan -Start (Get-Date -Date "1/1/1970") -End (Get-Date).ToUniversalTime()).TotalMilliseconds)

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
        "X-Version"     = 3
    }

    $instances = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

    If ($instances.total -lt 1) {
        $message = ("{0}: No instances found under {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Continue
    }

    Foreach ($instance in $instances.items) {
        $resourcePath = "/setting/datasources/$($instance.dataSourceId)"
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath"

        $epoch = [Math]::Round((New-TimeSpan -Start (Get-Date -Date "1/1/1970") -End (Get-Date).ToUniversalTime()).TotalMilliseconds)

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
            "X-Version"     = 3
        }

        $message = ("{0}: Getting DataSource settings." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $datasource = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        $resourcePath = "/device/devices/$($device.id)/devicedatasources/$($instance.deviceDataSourceId)/instances/$($instance.id)/alertsettings"
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath"
        $epoch = [Math]::Round((New-TimeSpan -Start (Get-Date -Date "1/1/1970") -End (Get-Date).ToUniversalTime()).TotalMilliseconds)

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
            "X-Version"     = 3
        }

        $message = ("{0}: Getting datapoints." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        If ($datapoints.Total -lt 1) {
            $message = ("{0}: No datapoints retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Continue
        }
        Else {
            $message = ("{0}: Adding datapoints to the report list." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
        }

        Foreach ($datapoint in $datapoints.items) {
            $reportList.Add(
                [PSCustomObject]@{
                    DeviceName                 = $device.displayName
                    Categories                 = ($device.customProperties | Where-Object { $_.name -eq 'system.categories' }).value
                    DataSource                 = ($instance.name -split '-', 2)[0]
                    Instance                   = ($instance.name -split '-', 2)[-1]
                    Datapoint                  = $datapoint.dataPointName
                    DatapointDescription       = $datapoint.dataPointDescription
                    EffectiveThreshold         = $(If ($datapoint.alertExpr) { $datapoint.alertExpr } Else { $datapoint.globalAlertExpr })
                    GlobalThreshold            = $datapoint.globalAlertExpr
                    CollectMethod              = If (($instance.name -split '-', 2)[0] -eq $datasource.name.TrimEnd('-')) { $datasource.collectMethod } Else { $null }
                    CollectionInterval_Minutes = If (($instance.name -split '-', 2)[0] -eq $datasource.name.TrimEnd('-')) { $datasource.collectInterval / 60 } Else { $null }
                    AlertTriggerInterval       = $datasource.dataPoints | Where-Object { $_.name -eq $datapoint.dataPointName } | Select-Object -ExpandProperty alertTransitionInterval
                }
            )
        }
    }
}
#endregion Create report

#region Output
Switch ($PsCmdlet.ParameterSetName) {
    "GroupFilter" {
        $fileName = "thresholdReport-Group-$GroupName.csv"
    }
    { $_ -in ("IdFilter", "StringFilter") } {
        If (-NOT($fileId)) { $fileName = "thresholdReport-Filter-$(([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")).csv" } Else { $fileName = "thresholdReport-Group-$fileId.csv" }
    }
    "AllDevices" {
        $fileName = "thresholdReport-AllDevices.csv"
    }
    "DataSourceFilter" {
        $fileName = "thresholdReport-DataSource-$DataSourceId.csv"
    }
}

If ($OutputPath) {
    Try {
        $reportList | Export-Csv -Path "$($OutputPath.FullName.TrimEnd('\'))\$fileName" -ErrorAction Stop -NoTypeInformation
    } Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OutputPath, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$($OutputPath.FullName.TrimEnd('\'))\$fileName"); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Exit 0
} Else {
    $reportList
}
#endregion Output

Exit 0