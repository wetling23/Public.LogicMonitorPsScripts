<#
    .DESCRIPTION
        Connects to the Meraki API, to retrieve DHCP subnet statistics.

        Requires the auto.serialNumber and meraki.api.key (API key with rights to access the defined organization) properties.
    .NOTES
        V2022.10.26.0
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Meraki
#>
[CmdletBinding()]
param ()
#Requires -Version 5.0

#region Setup
$computer = '##system.hostname##'
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-GetMerakiDhcpSubnetStats-ad-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

#region Variables
$apiKey = "##meraki.api.key##"
$serialNumber = "##auto.serialnumber##"
$baseUri = "https://dashboard.meraki.com/api/v1"
$headers = @{
    "X-Cisco-Meraki-API-Key" = $apiKey
    "Content-Type" = "application/json"
}
#endregion Variables
#endregion Setup

#region Get DHCP lease info
$commandParams = @{
    Method      = "GET"
    Uri         = "$baseUri/devices/$serialNumber/appliance/dhcp/subnets"
    ErrorAction = 'Stop'
    Headers     = $headers
}

$dhcpPools = Invoke-RestMethod @commandParams
#endregion Get DHCP lease info

#region Output
If ($dhcpPools) {
    Foreach ($subnet in $dhcpPools) {
        $message = ("{0}: Returning instance name {1} for VLAN {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $subnet.subnet, $subnet.vlanId)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("{0}##{0}" -f $subnet.subnet)
    }

    Exit 0
} Else {
    $message = ("{0}: No subnets retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Output