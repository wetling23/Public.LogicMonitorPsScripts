Function Get-AdForestList {
    <#
        .DESCRIPTION
            Gets the first forest root with interesting information.
        .NOTES
            V1.0.0.0 date: 2 October 2018
                - Initial release.
            V1.0.0.1 date: 11 January 2019
        .PARAMETER BaseForestDnsName
            FQDN of the desired Active Directory forest.
        .PARAMETER Credentials
            PowerShell credential used to connect to the desired forest.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $True)]
        [string]$BaseForestDnsName,

        [Parameter(Mandatory = $True, ParameterSetName = "CredsProvided")]
        [System.Management.Automation.PSCredential]$Credential
    )

    # Initialize variables.
    $ForestList = @()

    Switch ($PsCmdlet.ParameterSetName) {
        "CredsProvided" {
            $cmdParams = @{Credential = $Credential; Server = $BaseForestDnsName}
        }
        "Default" {
            $cmdParams = @{Server = $BaseForestDnsName}
        }
    }

    # Get AD forest properties.
    $ForestList += Get-AdForest @cmdParams | `
        Select-Object Name, ForestMode, RootDomain, Domains, DomainDetails, DomainNamingMaster, SchemaMaster, OptionalFeatures, GlobalCatalogs, UPNSuffixes, Sites, SiteDetails, SiteLinks, ReplicationPartners, Subnets, Trusts, `
    @{Name = "Polling Date"; Expression = {Get-Date -Format yyyy-MM-dd}} | Sort-Object Name

    Return $ForestList
} #1.0.0.1

$credential = New-Object System.Management.Automation.PSCredential ('##WMI.USER##', (ConvertTo-SecureString '##WMI.PASS##' -AsPlainText -Force))

Get-AdForestList -BaseForestDnsName "##SYSTEM.DOMAIN##" -Credential $credential