# LogicMonitor-ActiveDirectory-ConfigSource

LogicMonitor ConfigSource to monitor a user-supplied list of Active Directory group (defined in the custom.MonitoredGroups property) for membership changes (recursivley).

By default, the ConfigSource applies to any device with the custom.MonitoredGroups property and system.Categories containing "MicrosoftDomainController" (which is applied using the included PropertySource). The wmi.user and wmi.pass properties are used to define the account that will query Active Directory.

The ConfigSource requires the domain controller to be running Active Directory Web Services and the collector to have the Active Directory PowerShell module (usually installed via RSAT).
