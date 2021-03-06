<#
    .DESCRIPTION 
        Retrieves the out-of-band management IP (IPMI, iLO, iDRAC) from vSphere hosts.
    .NOTES
        Author: Daniel Bapple with modification by Mike Hashemi
        V1.0.0.0 date: 14 August 2018
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/DataSourceScripts/vSphere_IPMI_IP_Address.ps1
#>
$esxuser = '##ESX.USER##'
$esxpass = '##ESX.PASS##'
$hostname = '##HOSTNAME##'

$null = Get-Module -Name VMware* -ListAvailable | Import-Module
$null = Connect-VIServer -server "$hostname" -user "$esxuser" -password "$esxpass"

$omcBase = "http://schema.omc-project.org/wbem/wscim/1/cim-schema/2/"
$dmtfBase = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/"
$vmwareBase = "http://schemas.vmware.com/wbem/wscim/1/cim-schema/2/"
$option = New-WSManSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$class = "OMC_IPMIIPProtocolEndpoint"

$password = ConvertTo-SecureString "$esxpass" -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$esxuser", $password
$uri = "https`://$hostname/wsman"

If ($class -cmatch "^CIM") {
    $baseUrl = $dmtfBase
}
ElseIf ($class -cmatch "^OMC") {
    $baseUrl = $omcBase
}
ElseIf ($class -cmatch "^VMware") {
    $baseUrl = $vmwareBase
}
Else {
    throw "Unrecognized class"
}

$info = Get-WSManInstance -Authentication basic -ConnectionURI $uri -Credential $credential -Enumerate -Port 443 -UseSSL -SessionOption $option -ResourceURI "$baseUrl/$class"

Write-Host $info.IPv4Address"##"$info.IPv4Address

Disconnect-VIServer -Confirm:$false