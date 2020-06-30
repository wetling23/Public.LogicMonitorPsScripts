<#
    .DESCRIPTION
        Test if PS remoting is enabled on a local or remote machine, using Invoke-Command.
    .NOTES
        V1.0.0.0 date: 30 June 2020
            - Based on the function from Lee Holmes: https://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
    .LINK
        
    .PARAMETER ComputerName
        Represents the name of the device, on which to test PS Remoting.
    .PARAMETER Credential
        When testing a remote machine, this credential represents a user with access to remotely manage the target computer.
    .PARAMETER LocalCheck
        Switch used to indicate whether or not the value of -ComputerName is the local machine.
    .PARAMETER LogFile
        Path to which logging will be written (including file name).
#>
Function Test-PsRemoting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [System.Management.Automation.PSCredential]$Credential,

        [switch]$LocalCheck,

        [string]$LogFile
    )

    $message = ("{0}: Running Invoke-Command." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $LogFile -Append } Else { $message | Out-File -FilePath $LogFile -Append }

    Try {
        If ($LocalCheck) {
            $result = Invoke-Command -ComputerName $ComputerName { 1 } -ErrorAction Stop
        }
        Else {
            $result = Invoke-Command -Credential $Credential -ComputerName $ComputerName { 1 } -ErrorAction Stop
        }
    }
    Catch {
        $message = ("{0}: Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $LogFile -Append } Else { $message | Out-File -FilePath $LogFile -Append }

        Return $false
    }

    If ($result -ne 1) {
        $message = ("{0}: Remoting to {1} returned an unexpected result." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $LogFile -Append } Else { $message | Out-File -FilePath $LogFile -Append }

        Return $false
    }

    $true
}

Try {
    # Initialize variables.
    $ComputerName = "##SYSTEM.HOSTNAME##"
    $Credential = New-Object System.Management.Automation.PSCredential("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force -ErrorAction Stop))

    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    }
    Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-TestPsRemoting-collection-$ComputerName.log"

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $message = ("{0}: Checking TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    # If necessary, update TrustedHosts.
    If (-NOT(($ComputerName -eq $env:ComputerName) -or ($ComputerName -eq "127.0.0.1"))) {
        If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $ComputerName) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*")) {
            $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            Try {
                Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $ComputerName -Concatenate -Force -ErrorAction Stop
            }
            Catch {
                $message = ("{0}: Unexpected error updating TrustedHosts: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

                Exit 1
            }
        }
        Else {
            $message = ("{0}: {1} is already in TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
        }
    }

    If (($ComputerName -eq $env:ComputerName) -or ($ComputerName -eq "127.0.0.1")) {
        $result = Test-PsRemoting -ComputerName $ComputerName -LogFile $logFile -LocalCheck
    }
    Else {
        $result = Test-PsRemoting -ComputerName $ComputerName -LogFile $logFile -Credential $Credential
    }

    If ($result -eq $false) {
        $message = ("{0}: PS remoting is not enabled on {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Write-Host ("PsRemotingEnabled=0")
    }
    Else {
        $message = ("{0}: PS remoting is enabled on {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Write-Host ("PsRemotingEnabled=1")
    }

    Exit 0
}
Catch {
    $message = ("{0}: Unexpected error in {1}. The command was `"{2}`" and the specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}