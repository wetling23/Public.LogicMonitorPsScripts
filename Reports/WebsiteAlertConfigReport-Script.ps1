<#
    .DESCRIPTION
        Alerting configuration report for LogicMonitor websites (ping and webcheck).
    .NOTES
        Author: Mike Hashemi
        V2023.08.01.0
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/Reports/WebsiteAlertConfigReport-Script.ps1
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
    .PARAMETER GroupNameFilter
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
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -GroupName 'Acme Sites' -Recursive -OutputPath C:\Temp

        In this example, the script gets all websites in the group called 'Acme Sites', plus sites in groups directly under 'Acme Sites'. Alert-configuration data is written to C:\Temp\websiteAlertConfigReport-Group-Acme Sites.csv. Limited logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -GroupId 1399 -Recursive

        In this example, the script gets all websites in the group with ID 1399, plus sites in groups directly under 1399. Alert-configuration data is written to the console host. Limited logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -GroupFilter 'filter=name:"Acme Sites"'

        In this example, the script gets all websites in the "Acme Sites" group (directly). Alert-configuration data is written to the console host. Limited logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -WebsiteName 'Homepage'

        In this example, the script gets all websites with name "Homepage". Alert-configuration data is written to the console host. Limited logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -WebsiteId 3314 -OutputPath C:\Temp

        In this example, the script gets the website with ID 3314. Alert-configuration data is written to C:\Temp\websiteAlertConfigReport-Site-3314.csv. Limited logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name> -WebsiteFilter 'filter=host:"144.129.47.138"' -OutputPath C:\Temp -Verbose

        In this example, the script gets all websites where the host is equal to "144.129.47.138". Alert-configuration data is written to C:\Temp\websiteAlertConfigReport-Site-Filter-host.csv. Verbose logging is written only to the console host.
    .EXAMPLE
        PS C:\> .\WebsiteAlertConfigReport-Script.ps1 -AccessId <access ID> -AccessKey <access key> -AccountName <account name>

        In this example, the script gets all websites in the group called 'Acme Sites', plus sites in groups directly under 'Acme Sites'. Alert-configuration data is written to C:\Temp\websiteAlertConfigReport-Group-Acme Sites.csv. Limited logging is written only to the console host.
#>
[CmdletBinding(DefaultParameterSetName = 'AllSites')]
Param (
    [Parameter(Mandatory)]
    [String]$AccessId,

    [Parameter(Mandatory)]
    [SecureString]$AccessKey,

    [Parameter(Mandatory)]
    [String]$AccountName,

    [Parameter(Mandatory, ParameterSetName = 'GroupNameFilter')]
    [String]$GroupName,

    [Parameter(Mandatory, ParameterSetName = 'GroupIdFilter')]
    [Int]$GroupId,

    [Parameter(Mandatory, ParameterSetName = 'GroupStringFilter')]
    [String]$GroupFilter,

    [Parameter(Mandatory, ParameterSetName = 'SiteNameFilter')]
    [String]$WebsiteName,

    [Parameter(Mandatory, ParameterSetName = 'SiteIdFilter')]
    [Int]$WebsiteId,

    [Parameter(Mandatory, ParameterSetName = 'SiteStringFilter')]
    [String]$WebsiteFilter,

    [Parameter(ParameterSetName = 'GroupNameFilter')]
    [parameter(ParameterSetName = 'GroupIdFilter')]
    [parameter(ParameterSetName = 'GroupStringFilter')]
    [Switch]$Recursive,

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
$monitoringProps = [System.Collections.Generic.List[PSObject]]::new()
$siteList = [System.Collections.Generic.List[PSObject]]::new()
$lmParams = @{
    AccessId    = $AccessId
    AccessKey   = $AccessKey
    AccountName = $AccountName
}
#endregion Initialized variables

#region Logging
# Setup parameters for splatting.
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
#endregion Logging

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Out-PsLogging @loggingParams -MessageType First -Message $message

#region Import PowerShell modules
Try {
    Import-Module -Name LogicMonitor -ErrorAction Stop
} Catch {
    $message = ("{0}: Error importing the LogicMonitor module. To prevent errors, {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
    Out-PsLogging @loggingParams -MessageType Error -Message $message

    Exit 1
}
#endregion Import PowerShell modules
#endregion Setup

#region Get groups
Switch ($PsCmdlet.ParameterSetName) {
    'GroupNameFilter' {
        $groups = Get-LogicMonitorWebsiteGroup @lmParams -Name $GroupName @loggingParams
    }
    'GroupIdFilter' {
        $groups = Get-LogicMonitorWebsiteGroup @lmParams -Id $GroupId @loggingParams
    }
    'GroupStringFilter' {
        $groups = Get-LogicMonitorWebsiteGroup @lmParams -Filter $GroupFilter @loggingParams
    }
}

If ($groups.id.Count -gt 0) {
    $message = ("{0}: Found {1} groups." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $groups.id.Count)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
}
#endregion Get groups

#region Get site list from groups
If ($PsCmdlet.ParameterSetName -in @('GroupNameFilter', 'GroupIdFilter', 'GroupStringFilter')) {
    If ($Recursive) {
        $groupCount = $groups.subGroups.id.Count + $groups.id.Count
        $groupIds = ($groups, $groups.subGroups).id -join '|'
    } Else {
        $groupCount = $groups.id.Count
        $groupIds = $groups.id -join '|'
    }

    $message = ("{0}: Getting websites from {1} groups." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $groupCount)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $response = Get-LogicMonitorWebsite @lmParams -Filter "filter=groupId:$groupIds" @loggingParams

    If ($response.id.Count -gt 0) {
        $message = ("{0}: Found {1} websites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.id.Count)
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Foreach ($site in $response) {
            $siteList.Add($site)
        }
    }
}
#endregion Get site list from groups

#region Get direct site data
Switch ($PsCmdlet.ParameterSetName) {
    'SiteNameFilter' {
        $response = Get-LogicMonitorWebsite @lmParams -Name $WebsiteName @loggingParams
    }
    'SiteIdFilter' {
        $response = Get-LogicMonitorWebsite @lmParams -Id $WebsiteId @loggingParams
    }
    'SiteStringFilter' {
        $response = Get-LogicMonitorWebsite @lmParams -Filter $WebsiteFilter @loggingParams
    }
    'AllSites' {
        $response = Get-LogicMonitorWebsite @lmParams @loggingParams
    }
}

If ($response.id.Count -gt 0) {
    $message = ("{0}: Found {1} websites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.id.Count)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Foreach ($site in $response) {
        $siteList.Add($site)
    }
}
#endregion Get direct site data

#region Output
If ($siteList.id.Count -lt 1) {
    $message = ("{0}: No sites were returned, {1} cannot continue." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Out-PsLogging @loggingParams -MessageType Error -Message $message

    Exit 1
}

Foreach ($site in $siteList) {
    $monitoringProps.Add($(
            [PSCustomObject]@{
                Name                      = $site.name
                Type                      = $site.Type
                Host                      = $(If ($site.host) { $site.host } ElseIf ($site.domain) { $site.domain } Else { $null })
                PollingIntervalMinutes    = $site.pollingInterval
                SiteLoadMs                = $(If ($site.pageLoadAlertTimeInMS) { $site.pageLoadAlertTimeInMS } Else { $null })
                PacketsNotReceivedPercent = $(If ($site.percentPktsNotReceiveInTime) { $site.percentPktsNotReceiveInTime } Else { $null })
                PacketsNotReceivedTimeOut = $(If ($site.timeoutInMSPktsNotReceive) { $site.timeoutInMSPktsNotReceive } Else { $null })
                FailedChecksBeforeAlert   = $site.transition
                SendPackets               = $(If ($site.count) { $site.count } Else { $null })
                IndividualLocationAlert   = $site.individualSmAlertEnable
                IndividualAlertLevel      = $site.individualAlertLevel
                OverallAlertLevel         = $site.overallAlertLevel
                DefaultLocationSettings   = $site.useDefaultLocationSetting
                DefaultWebsiteSettings    = $site.useDefaultAlertSetting
                AlertOnSslError           = $(If ($site.triggerSSLStatusAlert) { $site.triggerSSLStatusAlert } Else { $null })
                AlertOnCertExpiration     = $(If ($site.triggerSSLExpirationAlert) { $site.triggerSSLExpirationAlert } Else { $null })
            }
        ))
}

If ($OutputPath) {
    Switch ($PsCmdlet.ParameterSetName) {
        'GroupNameFilter' {
            $fileName = "websiteAlertConfigReport-Group-$GroupName.csv"
        }
        'GroupIdFilter' {
            $fileName = "websiteAlertConfigReport-Group-$GroupId.csv"
        }
        "GroupStringFilter" {
            $fileName = "websiteAlertConfigReport-Group-Filter-$(($GroupFilter -split '\W')[1]).csv"
        }
        'SiteNameFilter' {
            $fileName = "websiteAlertConfigReport-Site-$WebsiteName.csv"
        }
        'SiteIdFilter' {
            $fileName = "websiteAlertConfigReport-Site-$WebsiteId.csv"
        }
        "SiteStringFilter" {
            $fileName = "websiteAlertConfigReport-Site-Filter-$(($WebsiteFilter -split '\W')[1]).csv"
        }
    }

    Try {
        $monitoringProps | Export-Csv -Path "$($OutputPath.FullName.TrimEnd('\'))\$fileName" -ErrorAction Stop -NoTypeInformation
    } Catch {
        $message = ("{0}: Unexpected error sending output to {1}. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OutputPath, $_.Exception.Message)
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Exit 1
    }

    $message = ("{0}: Sent output to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$($OutputPath.FullName.TrimEnd('\'))\$fileName")
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Exit 0
} Else {
    $monitoringProps

    Exit 0
}
#endregion Output