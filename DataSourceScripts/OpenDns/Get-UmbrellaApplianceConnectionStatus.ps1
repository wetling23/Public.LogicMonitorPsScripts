<#
    .DESCRIPTION
        Query Umbrella virtual appliance for connection-status data. 
    .NOTES
        V1.0.0.0 date: 22 September 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/OpenDns/
#>

$hostaddr = "##SYSTEM.HOSTNAME##"
$community = "##SNMP.COMMUNITY##"
$port = "##SNMP.PORT"
If (($port) -and ($port -match "^[\d]+$")) { $snmpPort = $port } Else { $snmpPort = '161' } # $port is defined and matches any whole number.

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-UmbrellaApplianceConnectionStatus-collection-$hostaddr.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$message = ("{0}: Attempting to get data from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hostaddr)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$response = (snmpget.exe -r:$hostaddr -p:$snmpPort -c:"$community" -o:"1.3.6.1.4.1.8072.1.3.2.4.1.2.7.116.104.105.115.100.110.115.1").Split('=')[-1]
If ($response -match 'green') {
    $vaStatus = 0
}
ElseIf ($response -match 'red') {
    $vaStatus = 1
}

$response = (snmpget.exe -r:$hostaddr -p:$snmpPort -c:"$community" -o:"1.3.6.1.4.1.8072.1.3.2.4.1.2.3.100.110.115.1").Split('=')[-1]
If ($response -match 'green') {
    $connectivityToUmbrellaResolvers = 0
}
ElseIf ($response -match 'red') {
    $connectivityToUmbrellaResolvers = 1
}

$response = (snmpget.exe -r:$hostaddr -p:$snmpPort -c:"$community" -o:"1.3.6.1.4.1.8072.1.3.2.4.1.2.8.108.111.99.97.108.100.110.115.1").Split('=')[-1]
If ($response -match 'green') {
    $connectivityToLocalDnsServers = 0
}
ElseIf ($response -match 'red') {
    $connectivityToLocalDnsServers = 1
}

$response = (snmpget.exe -r:$hostaddr -p:$snmpPort -c:"$community" -o:"1.3.6.1.4.1.8072.1.3.2.4.1.2.5.99.108.111.117.100.1").Split('=')[-1]
If ($response -match 'green') {
    $connectivityToUmbrellaDashboard = 0
}
ElseIf ($response -match 'red') {
    $connectivityToUmbrellaDashboard = 1
}

$response = (snmpget.exe -r:$hostaddr -p:$snmpPort -c:"$community" -o:"1.3.6.1.4.1.8072.1.3.2.4.1.2.2.97.100.1").Split('=')[-1]
If ($response -match 'green') {
    $connectivityToAdConnectors = 0
}
ElseIf ($response -match 'red') {
    $connectivityToAdConnectors = 1
}

$message = ("{0}: Returning values." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    Write-Host ("VaStatus={0}" -f $vaStatus)
    Write-Host ("ConnectivityToUmbrellaResolvers={0}" -f $connectivityToUmbrellaResolvers)
    Write-Host ("ConnectivityToLocalDnsServers={0}" -f $connectivityToLocalDnsServers)
    Write-Host ("ConnectivityToUmbrellaDashboard={0}" -f $connectivityToUmbrellaDashboard)
    Write-Host ("ConnectivityToAdConnectors={0}" -f $connectivityToAdConnectors)
    Write-Host ("ScriptStatus=0")

    Exit 0
}
Catch {
    $message = ("{0}: Unexpected error writting out the results. The specific error is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host ("ScriptStatus=1")

    Exit 1
}