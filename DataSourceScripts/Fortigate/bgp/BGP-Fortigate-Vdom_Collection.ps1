<#
    .DESCRIPTION
        Query BGP peer data from Fortigate devices configured with one or more VDOMs configured. 
    .NOTES
        V1.0.0.0 date: 14 July 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Fortigate/bgp
#>

$hostaddr = "##SYSTEM.HOSTNAME##"
$community = "##SNMP.COMMUNITY##"
$vdom = "##WILDVALUE2##"
$port = "##SNMP.PORT"
$instance = "##WILDVALUE##" # IP address of the BGP peer
If (("##SNMP.VERSION##") -and ("##SNMP.VERSION##" -notmatch "2c$")) { $snmpVersion = "##SNMP.VERSION##" } Else { $snmpVersion = 'v2c' }
If (($port) -and ($port -match "^[\d]+$")) { $snmpPort = $port } Else { $snmpPort = '161' } # $port is defined and matches any whole number.

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Fortigate_Vdom_Bgp-ad-$hostaddr.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Attempting to get data from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $instance)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

# Properties from the BGP- DataSource.
$establishedTime = ((snmpget.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -o:"1.3.6.1.2.1.15.3.1.16.$instance")[-1]).Split('=')[-1]
$peerInUpdates = ((snmpget.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -o:"1.3.6.1.2.1.15.3.1.10.$instance")[-1]).Split('=')[-1]
$peerOutUpdates = ((snmpget.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -o:"1.3.6.1.2.1.15.3.1.11.$instance")[-1]).Split('=')[-1]
$peerState = ((snmpget.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -o:"1.3.6.1.2.1.15.3.1.2.$instance")[-1]).Split('=')[-1]

$message = ("{0}: Returning values." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    Write-Host ("EstablishedTime={0}" -f $establishedTime)
    Write-Host ("PeerInUpdates={0}" -f $peerInUpdates)
    Write-Host ("PeerOutUpdates={0}" -f $peerOutUpdates)
    Write-Host ("PeerState={0}" -f $peerState)
    Write-Host ("ScriptStatus=0")

    Exit 0
}
Catch {
    $message = ("{0}: Unexpected error writting out the results. The specific error is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host ("ScriptStatus=1")

    Exit 1
}