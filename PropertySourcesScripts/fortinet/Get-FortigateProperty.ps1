<#
    .DESCRIPTION
        Returns:
         - SSL VPN is enabled status for any VDOMs (or the firewall overall, if VDOM is not enabled)
         - Count of fgfm enabled ports
         - IP address of FortiManager
         - List of configured VDOMs
    .NOTES
        Author: Mike Hashemi
        V2024.02.08.0
            - Requires the Posh-SSH PowerShell module (Install-Module -Name Posh-SSH).
        V2024.02.08.1
        V2024.02.13.0
        V2024.02.13.1
        V2024.02.13.2
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/fortinet
    .EXAMPLE
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param ()

Try {
    #region Setup
    #region Initialize variables
    #region Creds
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If ('##ssh.user##' -and '##ssh.pass##') {
        $user = '##ssh.user##'
        $pw = @'
##ssh.pass##
'@
    } ElseIf ('##config.user##' -and '##config.pass##') {
        $user = '##config.user##'
        $pw = @'
##config.pass##
'@
    }

    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($user, ($pw | ConvertTo-SecureString -AsPlainText -Force))
    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue
    #endregion Creds

    $exitCode = 0
    $enabled = $false
    $returnedState = $false
    $regex = '(?<=\=)(.*?)(?=\/)'
    $vdoms = [System.Collections.Generic.List[PSObject]]::new()

    $port = "##ssh.port##"
    If ($port -as [int]) {
        # No change, use the value from LM.
    } Else {
        $port = 22
    }
    #endregion Initialize variables

    #region Logging
    If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\propsource-get_fortigateproperty-$computerName.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile
    #endregion Setup

    #region Main
    #region Initial connection
    $message = ("{0}: Attempting to establish an SSH session to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
    $message | Out-File -FilePath $logFile -Append

    Try {
        $session = New-SSHSession -ComputerName $computerName -Credential $credential -Port $port -ConnectionTimeout 120 -ErrorAction Stop -Force -WarningAction SilentlyContinue
    } Catch {
        If ($_.Exception.Message -match 'Key exchange negotiation failed') {
            $message = ("{0}: SSH failed due to key exchange negotiation failure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
        } Else {
            $message = ("{0}: Unexpected error establishing an SSH session to {1}. The error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append

            Write-Host ('fortinet.sslvpn_enabled=Unknown')
            Write-Host ('fortinet.fgfmInterfaceCount=Unknown')
            Write-Host ('fortinet.vdomlist=unknown')
            Write-Host ('fortinet.vdomlistError=SSH error')

            Exit 1
        }
    }

    If ($session) {
        $message = ("{0}: SSH session established." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: Unable to establish the SSH session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Write-Host ('fortinet.sslvpn_enabled=Unknown')
        Write-Host ('fortinet.fgfmInterfaceCount=Unknown')
        Write-Host ("fortinet.vdomlist=unknown")
        Write-Host ("fortinet.vdomlistError=Other SSH failure")

        Exit 1
    }
    #endregion Initial connection

    #region Create SSHShellStream
    $message = ("{0}: Creating SSH shell stream." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

    $stream = New-SSHShellStream -Index 0
    #endregion Create SSHShellStream

    #region Check for vdoms
    #region Check system status
    $message = ("{0}: Sending 'get system status'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

    $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "get system status | grep Virtual.domain.configuration"

    $message = ("{0}: The value in `$response (if present) is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append
    #endregion Check system status

    If ($response -match 'disable') {
        $message = ("{0}: No VDOMs configured." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist=disabled")
    } ElseIf ($response) {
        #region Get VDOM list
        $message = ("{0}: Sending 'config global' and 'diagnose sys vd list | grep name='." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        $configGlobalResponse = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "config global" -PrompPattern "(global)"

        If ($configGlobalResponse -match 'Unknown action 0') {
            $message = ("{0}: so sad" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($configGlobalResponse | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append
        } Else {
            $message = ("{0}: 'config global' returned: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($configGlobalResponse | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append
        }

        $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "diagnose sys vd list | grep name="

        If ($response) {
            $message = ("{0}: The diagnose command returned: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append

            Foreach ($item in $response) {
                $vdoms.Add($([regex]::matches($item, $regex).value | Where-Object { $_ -notmatch '^vsys' }))
            }

            #region Return vdom list
            $message = ("{0}: Returning vdom list: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($vdoms | Select-Object -Unique) -join ',')); $message | Out-File -FilePath $logFile -Append
            Write-Host ("fortinet.vdomlist={0}" -f (($vdoms | Select-Object -Unique) -join ','))
            #endregion Return vdom list

            $message = ("{0}: Exiting config global." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
            $null = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "end"
        } Else {
            $message = ("{0}: No VDOMs retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

            Write-Host ("fortinet.vdomlist=unknown")
            Write-Host ("fortinet.vdomlistError=Diagnose sys vd command fail")
        }
        #endregion Get VDOM list
    } Else {
        $message = ("{0}: No response to the 'get system status' command." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Write-Host ("fortinet.vdomlist=unknown")
        Write-Host ("fortinet.vdomlistError=Get system status command fail")
    }
    #endregion Check for vdoms

    If (($vdoms) -and ($vdoms -ne 'disabled')) {
        #region VPN prop
        #region Enter vdom config
        $message = ("{0}: Sending 'config vdom'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        $null = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "config vdom"
        #endregion Enter vdom config

        Foreach ($vdom in ($vdoms | Where-Object { $_.Length -ge 1 })) {
            #region Send edit <vdom>
            $message = ("{0}: Sending 'edit {1}'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $vdom); $message | Out-File -FilePath $logFile -Append

            Try {
                $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "edit $vdom" -ErrorAction Stop
            } Catch {
                If ($_.Exception.Message -match 'Cannot access a disposed object') {
                    $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
                } Else {
                    $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append
                }

                Write-Host ('fortinet.sslvpn_enabled=Unknown')
                Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

                Return 1
            }
            #endregion Send edit <vdom>

            #region Send show vpn ssl settings
            $message = ("{0}: Sending 'show full-configuration vpn ssl settings...'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

            Try {
                $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show full-configuration vpn ssl settings | grep '.*\(\(status\)\|\(source-interface\)\).*'" -ErrorAction Stop
            } Catch {
                If ($_.Exception.Message -match 'Cannot access a disposed object') {
                    $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
                } Else {
                    $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append
                }

                Write-Host ('fortinet.sslvpn_enabled=Unknown')
                Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

                Return 1
            }
            #endregion Send show vpn ssl settings

            If (($response) -and ($response.Length -gt 1)) {
                $message = ("{0}: Parsing response ({1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String).Trim()); $message | Out-File -FilePath $logFile -Append

                If (($response -match 'set status enable') -and ($response -match 'set source-interface')) {
                    $message = ("{0}: Found SSL VPN enabled." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

                    $enabled = $true
                    $returnedState = $true
                }

                If ($enabled -eq $true) {
                    $message = ("{0}: Returning property and breaking loop." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

                    Write-Host ('fortinet.sslvpn_enabled={0}' -f $enabled)

                    Continue
                }
            } ElseIf (($response) -and ($response.Length -eq 1)) {
                $message = ("{0}: A blank response was received, indicating the default configuration (disabled) is in place." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: No recorded response to the 'show full-configuration vpn ssl settings...' command. This is an unexpected condition, but the script will attempt to continue." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
            }

            #region Send next
            $message = ("{0}: Sending 'next'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

            Try {
                $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "next" -ErrorAction Stop
            } Catch {
                If ($_.Exception.Message -match 'Cannot access a disposed object') {
                    $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
                } Else {
                    $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append
                }

                Write-Host ('fortinet.sslvpn_enabled=Unknown')
                Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

                Return 1
            }
            #endregion Send next
        }

        #region End vdom config
        $message = ("{0}: Sending 'end'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Invoke-SSHStreamShellCommand -ShellStream $stream -Command "end"
        #endregion End vdom config

        If ($returnedState -eq $false) {
            # SSL VPN must be disabled.
            Write-Host ('fortinet.sslvpn_enabled={0}' -f $enabled)
        }
        #endregion VPN prop

        #region fgfm
        #region Enter global
        $message = ("{0}: Sending 'config global'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        $null = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "config global"
        #endregion Enter global

        #region Show system central mgmt
        $message = ("{0}: Sending 'show system central-management | grep set.fmg'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Try {
            $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show system central-management | grep set.fmg" -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match 'Cannot access a disposed object') {
                $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); $message | Out-File -FilePath $logFile -Append
            }

            Write-Host ('fortinet.fortimanagerIp=Unknown')
            Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

            Return 1
        }

        If ($response -match 'set fmg') {
            Write-Host ('fortinet.fortimanagerIp={0}' -f $([regex]::Match($response, '\d+\.\d+\.\d+\.\d+').Value))
        } Else {
            Write-Host ('fortinet.fortimanagerIp=None')
        }
        #endregion Show system central mgmt

        #region Show interface
        $message = ("{0}: Sending 'show system interface | grep -f fgfm'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $logFile -Append

        Try {
            $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show system interface | grep -f fgfm" -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match 'Cannot access a disposed object') {
                $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                $message | Out-File -FilePath $logFile -Append
            }

            Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

            Return 1
        }

        Write-Host ('fortinet.fgfmInterfaceCount={0}' -f $($response | Where-Object { $_ -match 'fgfm' }).count)
        <#
        This block is commented-out until we can figure out how to parse "show system interface | grep -f fgfm". Per Jeff Sailers, sometimes the edit...next blocks (representing an interface) have a nested edit...next block.
        If we can figure out how to correctly identify the outer edit...next blocks, then we can return the interface names, IPs, and statuses instead of just the count of interfaces with 'fgfm'.
        If ($response -match 'set ip') {
            $result = @()
            For ($i = 0; $i -lt $response.Count; $i++) {
                If ($response[$i] -match '\s+edit "(.+)"') {
                    $interfaceName = $matches[1]
                    # Iterate through lines within the block until 'next' is encountered
                    For ($j = $i + 1; $j -lt $response.Count; $j++) {
                        If ($response[$j] -eq 'next') {
                            Break
                        }
                        If ($response[$j] -match '\s+set ip (\d+\.\d+\.\d+\.\d+)') {
                            $ip = $matches[1]
                            $result += [PSCustomObject]@{
                                InterfaceName = $interfaceName
                                IP            = $ip
                            }
                            Break
                        }
                    }
                }
            }

            Write-Host ('fortinet.fgfmInterfaces={0}' -f (($result | ForEach-Object { $_.InterfaceName + ":" + $_.IP + ":" + $_.Status }) -join ","))
            Write-Host ('fortinet.fgfmInterfaceCount={0}' -f $($response | Where {$_ -match 'fgfm'}).count)
        } Else {
            Write-Host ('fortinet.fgfmInterfaces=None')
            Write-Host ('fortinet.fgfmInterfaceCount=0')
        }#>
        #endregion Show interface

        #region End global config
        $message = ("{0}: Sending 'end'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Invoke-SSHStreamShellCommand -ShellStream $stream -Command "end"
        #endregion End global config
        #endregion fgfm
    } Else {
        #region VPN prop
        #region Send show vpn ssl settings
        $message = ("{0}: Sending 'show full-configuration vpn ssl settings...'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Try {
            $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show full-configuration vpn ssl settings | grep '.*\(\(status\)\|\(source-interface\)\).*'" -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match 'Cannot access a disposed object') {
                $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                $message | Out-File -FilePath $logFile -Append
            }

            Write-Host ('fortinet.sslvpn_enabled=Unknown')

            Return 1
        }
        #endregion Send show vpn ssl settings

        If (($response) -and ($response.Length -gt 1)) {
            $message = ("{0}: Parsing response ({1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String).Trim())
            $message | Out-File -FilePath $logFile -Append

            If (($response -match 'set status enable') -and ($response -match 'set source-interface')) {
                $message = ("{0}: Found SSL VPN enabled." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append

                $enabled = $true

                If ($enabled -eq $true) {
                    $message = ("{0}: Returning property and breaking loop." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    $message | Out-File -FilePath $logFile -Append

                    $returnedState = $true
                    Write-Host ('fortinet.sslvpn_enabled={0}' -f $enabled)
                }
            }
        } ElseIf (($response) -and ($response.Length -eq 1)) {
            $message = ("{0}: A blank response was received, indicating the default configuration (disabled) is in place." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $returnedState = $true
            Write-Host ('fortinet.sslvpn_enabled={0}' -f $enabled)
        } Else {
            $message = ("{0}: No recorded response to the 'show full-configuration vpn ssl settings...' command. This is an unexpected condition, but the script will attempt to continue." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $returnedState = $true
            Write-Host ('fortinet.sslvpn_enabled=Unknown')
        }

        If ($returnedState -eq $false) {
            # SSL VPN must be disabled.
            Write-Host ('fortinet.sslvpn_enabled={0}' -f $enabled)
        }
        #endregion VPN prop

        #region fgfm
        #region Show system central mgmt
        $message = ("{0}: Sending 'show system central-management | grep set.fmg'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Try {
            $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show system central-management | grep set.fmg" -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match 'Cannot access a disposed object') {
                $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                $message | Out-File -FilePath $logFile -Append
            }

            Write-Host ('fortinet.fortimanagerIp=Unknown')

            Return 1
        }

        If ($response -match 'set fmg') {
            Write-Host ('fortinet.fortimanagerIp={0}' -f $([regex]::Match($response, '\d+\.\d+\.\d+\.\d+').Value))
        } Else {
            Write-Host ('fortinet.fortimanagerIp=None')
        }
        #endregion Show system central mgmt

        #region Show interface
        $message = ("{0}: Sending 'show system interface | grep -f fgfm'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append

        Try {
            $response = Invoke-SSHStreamShellCommand -ShellStream $stream -Command "show system interface | grep -f fgfm" -ErrorAction Stop
        } Catch {
            If ($_.Exception.Message -match 'Cannot access a disposed object') {
                $message = ("{0}: The session was terminated before the command was run." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Unexpected error, {1} will exit. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                $message | Out-File -FilePath $logFile -Append
            }

            Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

            Return 1
        }

        Write-Host ('fortinet.fgfmInterfaceCount={0}' -f $($response | Where-Object { $_ -match 'fgfm' }).count)
        <#
        This block is commented-out until we can figure out how to parse the comment command above.
        If ($response -match 'set ip') {
            $result = @()
            For ($i = 0; $i -lt $response.Count; $i++) {
                If ($response[$i] -match '\s+edit "(.+)"') {
                    $interfaceName = $matches[1]
                    # Iterate through lines within the block until 'next' is encountered
                    For ($j = $i + 1; $j -lt $response.Count; $j++) {
                        If ($response[$j] -eq 'next') {
                            Break
                        }
                        If ($response[$j] -match '\s+set ip (\d+\.\d+\.\d+\.\d+)') {
                            $ip = $matches[1]
                            $result += [PSCustomObject]@{
                                InterfaceName = $interfaceName
                                IP            = $ip
                            }
                            Break
                        }
                    }
                }
            }

            Write-Host ('fortinet.fgfmInterfaces={0}' -f (($result | ForEach-Object { $_.InterfaceName + ":" + $_.IP + ":" + $_.Status }) -join ","))
            Write-Host ('fortinet.fgfmInterfaceCount={0}' -f $($response | Where {$_ -match 'fgfm'}).count)
        } Else {
            Write-Host ('fortinet.fgfmInterfaces=None')
            Write-Host ('fortinet.fgfmInterfaceCount=0')
        }#>
        #endregion Show interface
        #endregion fgfm
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

    Write-Host ('fortinet.sslvpn_enabled=Unknown')
    Write-Host ('fortinet.fgfmInterfaceCount=Unknown')

    Exit 1
}