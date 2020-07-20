<#
    .DESCRIPTION
        Accept a pair (or more) of interfaces to report their status as a group.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 9 July 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-InterfacePairStatus
    .PARAMETER LogFile
        Path and file name, to which the command will send output logs.
#>
[CmdletBinding()]
param(
)
Function Get-InterfacePairStatus {
    <#
        .DESCRIPTION
            Retrieves status data via the LogicMonitor REST API, for a pair of Ethernet ports.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 9 July 2020
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-InterfacePairStatus
        .PARAMETER AccessId
            LogicMonitor REST API access Id.
        .PARAMETER AccessKey
            LogicMonitor REST API access key.
        .PARAMETER AccountName
            LogicMonitor portal account name.
        .PARAMETER DeviceId
            LogicMonitor device Id.
        .PARAMETER PortPair
            A string or array of Ethernet names (e.g. Ethernet105/1/1).
        .PARAMETER LogFile
            Path and file name, to which the command will send output logs.
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
        [int64]$DeviceId,

        [string]$DataSourceName = 'snmp64_If-',

        [Parameter(Mandatory)]
        $PortPair,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    # Initialize variables.
    $appliedDataSourceInstances = [System.Collections.Generic.List[PSObject]]::New() # Primary collection to be filled with Invoke-RestMethod response.
    $offset = 0 # Define how many agents from zero, to start the query. Initial is zero, then it gets incremented later.
    $batchSize = 1000 # How many monitored instances to retrieve in each query.
    $firstLoopDone = $false # Will change to true, once the function determines how many times it needs to loop, to retrieve all devices.
    $httpVerb = "GET" # Define what HTTP operation will the script run.
    $resourcePath = "/device/devices/$DeviceId/instances" # Define the resourcePath, based on the type of device you're searching for.
    [boolean]$stopLoop = $false # Ensures we run Invoke-RestMethod at least once.
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

    If ($PortPair -match ',') {
        $PortPair = ($PortPair -replace "'", "").Split(',').Trim()
    }

    $message = ("{0}: Ports: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($PortPair -join ', '))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $message = ("{0}: Attempting to get the list of applied DataSources." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $stopLoop = $false
    Do {
        $queryParams = "?offset=$offset&size=$BatchSize&sort=id"

        # Construct the query URL.
        $url = "https://$AccountName.logicmonitor.com/santaba/rest$resourcePath$queryParams"

        If ($firstLoopDone -eq $false) {
            $message = ("{0}: Building request header." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            # Get current time in milliseconds
            $epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)

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
        }

        $stopLoop = $false
        Do {
            Try {
                $appliedDataSources = ([System.Collections.Generic.List[PSObject]]@(Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop).items)

                $stopLoop = $True
                $firstLoopDone = $True
            }
            Catch {
                If ($_.Exception.Message -match '429') {
                    $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    Write-Warning $message; $message | Out-File -FilePath $logFile -Append

                    Start-Sleep -Seconds 60
                }
                Else {
                    $message = ("{0}: Unexpected error getting applied DataSource instances. To prevent errors, {1} will exit. If present, the following details were returned:`r`n
                        Error message: {2}`r
                        Error code: {3}`r
                        Invoke-Request: {4}`r
                        Headers: {5}`r
                        Body: {6}" -f
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorMessage),
                        ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorCode), $_.Exception.Message, ($headers | Out-String), ($data | Out-String)
                    )
                    Write-Error $message; $message | Out-File -FilePath $logFile -Append

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        If ($firstLoopDone -and ($null -ne $appliedDataSources)) {
            $appliedDataSourceInstances.AddRange($appliedDataSources)

            $message = ("{0}: There are {1} instances in `$appliedDataSourceInstances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $appliedDataSourceInstances.count)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            # Increment offset, to grab the next batch of datasource instances.
            $message = ("{0}: Incrementing the search offset by {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $BatchSize)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            $offset += $BatchSize
        }
    }
    Until ($null -eq $appliedDataSources)

    If (-NOT($appliedDataSourceInstances.name) -or $appliedDataSourceInstances -eq "Error") {
        Return "Error"
    }

    $message = ("{0}: Filtering for monitored instances of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DataSourceName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $pairStatus = Foreach ($port in $PortPair) {
        $message = ("{0}: Searching for a monitored instance with the display name: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $port.Replace("'", "").Replace('"', '').Trim())
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        # Using 'replace' and 'trim' on the $port variable to make sure we have a clean string.
        $filteredInstances = $appliedDataSourceInstances | Where-Object { ($_.name -match $DataSourceName) -and ($_.stopMonitoring -eq $false) -and ($_.displayName -eq $port.Replace("'", "").Replace('"', '').Trim()) }

        If (-NOT($filteredInstances.displayName)) {
            $message = ("{0}: No monitoring instance found for a monitored port matching: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $port.Replace("'", "").Replace('"', '').Trim())
            Write-Warning $message; $message | Out-File -FilePath $logFile -Append
        }

        $filteredInstances | ForEach-Object {
            $instance = $_

            $message = ("{0}: Attempting to get value data for the {1} instance." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $instance.displayName)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            # This is where we start getting datapoint values.
            $resourcePath = "/device/devices/$DeviceId/devicedatasources/$($instance.deviceDataSourceId)/instances/$($instance.id)/data"
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

            Try {
                [array]$datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop
            }
            Catch {
                $message = ("{0}: Unexpected error getting datapoints. To prevent errors, {1} will exit. If present, the following details were returned:`r`n
                Error message: {2}`r
                Error code: {3}`r
                Invoke-Request: {4}`r
                Headers: {5}`r
                Body: {6}" -f
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorMessage),
                    ($_ | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errorCode), $_.Exception.Message, ($headers | Out-String), ($data | Out-String)
                )
                Write-Error $message; $message | Out-File -FilePath $logFile -Append

                Return "Error"
            }

            $index = [array]::indexOf($datapoints.datapoints, 'Status')

            [pscustomobject]@{
                Status = $datapoints[0].values[0][$index]
                Port   = $instance.displayName
            }
        }
    }

    $pairStatus
} #1.0.0.0

#region Setup
# Initialize variables.
# Need the computer for the log file name, so this has to be above the rest of the initialization and does not log.
$computer = '##system.hostname##'
$instanceName = "##alias##"

# Gotta define the log file after populating $DeviceId, because we use that variable's value in the file name.
If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-GetInterfacePairStatus-collection-$computer-$instanceName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

# More variable initialization.
[string]$accountName = '##lmaccount##'
[string]$accessId = '##lmaccess.id##'
[securestring]$accessKey = '##lmaccess.key##' | ConvertTo-SecureString -AsPlainText -Force
[string]$portPair = "##wildvalue##"
[int]$deviceId = '##system.deviceId##'

Switch ('accountName', 'accessId', 'accessKey', 'portPair', 'deviceId') {
    { [string]::IsNullOrEmpty((Get-Variable -Value $_)) } {
        $message = ("{0}: One or more of the required properties were not found in LogicMonitor. In this case, at least {1} is null." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ('ScriptError=1')

        Exit 1
    }
}
#endregion Setup

#region Main
$status = Get-InterfacePairStatus -AccessId $accessId -AccessKey $accessKey -AccountName $accountName -DeviceId $deviceId -PortPair $portPair.Split(',') -DataSourceName 'snmp64_If_no_status_alert' -LogFile $logFile

If ($status -match 'Error') {
    $message = ("{0}: Get-InterfacePairStatus returned an error. Exiting in an error state." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ('ScriptError=1')

    Exit 1
}
ElseIf ($status.Port.Count -ne $portPair.Split(',').Count) {
    $message = ("{0}: Found too little data. Review the log file for details." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ('InterfaceCountError=1')

    Exit 0
}
Else {
    $alertValue = 0
    $status | ForEach-Object {
        If ($_.Status -ne 1.0) {
            $alertValue++
        }
    }

    Write-Host ('ScriptError=0')
    Write-Host ('InterfaceCountError=0')
    Write-Host ('AggregateStatus={0}' -f $alertValue)

    Exit 0
}
#endregion Main