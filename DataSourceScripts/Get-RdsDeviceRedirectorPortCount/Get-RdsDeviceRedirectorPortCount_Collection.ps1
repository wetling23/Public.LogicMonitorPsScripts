<#
    .DESCRIPTION
        Get the count of inactive ports created by the Remote Desktop Services Device Redirector service.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 1 June 2020
            - Server 2008R2 KB: https://support.microsoft.com/en-us/help/2655998/long-logon-time-when-you-establish-an-rd-session-to-a-windows-server-2
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-RdsDeviceRedirectPortCount
#>
[CmdletBinding()]

$computerName = '##system.hostname##'

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-GetRdsDeviceRedirectorPortCount-collection-$computerName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

Try {
    $cred = New-Object System.Management.Automation.PSCredential("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force -ErrorAction Stop)) # Credential used to connect to remote machines.
}
Catch {
    If ($_.Exception.Message -match "Cannot bind argument to parameter 'String' because it is an empty string.") {
        $message = ("{0}: Missing wmi.user and/or wmi.pass property(ies). The script will continue without a credential variable." -f [datetime]::Now, $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    }
    Else {
        $message = ("{0}: Unexpected error creating a credential object. To prevent errors, the script will exit. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}

$message = ("{0}: Checking TrustedHosts." -f [datetime]::Now, $filter)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

# If necessary, update TrustedHosts.
If (-NOT(($computerName -eq $env:COMPUTERNAME) -or ($computerName -eq "127.0.0.1"))) {
    If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $computerName) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f [datetime]::Now, $computerName)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $computerName -Concatenate -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}." -f [datetime]::Now, $_.Exception.Message)
            If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            Exit 1
        }
    }
    Else {
        $message = ("{0}: {1} is already in TrustedHosts." -f [datetime]::Now, $filter)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    }
}

$message = ("{0}: Connecting to {1}, to query the registry for ports." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $uid)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response = Invoke-Command -ScriptBlock {
    Try {
        (Get-ChildItem -Path 'HKLM:SYSTEM\CurrentControlSet\Control\DeviceClasses\{28d78fad-5a12-11d1-ae5b-0000f803a8c2}\##?#Root#RDPBUS#0000#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}\' -Recurse -ErrorAction Stop | Where-Object {$_.Name -match '\#TS[0-9]{0,3}$'} | Select-Object -Property Name).Count
    }
    Catch {
        ("Error: {0}" -f $_.Exception.Message)
    }
} -Credential $cred -ComputerName $computerName


If ($response -as [int]) {
    Write-Host ("TsPortCount={0}" -f $response)

    Exit 0
}
Else {
    Write-Host ("{0}" -f $response)
    Write-Host ("TsPortCount=0")

    Exit 1
}