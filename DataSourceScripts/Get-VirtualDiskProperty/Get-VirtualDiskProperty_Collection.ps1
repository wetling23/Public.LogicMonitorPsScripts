<#
    .DESCRIPTION
        Get properties of virtual disks of the monitored device(s).
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 23 April 2020
            - Initial release
    .LINK
        
#>
[CmdletBinding()]

$computerName = '##system.hostname##'
$uid = "##wildvalue##"

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-GetVirtualDiskProperty-collection-$computerName.log"

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

$message = ("{0}: Connecting to {1}, to retieve virtual disk information for the disk labled: {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $uid)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$response = Invoke-Command -ScriptBlock {
    param(
        $uid
    )

    Try {
        Get-VirtualDisk -UniqueId $uid -ErrorAction Stop
    }
    Catch {
        "Error"
    }
} -Credential $cred -ComputerName $computerName -ArgumentList $uid

$message = ("{0}: Disk properties:`r`n`t{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String))
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

If ($response -eq "Error") {
    $message = ("{0}: Unknown error getting properties of the virtual disk." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}
ElseIf ($response.IsManualAttach -eq $true) {
    $message = ("{0}: The disk is set to manual attach." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    "IsManualAttach=1"
}
ElseIf ($response.IsManualAttach -eq $false) {
    $message = ("{0}: The disk is not set to manual attach." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    "IsManualAttach=0"
}