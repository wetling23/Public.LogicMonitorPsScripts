<#
    .DESCRIPTION
        Generate a .csv file, with DataSource properties.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 23 September 2021
            - Initial release.
        V1.0.0.1 date: 12 October 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/Reports/DataSourcePropertyReport-Script.ps1
    .PARAMETER AccessId
        Mandatory parameter. Represents the access ID used to connected to LogicMonitor's REST API.
    .PARAMETER AccessKey
        Mandatory parameter. Represents the access key used to connected to LogicMonitor's REST API.
    .PARAMETER AccountName
        Mandatory parameter. Represents the subdomain of the LogicMonitor customer.
    .PARAMETER DisplayName
        Represents the display name of the desired LogicMonitor DataSource. When included, the script will filter the list of retrieved DataSources, to include only the named DS.
    .PARAMETER Id
        Represents the ID of the desired LogicMonitor resource group. When included, the script will filter the list of retrieved DataSources, to include only the IDed DS
    .PARAMETER Filter
        Represents a string matching the API's filter format. This parameter can be used to filter for DataSources matching certain criteria (e.g. "appliesTo" contains in "Azure").

        See https://www.logicmonitor.com/support/rest-api-developers-guide/v1/devices/get-devices#Example-Request-5--GET-all-devices-that-have-a-spe
    .PARAMETER OutputPath
        When provided, the script will output the report to this path.
    .PARAMETER EventLogSource
        When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
    .PARAMETER LogPath
        When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
    .EXAMPLE
        PS C:\> .\DataSource-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Verbose -EventLogSource LmReport

        In this example, the script gets all DataSources from LogicMonitor and generates a report for them. Verbose logging is written to the console host and Windows Application log with the "LmReport" event source. Report content is sent only to the host.
    .EXAMPLE
        PS C:\> .\DataSource-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Name WinCPU -Verbose -LogPath C:\Temp\log.txt

        In this example, the script gets the WinCPU DataSource and generates a report for it. Verbose logging is written to the console host and C:\Temp\log.txt. Report content is sent only to the host.
    .EXAMPLE
        PS C:\> .\DataSource-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -Id 12345 -OutputPath C:\Temp

        In this example, the script gets the DataSource with ID 12345 and generates a report for it. Limited logging is written to the console host only. Report content is written to C:\temp\dataSourceReport-<variable>.csv only.
    .EXAMPLE
        PS C:\> .\DataSource-Script.ps1 -AccessId <access Id> -AccessKey <access key> -AccountName <account name> -GroupFilter 'filter=name~`"Azure`"'

        In this example, the script gets all DataSources from LogicMonitor, with "Azure" in the name property, and generates a report for them. Limited logging is written to the console host only. Report content is sent only to the host.
#>
[CmdletBinding(DefaultParameterSetName = 'AllDataSources')]
Param (
    [Parameter(Mandatory)]
    [string]$AccessId,

    [Parameter(Mandatory)]
    [securestring]$AccessKey,

    [Parameter(Mandatory)]
    [string]$AccountName,

    [Parameter(Mandatory, ParameterSetName = 'NameFilter')]
    [string]$DisplayName,

    [Parameter(Mandatory, ParameterSetName = 'IdFilter')]
    [string]$Id,

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

#region Setup
$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType First -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType First -Message $message }

# Initialize variables.
$reportList = [System.Collections.Generic.List[PSObject]]::new()
$progressCounter = 0

If ($PSBoundParameters['Verbose']) {
    $loggingParams = @{
        Verbose = $true
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
            LogPath = $LogPath
            Verbose = $False
        }
    } Else {
        $loggingParams = @{
            Verbose = $False
        }
    }
}

$commandParams = @{
    AccessId    = $AccessId
    AccessKey   = $AccessKey
    AccountName = $AccountName
}

Switch ($PsCmdlet.ParameterSetName) {
    "NameFilter" {
        $fileName = "dataSourceReport-$DisplayName.csv"
        $filterParam = @{ DisplayName = $DisplayName }
    }
    "IdFilter" {
        $fileName = "dataSourceReport-$Id.csv"
        $filterParam = @{ Id = $Id }
    }
    "StringFilter" {
        $fileName = "dataSourceReport-$(($filter.Split('=') -split '~|:')[1])Filter.csv"
        $filterParam = @{ Filter = $Filter }
    }
    "AllDevices" {
        $fileName = "dataSourceReport-AllDataSources.csv"
    }
}
#endregion Setup

$message = ("{0}: Getting DataSource(s)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

If ($PsCmdlet.ParameterSetName -eq "AllDevices") {
    $dataSources = Get-LogicMonitorDataSource @commandParams
}

If (-NOT($dataSources.id)) {
    $dataSources = Get-LogicMonitorDataSource @filterParam @commandParams
}

If ($dataSources.id.Count -ge 1) {
    $message = ("{0}: Found {1} DataSources." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $dataSources.id.Count)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
}
Else {
    $message = ("{0}: No DataSources returned from LogicMonitor, {1} will exit. If applicable, DataSources were filtered for:`r`n`t{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $(If ($filterParam) { ($filterParam | Out-String) } Else { "All DataSources" }))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
}

Foreach ($ds in $dataSources) {
    $progressCounter++

    $message = ("{0}: ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Working on {1}. This is DataSource {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ds.name, $progressCounter, $dataSources.id.Count)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Foreach ($dp in $ds.datapoints) {
        $reportList.Add([PSCustomObject]@{
            dsId                           = $ds.id
            dsName                         = $ds.name
            dsDisplayName                  = $ds.displayName
            dsDescription                  = $ds.description
            dsAppliesTo                    = $ds.appliesTo
            dsTechnology                   = $ds.technology
            dsTags                         = $ds.tags
            dsHasMultiInstance             = $ds.hasMultiInstance
            dsCollectInterval              = $ds.collectInterval
            dsCollectMethod                = $ds.collectMethod
            dsCollectorAttribute           = $ds.collectorAttribute
            dsEnableAutoDiscovery          = $ds.enableAutoDiscovery
            dsAutoDiscoveryConfig          = $ds.autoDiscoveryConfig
            dpName                         = $dp.name
            dpDescription                  = $dp.description
            dpAlertTransitionInterval      = $dp.alertTransitionInterval
            dpAlertClearTransitionInterval = $dp.alertClearTransitionInterval
            dpThreshold                    = $dp.alertExpr
            dpAlertSubject                 = $dp.alertSubject
            dpAlertBody                    = $dp.alertBody
            dpType                         = $dp.type
            dpAlertForNoData               = $dp.alertForNoData
            dpDataType                     = $dp.dataType
            dpMaxDigits                    = $dp.maxDigits
            dpMaxValue                     = $dp.maxValue
            dpMinValue                     = $dp.minValue
            dpPostProcessorMethod          = $dp.postProcessorMethod
            dpPostProcessorParam           = $dp.postProcessorParam
            dpRawDataFieldName             = $dp.rawDataFieldName
            dpUserParam1                   = $dp.userParam1
            dpUserParam2                   = $dp.userParam2
            dpUserParam3                   = $dp.userParam3
        })
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