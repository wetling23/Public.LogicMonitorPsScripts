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
        PS C:\> .\ThresholdReport-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Filter 'filter=systemProperties.value:"Microsoft Windows Server 2012 R2 Standard"'

        In this example, the script gets all devices from LogicMonitor, with "Microsoft Windows Server 2012 R2 Standard" in the system propreties, and generates a threshold report for them. Limited logging is written to the console host only. Output is sent only to the host.
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

    [Parameter(Mandatory, ParameterSetName = 'StringFilter')]
    [string]$Filter,

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
$reportList = [System.Collections.Generic.List[PSObject]]::new()
$progressCounter = 0
$httpVerb = 'GET'

If ($PSBoundParameters['Verbose']) {
    $loggingParams = @{
        Verbose     = $true
    }

    If ($EventLogSource -and (-NOT $LogPath)) {
        $loggingParams.Add('EventLogSource', $EventLogSource)
    } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $loggingParams.Add('LogPath', $LogPath)
    }
} Else {
    If ($EventLogSource -and (-NOT $LogPath)) {
        $loggingParams = @{
            EventLogSource = $EventLogSource
            Verbose        = $False
        }
    } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
        $loggingParams = @{
            LogPath     = $LogPath
            Verbose     = $False
        }
    } Else {
        $loggingParams = @{
            Verbose     = $False
        }
    }
}

$commandParams = @{
    AccessId    = $AccessId
    AccessKey   = $AccessKey
    AccountName = $AccountName
}

If ($Filter) {
    $commandParams.Add("Filter", $Filter)
}

If ($GroupId) {
    $message = ("{0}: Attempting to get all sub-groups of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupId)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $resourcePath = "/device/groups/$GroupId"
    $queryParams = $null

    # Get current time in milliseconds
    $epoch = [Math]::Round((New-TimeSpan -Start (Get-Date -Date "1/1/1970") -End (Get-Date).ToUniversalTime()).TotalMilliseconds)

    # Concatenate Request Details
    $requestVars = $httpVerb + $epoch + $resourcePath

    # Construct Signature
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto(([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessKey))))
    $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
    $signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
    $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))

    # Construct Headers
    $headers = @{
        "Authorization" = "LMv1 $accessId`:$signature`:$epoch"
        "Content-Type"  = "application/json"
        "X-Version"     = 2
    }

    $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath$queryParams"

    $stopLoop = $false
    Do {
        Try {
            $response = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

            $stopLoop = $True
        } Catch {
            If ($_.Exception.Message -match '429') {
                $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                Start-Sleep -Seconds 60
            } ElseIf ($_.ErrorDetails -match 'invalid filter') {
                $message = ("{0}: LogicMonitor returned `"invalid filter`". Please validate the value of the -Filter parameter and try again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            } Else {
                $message = ("{0}: Unexpected error getting groups. To prevent errors, {1} will exit. If present, the following details were returned:`r`n
                Error message: {2}`r
                Error code: {3}`r
                Invoke-Request: {4}`r
                Headers: {5}`r
                Body: {6}" -f
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorMessage),
                    ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorCode), $_.Exception.Message, ($headers | Out-String), ($data | Out-String)
                )
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    If ($response.subGroups) {
        $message = ("{0}: Retrieved {1} groups under {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.subGroups.Count, $GroupId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $allLmDevices = Foreach ($group in $response.subGroups) {
            $message = ("{0}: Attempting to get devices from group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $group.id)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Get-LogicMonitorDevice -AccessId $accessid -AccessKey $accesskey -AccountName $AccountName -Filter "filter=hostGroupIds~$($group.id)" @loggingParams
        }

        $message = ("{0}: Retrieved {1} devices under {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $allLmDevices.id.Count, $GroupId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
} Else {
    $allLmDevices = Get-LogicMonitorDevice @commandParams @loggingParams
}

If ($allLmDevices -eq "Error") {
    $message = ("{0}: Too few devices retrieved. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

    Exit 1
}

Switch ($PsCmdlet.ParameterSetName) {
    "GroupFilter" {
        $fileName = "thresholdReport-$GroupName.csv"

        $message = ("{0}: Filtering for devices in group {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GroupName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $devices = ($allLmDevices).Where( { ($_.systemProperties.name -eq 'system.groups') -and ($_.systemProperties.value -match $GroupName) })

        Remove-Variable allLmDevices -Force

        $message = ("{0}: Found {1} devices in group {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $devices.Count, $GroupName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    { $_ -in ("IdFilter", "StringFilter") } {
        If (-NOT($GroupId)) { $fileName = "thresholdReport-$(([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")).csv" } Else { $fileName = "thresholdReport-$GroupId.csv" }

        $devices = $allLmDevices
        Remove-Variable allLmDevices -Force
    }
    "AllDevices" {
        $fileName = "thresholdReport-AllDevices.csv"

        $message = ("{0}: No device filter applied. There are {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $allLmDevices.Count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $devices = $allLmDevices

        Remove-Variable allLmDevices -Force
    }
}

Foreach ($device in $devices) {
    $progressCounter++

    $message = ("{0}: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Working on {1}. This is device {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName, $progressCounter, $devices.count)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

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
        "X-Version"     = 2
    }

    $instances = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

    If ($instances.total -lt 1) {
        $message = ("{0}: No instances found under {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.displayName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

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
            "X-Version"     = 2
        }

        $message = ("{0}: Getting DataSources." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

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
            "X-Version"     = 2
        }

        $message = ("{0}: Getting datapoints." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        If ($datapoints.Total -lt 1) {
            $message = ("{0}: No datapoints retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Continue
        }
        Else {
            $message = ("{0}: Adding datapoints to the report list." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
        }

        Foreach ($datapoint in $datapoints.items) {
            $reportList.Add(
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
        $reportList | Export-Csv -Path "$($OutputPath.FullName.TrimEnd('\'))\$fileName" -ErrorAction Stop -NoTypeInformation
    } Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OutputPath, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$($OutputPath.FullName.TrimEnd('\'))\$fileName")
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Exit 0
} Else {
    $reportList
}

Exit 0