<#
    .DESCRIPTION
        Uses the API to determine if a device's FlapStatus value is in a state of '1' too often.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 17 September 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-InterfaceFlapTrend
    .PARAMETER LogFile
        Path and file name, to which the command will send output logs.
    .EXAMPLE
        PS C:\> Get-InterfaceFlapTrend -ComputerName 127.0.0.1 -Filter "LocalAccount = "true" AND NOT disabled = "true" AND NOT Name = "guest"" -LogFile C:\temp\log.log

        In this example, the command queries the local host for local accounts that are enabled and are not named "guest". The logged output is stored in C:\temp\log.log
    .EXAMPLE
        PS C:\> Get-InterfaceFlapTrend -ComputerName server1 -Credential (Get-Credential) -LogFile C:\temp\.log.log

        In this example, the command queries server1, using the provided credential, for all accounts. The logged output is stored in C:\temp\log.log
#>
[CmdletBinding()]
param(
    [int64]$DeviceId,

    [string]$AccountName,

    [string]$AccessId,

    [securestring]$AccessKey
)
Function Get-InterfaceFlapTrend {
    <#
        .DESCRIPTION
            Retrieves FlapStatus data via the LogicMonitor REST API.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 17 September 2019
                - Initial release
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-InterfaceFlapTrend
        .PARAMETER AccessId
            LogicMonitor REST API access Id.
        .PARAMETER AccessKey
            LogicMonitor REST API access key.
        .PARAMETER AccountName
            LogicMonitor portal account name.
        .PARAMETER DeviceId
            LogicMonitor device Id.
        .PARAMETER LogFile
            Path and file name, to which the command will send output logs.
        .EXAMPLE
            PS C:\> Get-InterfaceFlapTrend -AccessId <access Id> -AccessKey <access key> -AccountName company -DeviceId 234 -LogFile C:\temp\log.log

            In this example, the command connects to the API and returns the last 30 StatusFlap datapoint values and associated time stamps for the snmp64_If- DataSource. The logged output is stored in C:\temp\log.log
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
        [string]$LogFile
    )

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $resourcePath = "/device/devices/$deviceId/instances"
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
        "Authorization" = "LMv1 $accessId`:$signature`:$epoch"
        "Content-Type"  = "application/json"
        "X-Version"     = 2
    }

    $message = ("Attempting to get the list of applied DataSources.")
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $appliedDataSources = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

    If (-NOT($appliedDataSources) -or $appliedDataSources -eq "Error") {
        Return "Error"
    }

    $message = ("Filtering for monitored instances of {0}." -f $DataSourceName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $instances = $appliedDataSources.items | Where-Object { ($_.name -match $DataSourceName) -and ($_.stopMonitoring -eq $false) }

    $instances | ForEach-Object {
        $instance = $_

        $message = ("Attempting to get value data for the {0} instance." -f $instance.displayName)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        # This is where we start getting datapoint values
        $resourcePath = "/device/devices/$deviceId/devicedatasources/$($instance.deviceDataSourceId)/instances/$($instance.id)/data"
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
            "Authorization" = "LMv1 $accessId`:$signature`:$epoch"
            "Content-Type"  = "application/json"
            "X-Version"     = 2
        }

        [array]$datapoints = Invoke-RestMethod -Uri $url -Method $httpVerb -Header $headers -ErrorAction Stop

        $index = [array]::indexOf($datapoints.datapoints, 'StatusFlap')

        $flapObject = for ($i = 0; $i -lt $datapoints.values.Count; $i++) {
            [pscustomobject]@{
                StatusFlap = $datapoints.values[$i][$index]
                Time       = $datapoints.time[$i]
            }
        }
    }

    $flapObject
}

# Initialize variables.
$DeviceId = '##system.deviceId##'
$httpVerb = 'GET'
$accountName = '##custom.apiAcctName##'
$accessId = '##api.user##'
$accessKey = '##api.key##' | ConvertTo-SecureString -AsPlainText -Force
$minTime = ((Get-Date).AddMinutes(-10)).ToUniversalTime()
$maxTime = (Get-Date).ToUniversalTime()
$origin = New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0
$flapCount = 0
If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get-InterfaceFlapTrend-collection-$DeviceId.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$flapData = Get-InterfaceFlapTrend -AccessId $accessId -AccessKey $accessKey -AccountName $accountName -DeviceId $DeviceId -LogFile $logFile

If ($flapData.StatusFlap.Count -lt 1) {
    $message = ("Found too little data. Exiting in an error state.")
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ('ScriptError=1')

    Exit 1
}
Else {
    $flapData | ForEach-Object {
        $dataPointTime = $origin.AddMilliSeconds($_.Time)
        If (($minTime.TimeOfDay -le $dataPointTime.TimeOfDay -and $maxTime.TimeOfDay -ge $dataPointTime.TimeOfDay) -and ($_.StatusFlap -gt 0)) {
            $flapCount++

            $message = ("Found a flap in the previous 10 minutes. The value of `$flapCount is now {0}." -f $flapCount)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
        }
        Else {
            $message = ("{0} (UTC) is either not in the last 10 minutes or not '1'." -f $dataPointTime)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
        }
    }

    Write-Host ('ScriptError=0')
    Write-Host ('FlapCountTrend={0}' -f $flapCount)

    Exit 0
}