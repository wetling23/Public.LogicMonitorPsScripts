<#
    .DESCRIPTION
        Uses the AUTO.FORTINET.VDOMLIST property (https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/PropertySourcesScripts/fortinet/Get-FortigateVdomList.ps1) to discover VDOM instances on Fortigate devices.
    .NOTES
        V1.0.0.0 date: 14 July 2020
        V1.0.0.1 date: 23 February 2021
        V1.0.0.2 date: 18 August 2021
        V2023.06.21.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Fortigate/bgp
#>

#region Setup
#region Initialize variables
$hostaddr = "##SYSTEM.HOSTNAME##"
$community = "##SNMP.COMMUNITY##"
$vdoms = "##AUTO.FORTINET.VDOMLIST##"
$port = "##SNMP.PORT"
If (("##SNMP.VERSION##") -and ("##SNMP.VERSION##" -notmatch "2c$")) { $snmpVersion = "##SNMP.VERSION##" } Else { $snmpVersion = 'v2c' }
If (($port) -and ($port -match "^[\d]+$")) { $snmpPort = $port } Else { $snmpPort = '161' } # $port is defined and matches any whole number.
If ($vdoms -match ",") { $vdoms = $vdoms.Split(',') }
#endregion Initialize variables

#region Logging
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Fortigate_Vdom_Bgp-ad-$hostaddr.log"
#endregion Logging

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host -Message $message; $message | Out-File -FilePath $logFile

If ($vdoms -match 'disabled') {
    $message = ("{0}: VDOMs are not enabled on the device." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $vdoms.Count, ($vdoms | Out-String))
    Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append

    Exit 0
} Else {
    $message = ("{0}: There are {1} vdoms on the device ({2})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $vdoms.Count, ($vdoms | Out-String))
    Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append
}

#endregion Setup

#region SNMP walk
$message = ("{0}: Beginning snmpwalk, to get BGP peer instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append

$vdoms | ForEach-Object {
    $vdom = $_

    $message = ("{0}: Using the following settings:`r`n`tHost: {1}`r`n`tSNMP version: {2}`r`n`tPort: {3}`r`n`tCommunity: {4}`r`n`tVdom: {5}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hostaddr, $snmpVersion, $snmpPort, ($community -Replace "[\w\W]", '*'), $vdom)
    Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append

    $snmpwalkResult = (snmpwalk.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -os:1.3.6.1.2.1.15.3.1.7 -op:1.3.6.1.2.1.15.3.1.8) | ConvertFrom-String -Delimiter "," -PropertyNames oid, type, value

    If ($snmpwalkResult) {
        $message = ("{0}: Found {1} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $snmpwalkResult.Count)
        Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append

        $snmpwalkResult | Foreach-Object {
            Write-Host "$($_.value.Split('=')[-1])##$($_.value.Split('=')[-1])####$vdom"
        }
    }
    Else {
        $message = ("{0}: Found zero instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host -Message $message; $message | Out-File -FilePath $logFile -Append
    }
}
#endregion SNMP walk

Exit 0