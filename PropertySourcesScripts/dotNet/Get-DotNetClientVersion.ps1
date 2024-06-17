<#
    .DESCRIPTION
        Query Windows registry and return the newest installed version of .Net Framework.
    .NOTES
        V2024.06.16.0
        V2024.06.17.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/dotNet
#>
[CmdletBinding()]
param ()
#Requires -Version 5.0

#region Setup
#region Variables
$computer = '##system.hostname##'
#endregion Variables

#region Logging file setup
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\propertySource-Get_Dot_Net_Client_Version-$computer.log"
#endregion Logging file setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile

# If necessary, update TrustedHosts.
If (-NOT(($computer -eq $env:computerName) -or ($computer -eq "127.0.0.1"))) {
    If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $computer) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer); $message | Out-File -FilePath $logFile -Append

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $computer -Concatenate -Force -ErrorAction Stop
        } Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message); $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    } Else {
        $message = ("{0}: {1} is already in TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $filter); $message | Out-File -FilePath $logFile -Append
    }
}
#endregion Setup

#region Main
$remoteResponse = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
    $message += ("{0}: Running command on remote computer.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))

    Try {
        $version = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -ErrorAction SilentlyContinue | Where-Object { ($_.PSChildName -Match '^(?!S)\p{L}') -and ($_.PSChildName -eq 'Client') } | Sort-Object -Property version | Select-Object -ExpandProperty version -Last 1
    } Catch {
        $message += ("{0}: Unexpected error getting the hightest available .Net Framework version. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)

        $version = -1
    }

    Return $version, $message
}

$message = $remoteResponse[-1]
$version = $remoteResponse[0]
$message | Out-File -FilePath $logFile -Append
#region Main

#region Output
If (($version) -and ($version -eq -1)) {
    $message = ("{0}: No .Net Framework version retrieved. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile -Append

    Exit 1
} ElseIf (($version) -and ($version -match '\d+(\.\d+)+')) {
    Write-Host ("auto.dotnetframeworkversion={0}" -f $version)
} Else {
    $message = ("{0}: Unknown state. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Output

Exit 0