<#
    .DESCRIPTION
        Run manually to retrieve a JSON-formatted list of Active Directory properties. Can be run either from a domain controller (no creds required) or from remote server (cred required), targeted at a domain controller.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 19 March 2019
            - Initial release.
        V1.0.0.1 date: 21 March 2019
            - Renamed file because of LogicMonitor's intermittent timeout while collecting. The script can still be run manually, but the new name better represents what is happening.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/ActiveDirectory/GetAdProperties
    .PARAMETER OnDomainController
        Include if the script is being run on a domain controller. If not specified, the script will check for the ADWS and NTDS services, to determine if it is running on a DC.
    .PARAMETER DcFqdn
        Fully qualified domain name for a target domain controller. If not specified, the script will take the hostname (if $OnDomainController == $true) or will prompt the user for a server name.
    .PARAMETER Credential
        Domain admin credential. If the script is run manually and not on a domain controller, the user is prompted to provide a username and password.
    .EXAMPLE
        PS C:\Get_AdProperties.ps1 -DcFqdn server.domain.local -Credential (Get-Credential) -Verbose

        In this example, the script is run manually and a credential is provided by the user. Output is sent to the host session and to the log file.
    .EXAMPLE
        PS C:\Get_AdProperties.ps1

        In this example, the script is run manually. The user will be prompted to provide a hostname (if the script is not run from a DC) and a credential is provided by the user. Output is sent only to the log file.
#>
[CmdletBinding()]
param (
    [string]$DcFqdn,
    [System.Management.Automation.PSCredential]$Credential
)

$message = ("{0}: Checking if the script is running on a domain controller.." -f (Get-Date -Format s))
If ($PSBoundParameters['Verbose']) {Write-Verbose $message}

$OnDomainController = If (Get-WmiObject -Class win32_service -Filter "Name='ADWS' OR Name='NTDS'") {$true} Else {$False} # Used by the script, to determine if we need to find a DC.

#region In-line functions
Function Get-GpoReportData {
    [CmdletBinding()]
    param (
        [string]$Hostname,
        [array]$GpoList,
        [string]$LogFile
    )
    #region GPO settings
    [string]$GPO_Type_ExplicitSettings = "ExplicitSettings" # GPO Setting Types. Tells the script how the settings are stored/returned so they can be parsed correctly.
    [string]$GPO_Type_FreeformRegistry = "FreeformRegistry" # GPO Setting Types. Tells the script how the settings are stored/returned so they can be parsed correctly.
    [string]$GPO_Type_Mappings = "Mappings" # GPO Setting Types. Tells the script how the settings are stored/returned so they can be parsed correctly.
    [string]$GPO_Type_Script = "Script" # GPO Setting Types. Tells the script how the settings are stored/returned so they can be parsed correctly.
    [string]$ComputerConfigPath = "Computer" # Important GPO settings.
    [string]$UserConfigPath = "User" # Important GPO settings.
    [string]$SecuritySetting = "Security" # Important GPO settings.
    [string]$RegistrySetting = "Registry" # Important GPO settings.

    $Setting_PasswordHistorySize = [ordered]@{SettingName = "PasswordHistorySize"; DisplayName = "Enforce password history"; SettingType = "Number"}
    $Setting_MaximumPasswordAge = [ordered]@{SettingName = "MaximumPasswordAge"; DisplayName = "Maximum password age"; SettingType = "Number"}
    $Setting_MinimumPasswordAge = [ordered]@{SettingName = "MinimumPasswordAge"; DisplayName = "Minimum password age"; SettingType = "Number"}
    $Setting_MinimumPasswordLength = [ordered]@{SettingName = "MinimumPasswordLength"; DisplayName = "Minimum password length"; SettingType = "Number"}
    $Setting_PasswordComplexity = [ordered]@{SettingName = "PasswordComplexity"; DisplayName = "Password must meet complexity requirements"; SettingType = "Boolean"}
    $SettingsListPasswords = @(
        [ordered]@{SettingName = "PasswordHistorySize"; DisplayName = "Enforce password history"; SettingType = "Number"}
        [ordered]@{SettingName = "MaximumPasswordAge"; DisplayName = "Maximum password age"; SettingType = "Number"}
        [ordered]@{SettingName = "MinimumPasswordAge"; DisplayName = "Minimum password age"; SettingType = "Number"}
        [ordered]@{SettingName = "MinimumPasswordLength"; DisplayName = "Minimum password length"; SettingType = "Number"}
        [ordered]@{SettingName = "PasswordComplexity"; DisplayName = "Password must meet complexity requirements"; SettingType = "Boolean"}
    )
    $GPO_PasswordPolicy = [ordered]@{
        Name             = "Password Policy"
        Type             = $GPO_Type_ExplicitSettings
        ConfigPath       = $ComputerConfigPath
        SettingsTypePath = $SecuritySetting
        SettingsGroup    = "Account"
        SettingsList     = $SettingsListPasswords
    }

    $Setting_LockoutBadCount = [ordered]@{SettingName = "LockoutBadCount"; DisplayName = "Account lockout threshold"; SettingType = "Number"}

    $Setting_LockoutDuration = [ordered]@{SettingName = "LockoutDuration"; DisplayName = "Account lockout duration"; SettingType = "Number"}

    $Setting_ResetLockoutCount = [ordered]@{SettingName = "ResetLockoutCount"; DisplayName = "Reset account lockout counter after"; SettingType = "Number"}

    $SettingsListLockoutPolicy = @($Setting_LockoutDuration, $Setting_LockoutBadCount, $Setting_ResetLockoutCount)

    $GPO_AccountLockoutPolicy = [ordered]@{
        Name             = "Account Lockout Policy"
        Type             = $GPO_Type_ExplicitSettings
        ConfigPath       = $ComputerConfigPath
        SettingsTypePath = $SecuritySetting
        SettingsGroup    = "Account"
        SettingsList     = $SettingsListLockoutPolicy
    }
    $Setting_GpoRefreshFrequency = [ordered]@{
        SettingName  = "GpoRefreshFrequency"
        DisplayName  = "This setting allows you to customize how often Group Policy is applied to computers."
        SettingPath  = "Numeric"
        SettingIndex = 0
    }
    $Setting_GpoRefreshStagger = [ordered]@{
        SettingName  = "GpoRefreshStagger"
        DisplayName  = "This is a random time added to the refresh interval to prevent all clients from requesting Group Policy at the same time."
        SettingPath  = "Numeric"
        SettingIndex = 1
    }
    $SettingsListGpoRefreshPolicy = @($Setting_GpoRefreshFrequency, $Setting_GpoRefreshStagger)
    $GPO_GpoRefreshPolicy = [ordered]@{
        Name             = "Set Group Policy refresh interval for computers"
        Type             = $GPO_Type_FreeformRegistry
        ConfigPath       = $ComputerConfigPath
        SettingsTypePath = $RegistrySetting
        SettingsGroup    = "Policy"
        SettingsList     = $SettingsListGpoRefreshPolicy
    }

    # Mapped Printers.
    $GPO_MappedPrinters = [ordered]@{
        Name             = "Printer Mapping"
        Type             = $GPO_Type_Mappings
        ConfigPath       = $UserConfigPath
        SettingsTypePath = "Printers"
        SettingsGroup    = "Printers"
        SettingsSubGroup = "SharedPrinter"
        SettingsList     = @() # Because this is a mapping, the settings list will just be a list of the mapped printers.
    }

    # Mapped Drives.
    $GPO_MappedDrives = [ordered]@{
        Name             = "Drive Mapping"
        Type             = $GPO_Type_Mappings
        ConfigPath       = $UserConfigPath
        SettingsTypePath = "Drive Maps"
        SettingsGroup    = "DriveMapSettings"
        SettingsSubGroup = "Drive"
        SettingsList     = @() # Because this is a mapping, the settings list will just be a list of the mapped drives.
    }

    # Scripts (it may be nice to add a user/computer piece here, but we'll see).
    $GPO_UserScripts = [ordered]@{
        Name             = "User Scripts"
        Type             = $GPO_Type_Script
        ConfigPath       = $UserConfigPath
        SettingsTypePath = "Scripts"
        SettingsGroup    = "Script"
        SettingsList     = @() # Because this is a mapping, the settings list will just be a list of the mapped printers.
    }

    $GPO_ComputerScripts = [ordered]@{
        Name             = "Computer Scripts"
        Type             = $GPO_Type_Script
        ConfigPath       = $ComputerConfigPath
        SettingsTypePath = "Scripts"
        SettingsGroup    = "Script"
        SettingsList     = @() # Because this is a mapping, the settings list will just be a list of the mapped printers.
    }

    $ImportantGPOList = @($GPO_PasswordPolicy, $GPO_AccountLockoutPolicy, $GPO_GpoRefreshPolicy, $GPO_MappedPrinters, $GPO_MappedDrives, $GPO_UserScripts, $GPO_ComputerScripts)
    #endregion GPO settings

    # Begin GPO information grabbing
    $shortReport = @()
    Foreach ($gpo in $gpoList) {
        [xml]$fullReport = Get-GPOReport -Server $hostname -GUID $gpo.Id -ReportType XML
        $shortReportContent = $fullReport | Select-Object -ExpandProperty GPO | Select-Object Name, @{Name = "GUID"; Expression = {$gpo.Id}}, @{Name = "Linked To"; Expression = {$_.LinksTo | Select-Object @{Name = "OU Name"; Expression = {$_.SOMName}}, `
                @{Name = "OU Path"; Expression = {$_.SOMPath}}, Enabled, @{Name = "Enforced"; Expression = {$_.NoOverride}}}
        }, @{Name = "Computer Settings"; Expression = {$_.Computer | Select-Object Enabled, @{Name = "Settings"; Expression = {@()}}}}, `
        @{Name = "User Settings"; Expression = {$_.User | Select-Object Enabled, @{Name = "Settings"; Expression = {@()}}}}

        Foreach ($importantGpo in $importantGpoList) {
            $reportValues = @()
            $output = @()

            Switch ($importantGpo.Type ) {
                $GPO_Type_FreeformRegistry {
                    $reportValues = ($fullReport.GPO.($importantGpo.ConfigPath).ExtensionData | Where-Object {$_.Name -eq $importantGpo.SettingsTypePath }).Extension.($importantGpo.SettingsGroup) | Where-Object {$_.Name -eq $importantGpo.Name}

                    If ($reportValues) {
                        $message = ("{0}: Found {1} GPO settings, adding to list." -f (Get-Date -Format s), $importantGpo.Name)
                        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

                        Foreach ($setting in $importantGpo.SettingsList) {
                            if ($reportValues.($setting.SettingPath)[$setting.SettingIndex].State -eq "Enabled") {
                                [string]$settingValue = "$($reportValues.($setting.SettingPath)[$setting.SettingIndex].Name) $($reportValues.($setting.SettingPath)[$setting.SettingIndex].Value)"
                            }
                            Else {
                                [string]$settingValue = $reportValues.($setting.SettingPath)[$setting.SettingIndex].State
                            }

                            $gpoSettings = @{
                                Name        = $setting.SettingName
                                DisplayName = $setting.DisplayName
                                Value       = $settingValue
                                DefinedIn   = $gpo.DisplayName
                            }
                            $output += $gpoSettings
                        }
                    }
                }
                $GPO_Type_ExplicitSettings {
                    If ($importantGpo.SettingsSubGroup) {
                        $reportValues = ($fullReport.GPO.($importantGpo.ConfigPath).ExtensionData | Where-Object {$_.Name -eq $importantGpo.SettingsTypePath}).Extension.($importantGpo.SettingsGroup).($importantGpo.SettingsSubGroup)
                    }
                    Else {
                        $reportValues = ($fullReport.GPO.($importantGpo.ConfigPath).ExtensionData | Where-Object {$_.Name -eq $importantGpo.SettingsTypePath}).Extension.($importantGpo.SettingsGroup)
                    }
                    If ($reportValues) {
                        $message = ("{0}: Found {1} GPO settings, adding to list." -f (Get-Date -Format s), $importantGpo.Name)
                        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

                        Foreach ($setting in $importantGpo.SettingsList) {
                            #The next line looks weird, but it basically digs waaaaay down to find and grab the setting and save it.
                            $settingValue = $reportValues | Where-Object {$_.Name -eq $setting.SettingName} | Select-Object ("Setting" + $setting.SettingType) -ExpandProperty ("Setting" + $setting.SettingType)

                            $gpoSettings = @{
                                Name        = $setting.SettingName
                                DisplayName = $setting.DisplayName
                                Value       = $settingValue
                                DefinedIn   = $gpo.DisplayName
                            }
                            $output += $gpoSettings
                        }
                    }
                }
                $GPO_Type_Mappings {
                    # Mappings (printers and drives) are handled differently, so this section is structured a bit differently.
                    $reportValues = @($fullReport.GPO.($importantGpo.ConfigPath).ExtensionData | Where-Object {$_.Name -eq $importantGpo.SettingsTypePath}).Extension.($importantGpo.SettingsGroup).($importantGpo.SettingsSubGroup) |
                        Select-Object @{Name = "Action"; Expression = { $_.Properties.Action }}, Name, @{Name = "Path"; Expression = { $_.Properties.Path }}, @{Name = "Filter Group"; Expression = { $_.Filters.FilterGroup | Select-Object @{Name = "not"; Expression = { [bool]$_.not.ToBoolean() }}, @{Name = "User or Group"; Expression = { $_.name }}}}

                    If ($reportValues) {
                        $message = ("Found {0} settings, adding to list." -f $importantGpo.Name)
                        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

                        Foreach ($setting in $reportValues) {
                            $gpoSettings = @{
                                Name        = $importantGpo.SettingName
                                DisplayName = $importantGpo.DisplayName
                                Value       = ($setting.Name + " - " + $setting.Path)
                                DefinedIn   = $gpo.DisplayName
                            }
                            $output += $gpoSettings
                        }
                    }
                }
                $GPO_Type_Script {
                    $reportValues = @($fullReport.GPO.($importantGpo.ConfigPath).ExtensionData | Where-Object {$_.Name -eq $importantGpo.SettingsTypePath}).Extension.($importantGpo.SettingsGroup) | Select-Object @{Name = "File"; Expression = { $_.Command }}, Type

                    Foreach ($setting in $reportValues) {
                        $gpoSettings = @{
                            Name        = "Script File"
                            DisplayName = $importantGpo.DisplayName
                            Value       = ($setting.Type + "-" + $setting.File)
                            DefinedIn   = $gpo.DisplayName
                        }
                        $output += $gpoSettings
                    }
                }
            }

            # If we found values in the settings we care about...
            If ($output) {
                $shortReportContent.(($importantGpo.ConfigPath) + " Settings").Settings += $output
            }
        }

        $shortReport += $shortReportContent
    }

    Return $shortReport
}
Function Get-AdSettings {
    [CmdletBinding()]
    param (
        [switch]$OnDomainController,
        [string]$SearchBase,
        [string]$LogFile
    )

    $message = ("{0}: Running Get-ADForest." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    If ($OnDomainController) {
        Try {
            $forest = Get-ADForest

            $message = ("{0}: Mapping ForestMode to `$forestMode." -f (Get-Date -Format s))
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $forestMode = Switch ($forest.ForestMode) {
                default {$_}
                0 {
                    "Windows2000Forest"
                }
                1 {
                    "Windows2003InterimForest"
                }
                2 {
                    "Windows2003Forest"
                }
                3 {
                    "Windows2008Forest"
                }4 {
                    "Windows2008R2Forest"
                }5 {
                    "Windows8Forest"
                }
                6 {
                    "Windows2012R2Forest"
                }
            }

            $message = ("{0}: The forest mode is {1}." -f (Get-Date -Format s), $forestMode)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
        Catch {
            $message = ("{0}: Running Get-ADForest failed: {1}, attempting to use the System.DirectoryServices.ActiveDirectory method." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
    }
    Else {
        Try {
            $forest = Get-ADForest @commandParams

            $message = ("{0}: Mapping ForestMode to `$forestMode." -f (Get-Date -Format s))
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $forestMode = Switch ($forest.ForestMode) {
                default {$_}
                0 {
                    "Windows2000Forest"
                }
                1 {
                    "Windows2003InterimForest"
                }
                2 {
                    "Windows2003Forest"
                }
                3 {
                    "Windows2008Forest"
                }4 {
                    "Windows2008R2Forest"
                }5 {
                    "Windows8Forest"
                }
                6 {
                    "Windows2012R2Forest"
                }
            }

            $message = ("{0}: The forest mode is {1}." -f (Get-Date -Format s), $forestMode)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
        Catch {
            $message = ("{0}: Running Get-ADForest failed: {1}, attempting to use the System.DirectoryServices.ActiveDirectory method." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
    }

    If (-NOT($forest)) {
        $message = ("{0}: No forest found. To prevent errors, the script will exit." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        $object = New-Object -TypeName PSObject -Property @{
            ForestName            = "Unknown"
            ForestFunctionalLevel = "Unknown"
            UPNSuffixes           = "Unknown"
            Sites                 = "Unknown"
            GC                    = "Unknown"
            DistinguishedName     = "Unknown"
            DomainFunctionalLevel = "Unknown"
            NetBIOSName           = "Unknown"
            PDCEmulator           = "Unknown"
            InfrastructureMaster  = "Unknown"
            RIDMaster             = "Unknown"
            SchemaMaster          = "Unknown"
            DomainNamingMaster    = "Unknown"
            AllDomainControllers  = "Unknown"
            SiteList              = "Unknown"
            SiteLinks             = "Unknown"
            Trusts                = "Unknown"
            OptionalFeatures      = "Unknown"
        }

        Return $object
    }

    $message = ("{0}: Running Get-ADDomain." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $domain = Get-ADDomain @commandParams

        $message = ("{0}: Mapping DomainMode to `$domainMode." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        $domainMode = Switch ($domain.DomainMode) {
            default {$_}
            0 {
                "Windows2000Mixed"
            }
            1 {
                "Windows2000Native"
            }
            2 {
                "Windows2003Interim"
            }
            3 {
                "Windows2003"
            }
            4 {
                "Windows2008"
            }
            5 {
                "Windows2008R2"
            }
            6 {
                "Windows8"
            }
            7 {
                "Windows2012R2"
            }
        }

        $message = ("{0}: The domain mode is {1}." -f (Get-Date -Format s), $domainMode)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }
    Catch {
        $message = ("{0}: Running Get-ADDomain failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }

    $message = ("{0}: Running Get-ADDomainController." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $domainControllers = Get-ADDomainController @commandParams -Filter * | Select-Object Name, HostName, IPv4Address, ComputerObjectDN, OperatingSystem, Site, IsGlobalCatalog, IsReadOnly, OperationMasterRoles
    }
    Catch {
        $message = ("{0}: Running Get-ADDomain failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }

    $message = ("{0}: Attempting to use Get-ADReplicationSubnet." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $sites = Get-ADReplicationSubnet -Filter * @commandParams

        If ($sites) {
            $message = ("{0}: Found sites, filtering properties." -f (Get-Date -Format s))
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $siteList = Foreach ($site in $sites) {
                $siteObj = New-Object -Type PSObject -Property (
                    @{
                        "SiteName" = (($site.Site).Replace('CN=', '')).Split(',')[0];
                        "Subnets"  = $site.Name;
                        "Servers"  = $domainControllers | Where-Object {$_.Site -eq (($site.Site).Replace('CN=', '')).Split(',')[0]};
                    }
                )
                $siteObj
            }
        }
        Else {
            $message = ("{0}: No sites found." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $siteList = 'RetrievalFailure'
        }
    }
    Catch {
        $message = ("{0}: Using Get-ADReplicationSubnet failed: {1}, attempting to use the System.DirectoryServices.ActiveDirectory method." -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        If ($OnDomainController) {
            $message = ("{0}: Running on a DC, attempting to create a directory context object." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $a = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $forest.Name)
            [array]$sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a).sites
            $siteList = Foreach ($site in $sites) {
                $siteObj = New-Object -Type PSObject -Property (
                    @{
                        "SiteName" = $site.Name;
                        "SubNets"  = $site.Subnets;
                        "Servers"  = $Site.Servers;
                    }
                )
                $siteObj
            }
        }
        Else {
            $message = ("{0}: Not running on a DC, attempting to create a directory context object through Invoke-Command." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            Try {
                $siteList = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {
                    $forestName = $args[0]
                    $a = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $forestName)
                    [array]$sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a).sites
                    Foreach ($site in $sites) {
                        $siteObj = New-Object -Type PSObject -Property (
                            @{
                                "SiteName" = $site.Name;
                                "SubNets"  = $site.Subnets;
                                "Servers"  = $Site.Servers;
                            }
                        )
                        $siteObj
                    }
                } -ArgumentList $forest.Name -ErrorAction Stop
            }
            Catch {
                $message = ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
                If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
            }
        }
    }

    $message = ("{0}: Running Get-ADObject to get site link properties." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $siteLinks = Get-ADObject @commandParams -Filter 'objectClass -eq "siteLink"' -SearchBase $searchBase -Property Name, Cost, ReplInterval, SiteList | Select-Object Name, SiteList, Cost, ReplInterval
    }
    Catch {
        $message = ("{0}: Running Get-ADObject failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }

    $message = ("{0}: Running Get-ADTrusts." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $trusts = Get-ADTrust @commandParams -Filter * | Select-Object Target, Direction, ForestTransitive, IntraForest, TrustAttributes, SelectiveAuthentication, Authentication, @{Name = "TrustType"; Expression = {[string]$_.TrustType}}

        $message = ("{0}: Assigning trust attributes." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        Foreach ($trust in $trusts) {
            Switch ($trust.TrustAttributes) {
                1 {$trust.TrustAttributes = "Non-Transitive"}
                2 {$trust.TrustAttributes = "Uplevel clients only (Windows 2000 or newer"}
                4 {$trust.TrustAttributes = "Quarantined Domain (External)"}
                8 {$trust.TrustAttributes = "Forest Trust"}
                16 {$trust.TrustAttributes = "Cross-Organizational Trust (Selective Authentication)"}
                32 {$trust.TrustAttributes = "Intra-Forest Trust (trust within the forest)"}
                64 {$trust.TrustAttributes = "Inter-Forest Trust (trust with another forest)"}
                Default {$trust.TrustAttributes = "Unknown value. Trust type: $PSItem"}
            }
            If ($trust.SelectiveAuthentication -eq $False) {$trust.Authentication = "Forest Wide"} Else {$trust.Authentication = "Selective Authentication"}
        }
    }
    Catch {
        $message = ("{0}: Running Get-ADTrusts failed: {1}. Attempting to use the System.DirectoryServices.ActiveDirectory method" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        If ($OnDomainController) {
            $message = ("{0}: Running on a DC, attempting to create a directory context object." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $a = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $forest.Name)
            [array]$b = ([System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a)).GetAllTrustRelationships()
            $trusts = Foreach ($trust in $b) {
                $siteObj = New-Object -Type PSObject -Property (
                    @{
                        "Target"                  = $b.TargetName;
                        "Direction"               = $b.TrustDirection;
                        "ForestTransitive"        = "Unknown";
                        "IntraForest"             = "Unknown";
                        "TrustAttributes"         = "Unknown";
                        "SelectiveAuthentication" = "Unknown";
                        "TrustType"               = "Unknown";
                    }
                )
                $siteObj
            }
        }
        Else {
            $message = ("{0}: Not running on a DC, attempting to create a directory context object through Invoke-Command." -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            Try {
                $trusts = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {
                    $forestName = $args[0]
                    $a = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $forestName)
                    [array]$trusts = ([System.DirectoryServices.ActiveDirectory.Forest]::GetForest($a)).GetAllTrustRelationships()
                    Foreach ($trust in $trusts) {
                        $siteObj = New-Object -Type PSObject -Property (
                            @{
                                "Target"                  = $trust.TargetName;
                                "Direction"               = $trust.TrustDirection;
                                "ForestTransitive"        = "Unknown";
                                "IntraForest"             = "Unknown";
                                "TrustAttributes"         = "Unknown";
                                "SelectiveAuthentication" = "Unknown";
                                "TrustType"               = "Unknown";
                            }
                        )
                        $siteObj
                    }
                } -ArgumentList $forest.Name
            }
            Catch {
                $message = ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
                If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
            }
        }
    }

    $message = ("{0}: Running Get-ADOptionalFeature." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $optionalFeatures = Get-ADOptionalFeature @commandParams -Filter * | Select-Object Name, RequiredForestMode, RequiredDomainMode, @{Name = "Status"; Expression = {($_.EnabledScopes.Count -gt 0)}}
    }
    Catch {
        $message = ("{0}: Running Get-ADOptionalFeature failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }

    $message = ("{0}: Assigning properties to `$object." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    $object = New-Object -TypeName PSObject -Property @{
        ForestName            = $forest.Name
        ForestFunctionalLevel = $forestMode
        UPNSuffixes           = $forest.UPNSuffixes
        Sites                 = $forest.Sites
        GC                    = $forest.GlobalCatalogs
        DistinguishedName     = $domain.DistinguishedName
        DomainFunctionalLevel = $domainMode
        NetBIOSName           = $domain.NetBIOSName
        PDCEmulator           = $domain.PDCEmulator
        InfrastructureMaster  = $domain.InfrastructureMaster
        RIDMaster             = $domain.RIDMaster
        SchemaMaster          = $forest.SchemaMaster
        DomainNamingMaster    = $forest.DomainNamingMaster
        AllDomainControllers  = @($domainControllers)
        SiteList              = @($siteList)
        SiteLinks             = @($siteLinks)
        Trusts                = @($trusts)
        OptionalFeatures      = @($optionalFeatures)
    }

    Return $object
}
Function Get-DcSettings {
    [CmdletBinding()]
    param (
        [array]$DomainControllers,
        [string]$LogFile
    )

    Foreach ($dc in $domainControllers) {
        $message = ("{0}: Running Get-ADComputer for {1}." -f (Get-Date -Format s), $dc.HostName)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        Try {
            $description = Get-ADComputer @commandParams -Identity $dc.ComputerObjectDN -Properties 'Description' | Select-Object -ExpandProperty Description -ErrorAction SilentlyContinue
        }
        Catch {
            $message = ("{0}: Running Get-ADComputer failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }

        $message = ("{0}: Adding description property to {1}." -f (Get-Date -Format s), $dc.HostName)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        If ($description) {
            $dc | Add-Member -MemberType NoteProperty -Name Description -Value $description -Force
        }
        Else {
            $dc | Add-Member -MemberType NoteProperty -Name Description -Value 'No description found in Active Directory.' -Force
        }

        $message = ("{0}: Running Resolve-DnsName for {1}." -f (Get-Date -Format s), $dc.HostName)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        Try {
            $ipV4Address = Resolve-DnsName -Name $dc.Hostname -Server $hostname | Select-Object @{Name = "IPv4Address"; Expression = {$_.IPAddress}} | Select-Object -ExpandProperty IPv4Address
        }
        Catch {
            $message = ("{0}: Running Resolve-DnsName failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }

        $message = ("{0}: Adding IpV4Address property to {1}." -f (Get-Date -Format s), $dc.HostName)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        If ($ipV4Address) {
            $dc | Add-Member -MemberType NoteProperty -Name IpV4Address -Value $ipV4Address -Force
        }
        Else {
            $dc | Add-Member -MemberType NoteProperty -Name IpV4Address -Value 'No IP address found.' -Force
        }
    }

    $script:backup | Add-Member -MemberType NoteProperty -Name RODC -Value @($domainControllers | Where-Object {$_.IsReadOnly -eq $true}) -Force
    $script:backup | Add-Member -MemberType NoteProperty -Name FullDomainControllers -Value @($domainControllers | Where-Object {$_.IsReadOnly -eq $false}) -Force
}
Function Get-DhcpSettings {
    [CmdletBinding()]
    param (
        [string]$SearchBase,
        [string]$LogFile
    )
    $message = ("{0}: Running Get-ADObject to get DHCP servers." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Try {
        $authorizedDHCPServers = Get-ADObject @commandParams -Filter 'objectClass -eq "dhcpclass" -AND name -ne "dhcproot"' -SearchBase $searchBase
    }
    Catch {
        $message = ("{0}: Running Get-ADObject failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }

    $script:backup | Add-Member -MemberType NoteProperty -Name DhcpServers -Value @($authorizedDHCPServers.Name) -Force
}
Function Get-GpoSettings {
    [CmdletBinding()]
    param (
        [switch]$OnDomainController,
        [string]$Server,
        [string]$LogFile
    )
    $message = ("{0}: Running Get-GPO to get list of GPOs." -f (Get-Date -Format s))
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    If ($OnDomainController) {
        Try {
            $gpoList = Get-GPO -Server $Server -All -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Running Get-GPO failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            Return
        }

        $message = ("{0}: Running Get-GpoReportData to get GPO properties." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        Try {
            $gpoCsv = Get-GpoReportData -Hostname $Server -GpoList $gpoList -LogFile $LogFile -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Running Get-GpoReportData failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            Return
        }
    }
    Else {
        Try {
            $gpoList = Invoke-Command -Credential $cred -ComputerName $Server -ScriptBlock {$Server = $args[0]; Get-GPO -Server $Server -All} -ArgumentList $Server -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }

        $message = ("{0}: Running Invoke-Command to get GPO properties." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        Try {
            $gpoCsv = Invoke-Command -Credential $cred -ComputerName $Server -ScriptBlock {Param ($FunctionCode, $Server, $gpoList, $LogFile); . Invoke-Expression $FunctionCode; Get-GpoReportData -Hostname $Server -GpoList $gpoList -LogFile $LogFile} -ArgumentList $code, $Server, $gpoList, $LogFile
        }
        Catch {
            $message = ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
    }

    $script:backup | Add-Member -MemberType NoteProperty -Name GPOs -Value @($gpoCsv) -Force
}
# This section puts the Get-GpoReportData function definition into $code, so I can send the function to the remote DC.
$code = @"
Function Get-GpoReportData {
$(Get-Command Get-GpoReportData | Select-Object -ExpandProperty Definition)
}
"@
#endregion In-line functions

Switch ($OnDomainController) {
    $true {
        # Initialize variables.
        $hostname = $env:COMPUTERNAME

        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
        $logFile = "$logDirPath\configsource-get_adproperties-collection-$hostname.log"

        $message = ("{0}: Beginning script to get Active Directory properties. This script is running on a domain controller." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile} Else {$message | Out-File -FilePath $logFile}

        $searchBase = (Get-ADRootDSE -Server $hostname).ConfigurationNamingContext

        $commandParams = @{
            Server      = $hostname;
            ErrorAction = 'Stop';
        }
    }
    $false {
        # Initialize variables.
        If ($DcFqdn) {$hostname = $DcFqdn} Else {$hostname = "##SYSTEM.HOSTNAME##"}
        If ($Credential) {$cred = $Credential} Else {$cred = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))}
        If ($hostname -match '##') {$hostname = Read-Host -Prompt 'Enter a domain controller hostname (or FQDN)'}
        If ($cred.UserName -match '##') {$cred = Get-Credential -Message 'Enter a credential with access to the domain controller.'}

        If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
            $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the collector will write the log file.
        }
        Else {
            $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
        }

        $logFile = "$logDirPath\configsource-get_adproperties-collection-$hostname.log"

        $message = ("{0}: Beginning script to get Active Directory properties. This script is not running on a domain controller." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile} Else {$message | Out-File -FilePath $logFile}

        $commandParams = @{
            Credential  = $cred;
            Server      = $hostname;
            ErrorAction = 'Stop';
        }

        $searchBase = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {$server = $args[0]; (Get-ADRootDSE -Server $server).ConfigurationNamingContext} -ArgumentList $hostname

        $message = ("{0}: Checking TrustedHosts file." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        # Add the target device to TrustedHosts.
        If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $hostname) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($hostname -ne "127.0.0.1")) {
            $message = ("{0}: Adding {1} to TrustedHosts." -f (Get-Date -Format s), $hostname)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            Try {
                Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $hostname -Concatenate -Force -ErrorAction Stop
            }
            Catch {
                $message = ("Unexpected error updating TrustedHosts: {0}" -f $_.Exception.Message)
                If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

                Exit 1
            }
        }

        $message = ("{0}: Checking for the adConfig file on {1}." -f (Get-Date -Format s), $hostname)
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

        $backup = Invoke-Command -ComputerName $hostname -Credential $cred -ScriptBlock {
            Try {Get-Content -Path C:\Windows\System32\adConfig.json -ErrorAction Stop; Exit 0} Catch {("Error: {0}" -f $_.Exception.Message); Exit 1}
        }

        If (($backup) -and ($backup -notmatch "Error:")) {
            $message = ("{0}: Retrieved Active Directory config content, returning it." -f (Get-Date -Format s), $hostname)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

            $backup

            Exit 0
        }
        ElseIf (($backup) -and ($backup -match "Error:")) {
            $message = ("{0}: {1} reported an error retrieving Active Directory config content: {1}." -f (Get-Date -Format s), $backup)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }
        ElseIf (-NOT($backup)) {
            $message = ("{0}: No content or error retrieved." -f (Get-Date -Format s), $hostname)
            If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
        }

        $message = ("{0}: Attempting to retrieve live Active Directory config." -f (Get-Date -Format s))
        If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}
    }
}

#region Running functions
$message = ("{0}: Calling the Get-AdSettings function." -f (Get-Date -Format s))
If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

If ($OnDomainController) {
    New-Variable -Name backup -Value (Get-AdSettings -SearchBase $searchBase -LogFile $logFile -OnDomainController) -Scope Script -Force
}
Else {
    New-Variable -Name backup -Value (Get-AdSettings -SearchBase $searchBase -LogFile $logFile) -Scope Script -Force
}

$message = ("{0}: Calling the Get-DcSettings function." -f (Get-Date -Format s))
If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

Get-DcSettings -LogFile $logFile -DomainControllers $backup.AllDomainControllers

$message = ("{0}: Calling the Get-DhcpSettings function." -f (Get-Date -Format s))
If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

Get-DhcpSettings -SearchBase $searchBase -LogFile $logFile

$message = ("{0}: Calling the Get-GpoSettings function." -f (Get-Date -Format s))
If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

If ($OnDomainController) {
    Get-GpoSettings -LogFile $logFile -Server $hostname -OnDomainController
}
Else {
    Get-GpoSettings -LogFile $logFile -Server $hostname
}
#endregion Running functions

If ($backup.ForestName) {
    $message = ("{0}: Sending the backup to {1}." -f (Get-Date -Format s), "$([System.Environment]::SystemDirectory)\adConfig.json")
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    $backup | ConvertTo-Json | Out-File -FilePath "$([System.Environment]::SystemDirectory)\adConfig.json" -Force
    $backup | ConvertTo-Json

    Exit 0
}
Else {
    $message = ("{0}: An improper (or no) backup, was collected." -f (Get-Date -Format s), "$([System.Environment]::SystemDirectory)\adConfig.json")
    If ($PSBoundParameters['Verbose']) {Write-Verbose $message; $message | Out-File -FilePath $logFile -Append} Else {$message | Out-File -FilePath $logFile -Append}

    Exit 1
}