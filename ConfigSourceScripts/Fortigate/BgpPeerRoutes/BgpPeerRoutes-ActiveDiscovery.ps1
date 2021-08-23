<#
    .DESCRIPTION
        Collect BGP peer information.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 15 February 2021
            - Requires the Posh-SSH PowerShell module (Install-Module -Name Posh-SSH).
        V1.0.0.1 date: 26 February 2021
        V1.0.0.2 date: 31 March 2021
        V1.0.0.3 date: 18 August 2021
        V1.0.0.4 date: 23 August 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Fortigate/BgpPeerRoutes/
    .EXAMPLE
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param ()

Try {
    #region Setup
    # Initialize variables.
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\configsource-bgp_peer_routes-activediscovery-$computerName.log"

    $pw = @'
##ssh.pass##
'@
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##ssh.user##', ($pw | ConvertTo-SecureString -AsPlainText -Force))
    $regex = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
    $exitCode = 0
    $vdoms = "##AUTO.FORTINET.VDOMLIST##"
    If ($vdoms -match ",") { $vdoms = $vdoms.Split(',') }

    $command1 = 'get router info bgp sum'

    If ($vdoms) {
        $expandedCommand = "config vdom`r`n`tedit $($vdoms.Split(',')[0])`r`n`t" # Need double quotes here, so PS will parse the hidden characters correctly.
    } Else {
        $expandedCommand = $null
    }

    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to establish an SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    Try {
        $session = New-SSHSession -ComputerName $computerName -Credential $credential -ErrorAction Stop -AcceptKey -Force
    } Catch {
        $message = ("{0}: Unexpected error establishing an SSH session to {1}. The error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    If ($session) {
        $message = ("{0}: SSH session established." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Unable to establish the SSH session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $exitCode = 1
    }

    If ($vdoms) {
        Foreach ($vdom in $vdoms) {
            $message = ("{0}: Running BGP commands." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $message = ("{0}: Running:`r`n`t{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$expandedCommand$command1")
            $message | Out-File -FilePath $logFile -Append

            Try {
                $bgpResponse = Invoke-SSHCommand -SSHSession $session -Command $expandedCommand$command1 -ErrorAction Stop
            } Catch {
                $message = ("{0}: Unexpected error running the bgp command. The error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                $message | Out-File -FilePath $logFile -Append

                $exitCode = 1
            }

            If ($bgpResponse.Output) {
                $message = ("{0}: Captured response, parsing it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append

                $ips = Foreach ($line in $bgpResponse.Output) {
                    If ($line -match $regex) {
                        (($line | Select-String -Pattern $regex) -split ' ')[0]
                    }
                }

                If ($ips) {
                    $message = ("{0}: Found {1} IP addresses." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ips.Count)
                    $message | Out-File -FilePath $logFile -Append

                    Foreach ($ip in $ips) {
                        Write-Host "$ip received-routes##$ip received-routes-$vdom"
                        Write-Host "$ip advertised-routes##$ip received-routes-$vdom"
                    }
                } Else {
                    $message = ("{0}: No IP addresses returned." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    Write-Host $message; $message | Out-File -FilePath $logFile -Append
                }
            } Else {
                $message = ("{0}: No response." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                Write-Host $message; $message | Out-File -FilePath $logFile -Append

                $exitCode = 1
            }
        }
    }
    ElseIf ($exitCode -eq 0) {
        $message = ("{0}: Running BGP commands." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        $message = ("{0}: Running:`r`n`t{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$command1")
        $message | Out-File -FilePath $logFile -Append

        Try {
            $bgpResponse = Invoke-SSHCommand -SSHSession $session -Command $command1 -ErrorAction Stop
        } Catch {
            $message = ("{0}: Unexpected error running the bgp command. The error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            $message | Out-File -FilePath $logFile -Append

            $exitCode = 1
        }

        If ($bgpResponse.Output) {
            $message = ("{0}: Captured response, parsing it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $ips = Foreach ($line in $bgpResponse.Output) {
                If ($line -match $regex) {
                    (($line | Select-String -Pattern $regex) -split ' ')[0]
                }
            }

            If ($ips) {
                $message = ("{0}: Found {1} IP addresses." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ips.Count)
                $message | Out-File -FilePath $logFile -Append

                Foreach ($ip in $ips) {
                    Write-Host "$ip received-routes##$ip received-routes-novdoms"
                    Write-Host "$ip advertised-routes##$ip advertised-routes-novdoms"
                }
            } Else {
                $message = ("{0}: No IP addresses returned." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                Write-Host $message; $message | Out-File -FilePath $logFile -Append
            }
        } Else {
            $message = ("{0}: No response." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            $exitCode = 1
        }
    }
    #endregion Main

    #region Cleanup
    $message = ("{0}: Attempting to cleanup the SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue
    #endregion Cleanup

    $message = ("{0}: {1} is complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -FilePath $logFile -Append

    Exit $exitCode
} Catch {
    $null = $session | Remove-SSHSession -ErrorAction SilentlyContinue

    $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    $message | Out-File -FilePath $logFile

    Exit 1
}