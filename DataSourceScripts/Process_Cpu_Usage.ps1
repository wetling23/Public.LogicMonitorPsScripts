Function Get-ProcessCpuUsage {
    <#
        .SYNOPSIS
            Sum the results of a CPU-utilization query, to display total CPU used by a user-defined list of processes.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 7 December 2017
                - Initial release.
            V1.0.0.1 date: 5 May 2019
                - Improved performance with System.Collections.Generic.List and Get-CimInstance.
            V1.0.0.2 date: 5 May 2019
                - Swapped Get-CimInstance for Get-Counter.
            V1.0.0.3 date: 6 May 2019
                - Functionality updates for PS v4.
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/DataSourceScripts
        .PARAMETER ComputerName
            FQDN or IP of the target server.
        .PARAMETER ProcessName
            String array of process names.
        .PARAMETER Credential
            Windows credential with rights to connect to the target server.
        .EXAMPLE
            PS C:> Get-ProcessCpuUsage -ComputerName server1 -ProcessName 'conhost','svchost' -Credential (Get-Credential)

            In this example, the script connects to server1 and gets the CPU utilization of the conhost and svchost processes. The user is prompted for credentials so server1 will allow the connection.
    #>
    [CmdletBinding()]
    Param (
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string[]]$ProcessName,

        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Output ("Beginning {0}." -f $MyInvocation.MyCommand)

    # Initialize variables.
    [decimal]$totalCpu = 0 # Will contain the sum of the CPU utilization.

    If ($ComputerName -eq $env:COMPUTERNAME) {
        Write-Output ("The target machine name ({0}) matches the local host name, working locally." -f $ComputerName)

        $runningProcesses = $ProcessName | Where-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue }

        If ($runningProcesses.Count) {
            $counterData = Foreach ($process in $runningProcesses) {
                Write-Output ("Working on process: {0}." -f $process)

                If (-NOT(Get-Process -Name $process -ErrorAction SilentlyContinue)) {
                    Write-Output ("Process was not found.")

                    [void]$ProcessName.Remove($process)

                    Continue
                }

                Write-Output ("Attempting to get counter data for {0}." -f $process)

                Try {
                    (Get-Counter "\Process($process)\% Processor Time" -ErrorAction Stop).CounterSamples.CookedValue
                }
                Catch {
                    $_.Exception.Message
                }
            }
        }
    }
    Else {
        Write-Output ("Connecting to {0}, to get CPU utilization." -f $ComputerName)

        $runningProcesses = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            param (
                $Names
            )

            $Names | Where-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue }
        } -ArgumentList $ProcessName -ErrorAction Stop

        $counterData = Foreach ($process in $runningProcesses) {
            #Write-Output ("Working on process: {0}." -f $process)

            Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                Try {
                    (Get-Counter "\Process($($args[0]))\% Processor Time" -ErrorAction Stop).CounterSamples.CookedValue
                }
                Catch {
                    $_.Exception.Message
                }
            } -ArgumentList $process -ErrorAction Stop
        }
    }

    If ($counterData -match 'The \\Process') {
        "cpu=-1"
        Write-Host ("message={0}" -f ($counterData | Where-Object { $_ -isnot [ValueType] }))
    }
    Else {
        Foreach ($item in $counterData) {
            $totalCpu += $item
        }

        "cpu=$totalCpu"
        Write-Host ("message=No errors")
    }
}

# Initialize variables.
$ComputerName = "##HOSTNAME##" # Target host for the script to query.
$cred = New-Object System.Management.Automation.PSCredential("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))
$procs = [System.Collections.Generic.List[String]]@((("##custom.procCpu##").Split(',')).Replace("`"", ""))

# Add the target device to TrustedHosts.
If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $ComputerName) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($ComputerName -ne "127.0.0.1")) {
    #Write-Output ("{0}: Adding {1} to TrustedHosts." -f (Get-Date -Format s), $ComputerName) | Out-File -FilePath $log_full_path -Append

    Try {
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $ComputerName -Concatenate -Force -ErrorAction Stop
    }
    Catch {
        #Write-Output ("{0}: Unexpected error updating TrustedHosts: {1}." -f (Get-Date -Format s), $_.Exception.Message) | Out-File -FilePath $log_full_path -Append

        Exit 0
    }
}
Else {
    Write-Output ("{0}: {1} is in TrustedHosts." -f (Get-Date -Format s), $ComputerName) #| Out-File -FilePath $log_full_path -Append
}

Get-ProcessCpuUsage -ComputerName $ComputerName -ProcessName $procs -Credential $cred