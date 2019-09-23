# Initialize variables.
$computerName = "##HOSTNAME##"

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-HyperV_Checkpoint_Age-ad-$computerName.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile }

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

$vms = Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock {
    Try {
        Get-VM -ErrorAction Stop
    }
    Catch {
        Else {
            $message = ("{0}: Unexpected error getting the list of virtual machines for {1}. The specific error is: {1}." -f [datetime]::Now, $vmName, $_.Exception.Message)
            Write-Error $message

            ("Error: {0}" -f $_.Exception.Message)
        }
    }
}

If ($vms -match "Error: ") {
    $message = ("{0}: Unexpected error getting the list of virtual machines for {1}. The specific error is: {1}." -f [datetime]::Now, $vmName, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1s
}
Else {
    Foreach ($vm in $vms) {
        Write-Host "$($vm.VmId)##$($vm.Name)"
    }

    Exit 0
}