<#
    .DESCRIPTION
        Uses the custom.vdom property to discover VDOM instances on Fortigate devices.
    .NOTES
        V1.0.0.0 date: 14 July 2020
        V1.0.0.1 date: 23 February 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Fortigate/bgp
#>

$hostaddr = "##SYSTEM.HOSTNAME##"
$community = "##SNMP.COMMUNITY##"
$vdoms = "##CUSTOM.VDOM##"
$port = "##SNMP.PORT"
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

If ($vdoms -match ",") { $vdoms = $vdoms.Split(',') }

$message = ("{0}: There are {1} vdoms on the device ({2})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $vdoms.Count, ($vdoms | Out-String))
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Beginning snmpwalk, to get BGP peer instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$vdoms | ForEach-Object {
    $vdom = $_

    $message = ("{0}: Using the following settings:`r`n`tHost: {1}`r`n`tSNMP version: {2}`r`n`tPort: {3}`r`n`tCommunity: {4}`r`n`tVdom: {5}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hostaddr, $snmpVersion, $snmpPort, ($community -Replace "[\w\W]", '*'), $vdom)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $snmpwalkResult = (snmpwalk.exe -r:$hostaddr -$snmpVersion -p:$snmpPort -c:"$community-$vdom" -os:1.3.6.1.2.1.15.3.1.7 -op:1.3.6.1.2.1.15.3.1.8) | ConvertFrom-String -Delimiter "," -PropertyNames oid, type, value

    If ($snmpwalkResult) {
        $message = ("{0}: Found {1} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $snmpwalkResult.Count)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        $snmpwalkResult | Foreach-Object {
            Write-Host "$($_.value.Split('=')[-1])##$($_.value.Split('=')[-1])####$vdom"
        }
    }
    Else {
        $message = ("{0}: Found zero instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    }
}

Exit 0