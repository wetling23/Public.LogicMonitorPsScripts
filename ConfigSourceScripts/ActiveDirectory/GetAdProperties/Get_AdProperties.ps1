$cred = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))
$hostname = "##SYSTEM.HOSTNAME##"
$searchBase = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {$server = $args[0]; (Get-ADRootDSE -Server $server).ConfigurationNamingContext} -ArgumentList $hostname
$log_base_dir_path = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # directory in which the collector will write the log file.
$log_module_type = "configsource"                    # datasource, configsource, propertysource, eventsource....
$log_module_name = "get_adproperties"                # typically the name of the logicmodule
$log_module_method = "collection"                    # typically "ad", "batch", or "collection"
$log_name = "$log_module_type-$log_module_name-$log_module_method$log_module_instance-$hostname"
$log_full_path = "$log_base_dir_path\$log_name.log"
$searchParams = @{
    Credential  = $cred;
    Server      = $hostname;
    ErrorAction = 'Stop';
}

Write-Output ("{0}: Beginning Get_AdProperties ConfigSource." -f (Get-Date -Format s), $hostname) | Out-File -FilePath $log_full_path

# Add the target device to TrustedHosts.
If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $hostname) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($hostname -ne "127.0.0.1")) {
    Write-Output ("{0}: Adding {1} to TrustedHosts." -f (Get-Date -Format s), $hostname) | Out-File -FilePath $log_full_path -Append

    Try {
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $hostname -Concatenate -Force -ErrorAction Stop
    }
    Catch {
        Write-Verbose ("Unexpected error updating TrustedHosts: {0}" -f $_.Exception.Message)

        Exit 0
    }
}
Function Get-GpoReportData {
    [CmdletBinding()]
    param (
        [string]$Hostname,
        [array]$GpoList
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
                        Write-Verbose ("Found {0} settings, adding to list." -f $importantGpo.Name)

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
                        Write-Verbose ("Found {0} settings, adding to list." -f $importantGpo.Name)

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
                        Select-Object @{Name = "Action"; Expression = { $_.Properties.Action }}, Name, @{Name = "Path"; Expression = { $_.Properties.Path }}, @{Name = "Filter Group"; Expression = { $_.Filters.FilterGroup | Select @{Name = "not"; Expression = { [bool]$_.not.ToBoolean() }}, @{Name = "User or Group"; Expression = { $_.name }}}}

                    If ($reportValues) {
                        Write-Verbose ("Found {0} settings, adding to list." -f $importantGpo.Name)

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
# This section puts the function definition into $code, so I can send the function to the remote DC.
$code = @"
Function Get-GpoReportData {
$(Get-Command Get-GpoReportData | Select-Object -ExpandProperty Definition)
}
"@

Write-Output ("{0}: Running Get-ADForest." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $forest = Get-ADForest @searchParams
}
Catch {
    Write-Output ("{0}: Running Get-ADForest failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Get-ADDomain." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $domain = Get-ADDomain @searchParams
}
Catch {
    Write-Output ("{0}: Running Get-ADDomain failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Get-ADDomainController." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $domainControllers = Get-ADDomainController @searchParams -Filter * | Select-Object Name, HostName, IPv4Address, ComputerObjectDN, OperatingSystem, Site, IsGlobalCatalog, IsReadOnly, OperationMasterRoles
}
Catch {
    Write-Output ("{0}: Running Get-ADDomain failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Foreach ($dc in $domainControllers) {
    Write-Output ("{0}: Running Get-ADComputer for {1}." -f (Get-Date -Format s), $dc.HostName) | Out-File -FilePath $log_full_path -Append
    Try {
        $description = Get-ADComputer @searchParams -Identity $dc.ComputerObjectDN -Properties 'Description' | Select-Object -ExpandProperty Description -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Output ("{0}: Running Get-ADComputer failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
    }

    Write-Output ("{0}: Adding description property to {1}." -f (Get-Date -Format s), $dc.HostName) | Out-File -FilePath $log_full_path -Append
    If ($description) {
        $dc | Add-Member -MemberType NoteProperty -Name Description -Value $description -Force
    }
    Else {
        $dc | Add-Member -MemberType NoteProperty -Name Description -Value 'No description found in Active Directory.' -Force
    }

    Write-Output ("{0}: Running Resolve-DnsName for {1}." -f (Get-Date -Format s), $dc.HostName) | Out-File -FilePath $log_full_path -Append
    Try {
        $ipV4Address = Resolve-DnsName -Name $dc.Hostname -Server $hostname | Select-Object @{Name = "IPv4Address"; Expression = {$_.IPAddress}} | Select-Object -ExpandProperty IPv4Address
    }
    Catch {
        Write-Output ("{0}: Running Resolve-DnsName failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
    }

    Write-Output ("{0}: Adding IpV4Address property to {1}." -f (Get-Date -Format s), $dc.HostName) | Out-File -FilePath $log_full_path -Append
    If ($ipV4Address) {
        $dc | Add-Member -MemberType NoteProperty -Name IpV4Address -Value $ipV4Address -Force
    }
    Else {
        $dc | Add-Member -MemberType NoteProperty -Name IpV4Address -Value 'No IP address found.' -Force
    }
}

Write-Output ("{0}: Attempting to use Get-ADReplicationSubnet." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $sites = Get-ADReplicationSubnet -Filter * -ErrorAction Stop @searchParams

    If ($sites) {
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
        Write-Output ("{0}: No sites found." -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append

        $siteList = 'RetrievalFailure'
    }
}
Catch {
    Write-Output ("{0}: Using Get-ADReplicationSubnet failed. Attempting to use the System.DirectoryServices.ActiveDirectory method." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
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
        } -ArgumentList $forest.Name
    }
    Catch {
        Write-Output ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
    }
}

Write-Output ("{0}: Running Get-ADObject to get site link properties." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $siteLinks = Get-ADObject @searchParams -Filter 'objectClass -eq "siteLink"' -SearchBase $searchBase -Property Name, Cost, ReplInterval, SiteList | Select-Object Name, SiteList, Cost, ReplInterval
}
Catch {
    Write-Output ("{0}: Running Get-ADObject failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Get-ADObject to get DHCP servers." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $authorizedDHCPServers = Get-ADObject @searchParams -Filter 'objectClass -eq "dhcpclass" -AND name -ne "dhcproot"' -SearchBase $searchBase
}
Catch {
    Write-Output ("{0}: Running Get-ADObject failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Get-ADTrusts." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $trusts = Get-ADTrust @searchParams -Filter * | Select-Object Target, Direction, ForestTransitive, IntraForest, TrustAttributes, SelectiveAuthentication, Authentication, @{Name = "TrustType"; Expression = {[string]$_.TrustType}}
}
Catch {
    Write-Output ("{0}: Running Get-ADTrusts failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Assigning trust attributes." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
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

Write-Output ("{0}: Running Get-ADOptionalFeature." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $optionalFeatures = Get-ADOptionalFeature @searchParams -Filter * | Select-Object Name, RequiredForestMode, RequiredDomainMode, @{Name = "Status"; Expression = {($_.EnabledScopes.Count -gt 0)}}
}
Catch {
    Write-Output ("{0}: Running Get-ADOptionalFeature failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Invoke-Command to get list of GPOs." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $gpoList = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {$hostname = $args[0]; Get-GPO -Server $hostname -All} -ArgumentList $hostname
}
Catch {
    Write-Output ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Running Invoke-Command to get GPO properties." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
Try {
    $gpoCsv = Invoke-Command -Credential $cred -ComputerName $hostname -ScriptBlock {Param ($FunctionCode, $hostname, $gpoList); . Invoke-Expression $FunctionCode; Get-GpoReportData -Hostname $hostname -GpoList $gpoList} -ArgumentList $code, $hostname, $gpoList
}
Catch {
    Write-Output ("{0}: Running Invoke-Command failed: {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append
}

Write-Output ("{0}: Assigning properties to `$backup." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append
$backup = @{
    ForestName            = $forest.Name
    ForestFunctionalLevel = $forest.ForestMode
    UPNSuffixes           = $forest.UPNSuffixes
    Sites                 = $forest.Sites
    GC                    = $forest.GlobalCatalogs
    DistinguishedName     = $domain.DistinguishedName
    DomainFunctionalLevel = $domain.DomainMode
    NetBIOSName           = $domain.NetBIOSName
    PDCEmulator           = $domain.PDCEmulator
    InfrastructureMaster  = $domain.InfrastructureMaster
    RIDMaster             = $domain.RIDMaster
    SchemaMaster          = $forest.SchemaMaster
    DomainNamingMaster    = $forest.DomainNamingMaster
    AllDomainControllers  = @($domainControllers)
    RODC                  = @($domainControllers | Where-Object {$_.IsReadOnly -eq $true})
    FullDomainControllers = @($domainControllers | Where-Object {$_.IsReadOnly -eq $false})
    SiteList              = @($siteList)
    SiteLinks             = @($siteLinks)
    DhcpServers           = @($authorizedDHCPServers.Name)
    Trusts                = @($trusts)
    OptionalFeatures      = @($optionalFeatures)
    GPOs                  = @($gpoCsv)
}

Write-Output ("{0}: Return `$backup." -f (Get-Date -Format s)) | Out-File -FilePath $log_full_path -Append

$backup

#Out-ItGlue -ActiveDirectory $backup -AutoTaskId 0 -ItGlueCustomerId $ItGlueCustomerId -ItGlueApiKey $ItGlueApiKey

<#

# Domain trusts
## use this code as a back-stop to the code in the get-adtrustlist function? Should this go in the function?
$remoteConnection = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('Forest', $RemoteForest, $RemoteAdmin, $RemotePassword)
$remoteForestConnection = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($remoteConnection)
$localForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($remoteConnection)
$localForest.GetAllTrustRelationships()
#>