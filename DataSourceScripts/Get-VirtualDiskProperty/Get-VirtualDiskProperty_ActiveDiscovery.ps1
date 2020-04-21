<#
    .DESCRIPTION
        Get properties of virtual disks of the monitored device(s).
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 20 April 2020
            - Initial release
    .LINK
        
#>

# Initialize variables.
$computerName = '##system.hostname##'

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-MonitorVirtualDisk-AD-$computerName.log"

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
If (-NOT(($computerName -eq $env:computerName) -or ($computerName -eq "127.0.0.1"))) {
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

$message = ("{0}: Connecting to {1}, to retieve virtual disk information." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response = Invoke-Command -ScriptBlock { Get-VirtualDisk } -Credential $cred -ComputerName $computer

$message = ("{0}: Found {1} virtual disks on {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.Count, $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response | ForEach-Object {
    "$($_.FriendlyName)##$($_.UniqueId)"
}

Exit 0




collection script below


$friendlyName = "##WILDVALUE##"

$response = Invoke-Command -ScriptBlock {
    param(
        $friendlyName
    )

    Get-VirtualDisk -FriendlyName $friendlyName
} -Credential $cred -ComputerName $computer -ArgumentList $friendlyName

$response | ForEach-Object {
    If ($_.IsManualAttach) {
        "IsManualAttach=1"
    }
    Else {
        "IsManualAttach=0"
    }
}
