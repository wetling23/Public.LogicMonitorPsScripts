Function Get-CheckpointAge {
    <#
        .DESCRIPTION
            Connects to a remove Hyper-V host and retrieves the VM checkpoints for the user-specified virtual machine.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 23 September 2019
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-HyperVCheckpointAge
        .PARAMETER ComputerName
            Represent the name or IP of the Hyper-V host, which will be queried.
        .PARAMETER Id
            Represents the ID of the virtual machine, where we will check for checkpoints.
        .PARAMETER Credential
            Credential object to be used to connect to the machine specified in $ComputerName.
        .PARAMETER LogFile
            Path and file name, to which the command will send output logs.
        .EXAMPLE
            PS C:\> Get-CheckpointAge -ComputerName host1 -Id f4bb6f9d-be72-4185-895f-e531329f973e -Credential (Get-Credential) -LogFile C:\Temp\log.txt

            In this example, the script will prompt the user for a credential and will use that credential to connect to host1 to check the VM with ID f4bb6f9d-be72-4185-895f-e531329f973e, for checkpoints.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $checkpoints = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        param (
            $Id
        )

        Try {
            $response = Get-VM -Id $Id -ErrorAction Stop | Get-VMSnapshot -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error getting the list of checkpoints for {1}. The specific error is: {2}." -f [datetime]::Now, $Id, $_.Exception.Message)
            Write-Error $message

            ("Error: {0}" -f $_.Exception.Message)
        }

        $response
    } -ArgumentList $Id -ErrorAction Stop

    If ($checkpoints -match 'Error:') {
        $message = ("{0}: The host ({1}) returned an error: {2}." -f [datetime]::Now, $ComputerName, $checkpoints)
        Write-Error $message; $message | Out-File -FilePath $LogFile -Append
    }
    Else {
        $checkpoints
    }
}


#region Initialize variables
$computerName = "##HOSTNAME##" # Target host for the script to query.
$vmId = "##wildvalue##"

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-HyperV_Checkpoint_Age-collection-$computerName.log"

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
#endregion initialize variables

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile }

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
        $message = ("{0}: {1} is already in TrustedHosts." -f [datetime]::Now, $computerName)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    }
}

$message = ("{0}: Calling Get-CheckpointAge for {1}." -f [datetime]::Now, $vmId)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$checkpoints = Get-CheckpointAge -ComputerName $computerName -Credential $cred -Id $vmId -LogFile $logFile

If ($checkpoints.CreationTime) {
    $message = ("{0}: Checking for checkpoint age." -f [datetime]::Now)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host ("OldestCheckpointAge={0}" -f ((New-TimeSpan -Start $($checkpoints | Sort-Object -Descending | Select-Object -First 1).CreationTime -End (Get-Date))).Hours)
}
Else {
    $message = ("{0}: Zero checkpoints returned." -f [datetime]::Now)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
}

Write-Host ("CheckpointCount={0}" -f $checkpoints.Count)

If ($checkpoints -match 'Error:') {
    Exit 1
}
Else {
    Exit 0
}