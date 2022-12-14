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
#>
[CmdletBinding(DefaultParameterSetName = 'AllDevices')]
Param (
    [Parameter(Mandatory)]
    [string]$AccessId,

    [Parameter(Mandatory)]
    [securestring]$AccessKey,

    [Parameter(Mandatory)]
    [string]$AccountName,

    [Parameter(Mandatory, ParameterSetName = 'GroupFilter')]
    [string]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'IdFilter')]
    [string]$GroupId,

    [Parameter(Mandatory, ParameterSetName = 'GroupStringFilter')]
    [string]$GroupFilter,

    [Parameter(Mandatory, ParameterSetName = 'DeviceStringFilter')]
    [string]$DeviceFilter,

    [Parameter(ParameterSetName = 'GroupFilter')]
    [parameter(ParameterSetName = 'IdFilter')]
    [parameter(ParameterSetName = 'GroupStringFilter')]
    [switch]$Recursive,

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

#region Setup
#region Initialized variables
$reportList = [System.Collections.Generic.List[PSObject]]::new()
$devices = [System.Collections.Generic.List[PSObject]]::new()
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
            #Verbose        = $False
            EventLogSource = $EventLogSource
        }
    } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $loggingParams = @{
            #Verbose = $False
            LogPath = $LogPath
        }
    } Else {
        <#$loggingParams = @{
            $Verbose = $null
        }#>
    }
}
#endregion Logging splatting

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Out-PsLogging @loggingParams -MessageType First -Message $message

#region Import PowerShell modules
Try {
    Import-Module -Name LogicMonitor -ErrorAction Stop
} Catch {
    $timer.Stop()

    $message = ("{0}: Error importing the LogicMonitor module. To prevent errors, {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
    Out-PsLogging @loggingParams -MessageType Error -Message $message

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
            $message = ("{0}: Proceeding with GroupId: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId)
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
        } ElseIf ($GroupId.Count -gt 1) {
            $message = ("{0}: Found {1} group IDs, selecting one and adding the other to the list of groups to check." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId.Count)
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Foreach ($id in $GroupId) {
                $groupsToCheckForSubGroups.Add($id)
            }

            $GroupId = $groupProps[0]
        } Else {
            $message = ("{0}: Unable to locate the desired group(s). {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            Out-PsLogging @loggingParams -MessageType Error -Message $message

            Exit 1
        }

        If ($Recursive) {
            $message = ("{0}: Attempting to get all sub-groups of group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId)
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Do {
                $groupProps = (Get-LogicMonitorDeviceGroup -Id $GroupId @commandParams @loggingParams)
                $searchedGroups.Add($GroupId)

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

        Foreach ($group in $searchedGroups) {
            $groupDevices = $null

            $message = ("{0}: Attempting to get devices from group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $group)
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $groupDevices = Get-LogicMonitorDevice -AccessId $accessid -AccessKey $accesskey -AccountName $AccountName -Filter "filter=hostGroupIds~$($group)" @loggingParams
            Foreach ($device in $groupDevices) {
                $devices.Add($device)
            }
        }
    }
    "AllDevices" {
        $devices = Get-LogicMonitorDevice @commandParams @loggingParams
    }
    "DeviceStringFilter" {
        $devices = Get-LogicMonitorDevice -Filter $DeviceFilter @commandParams @loggingParams
    }
}

If (($devices -eq "Error") -or ($devices.id.Count -lt 1)) {
    $message = ("{0}: Too few devices retrieved. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

    Exit 1
}

$message = ("{0}: Retrieved a total of {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $devices.id.Count)
If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
#endregion Get devices

#region Create report
Foreach ($device in $devices) {
    $progressCounter++

    $message = ("{0}: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $message = ("{0}: Working on {1}. This is device {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName, $progressCounter, $devices.count)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $resourcePath = "/device/devices/$($device.id)/instances"
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

    $instances = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

    If ($instances.total -lt 1) {
        $message = ("{0}: No instances found under {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName)
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

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

        $message = ("{0}: Getting DataSources." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

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

        $message = ("{0}: Getting datapoints." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        If ($datapoints.Total -lt 1) {
            $message = ("{0}: No datapoints retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Continue
        }
        Else {
            $message = ("{0}: Adding datapoints to the report list." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
        }

        Foreach ($datapoint in $datapoints.items) {
            $reportList.Add(
                [PSCustomObject]@{
                    DeviceName                 = $device.displayName
                    Categories                 = ($device.customProperties | Where-Object { $_.name -eq 'system.categories' }).value
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
#endregion Create report

#region Output
Switch ($PsCmdlet.ParameterSetName) {
    "GroupFilter" {
        $fileName = "thresholdReport-$GroupName.csv"
    }
    { $_ -in ("IdFilter", "StringFilter") } {
        If (-NOT($fileId)) { $fileName = "thresholdReport-$(([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")).csv" } Else { $fileName = "thresholdReport-$fileId.csv" }
    }
    "AllDevices" {
        $fileName = "thresholdReport-AllDevices.csv"
    }
}

If ($OutputPath) {
    Try {
        $reportList | Export-Csv -Path "$($OutputPath.FullName.TrimEnd('\'))\$fileName" -ErrorAction Stop -NoTypeInformation
    } Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OutputPath, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$($OutputPath.FullName.TrimEnd('\'))\$fileName")
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Exit 0
} Else {
    $reportList
}
#region Output

Exit 0