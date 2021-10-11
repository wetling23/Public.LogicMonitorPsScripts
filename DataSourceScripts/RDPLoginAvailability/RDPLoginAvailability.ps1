<#
    .DESCRIPTION
        Attempt to RDP to a system, then check the system for the list of logged in users. If the script's user is found, exit 0 otherwise exit 1.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 13 September 2019
            - Initial release
        V1.0.0.1 date: 9 October 2019
        V1.0.0.2 date: 4 October 2020
        V1.0.0.3 date: 6 October 2020
        V1.0.0.4 date: 11 October 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/RDPLoginAvailability
#>

#region Setup
Function Connect-RDP {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [pscredential]$Credential
    )

    # Store the credential using cmdkey.exe for the given connection.
    If ($PSBoundParameters.ContainsKey('Credential')) {
        $User = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password

        # save information using cmdkey.exe
        $null = cmdkey.exe /generic:TERMSRV/$ComputerName /user:$User /pass:$Password
    }

    mstsc.exe /v $ComputerName /f
}

# Initialize variables.
$rdpSecStatus = 15
$computerName = '##system.hostname##'
$username = '##wmi.user##'
$pass = @'
##wmi.pass##
'@
$cred = New-Object System.Management.Automation.PSCredential ($username, $($pass | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-RDP_Login_Availability-collection-$computerName.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$message = ("{0}: Checking TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

# If necessary, update TrustedHosts.
If (-NOT(($computerName -eq $env:ComputerName) -or ($computerName -eq "127.0.0.1"))) {
    If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $computerName) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $computerName -Concatenate -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }
    Else {
        $message = ("{0}: {1} is already in TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
}
#endregion Setup

#region Local testing
$message = ("{0}: Checking if the HKCU:\Software\Microsoft\Terminal Server Client path is present." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

If (Test-Path -Path 'HKCU:\Software\Microsoft\Terminal Server Client') {
    $message = ("{0}: Found path, checking AuthenticationLevelOverride value." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $rdpSecStatus = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client\' -ErrorAction SilentlyContinue).AuthenticationLevelOverride
}
Else {
    $message = ("{0}: Path not found, creating it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    New-Item -Path 'HKCU:\Software\Microsoft\Terminal Server Client\'
}

If ($rdpSecStatus -eq 0) {
    $message = ("{0}: Found AuthenticationLevelOverride present and with value '0'. No changes to make." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $startStatus = 'Found:0'
}
ElseIf (($rdpSecStatus -ne 15) -and ($rdpSecStatus -ne 0)) {
    $message = ("{0}: AuthenticationLevelOverride was not found with a value of {1}. Changing the registry value and recording that change, so we can return it later." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $rdpSecStatus)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $startStatus = ('Non-zero:{0}' -f $rdpSecStatus)

    $null = Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value 0
}
ElseIf (-NOT($rdpSecStatus) -or $rdpSecStatus -eq 15) {
    $message = ("{0}: AuthenticationLevelOverride not found. Adding the registry value and recording that change, so we can return it later." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $startStatus = 'Not present'

    $null = New-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value 0 -ErrorAction SilentlyContinue
}
#endregion Local testing

#region Remote testing
$message = ("{0}: Attempting to RDP to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Connect-RDP -ComputerName $computerName -Credential $cred

$message = ("{0}: Waiting 30 seconds, for the login to complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Start-Sleep -Seconds 30

$message = ("{0}: Connecting to {1}, with Invoke-Command, to retieve logged-in users." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $response = Invoke-Command -ComputerName $computerName -Credential $cred -ScriptBlock {
        param (
            $ComputerName,
            $UserName
        )

        Function Get-ActiveSessions {
            Param(
                [Parameter(
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true
                )]
                [ValidateNotNullOrEmpty()]
                [string]$ComputerName,

                [switch]$Quiet
            )
            Begin {
                $return = @()
                $remoteMessage += ("{0}: Beginning {1}.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.$MyInvocation.MyCommand)
            }
            Process {
                If (-NOT(Test-Connection $ComputerName -Quiet -Count 1)) {
                    $remoteMessage += ("{0}: Unable to contact $ComputerName. Please verify its network connectivity and try again.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))

                    "Error"
                }
                If ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
                    #check if user is admin, otherwise no registry work can be done
                    $remoteMessage += ("{0}: Verified that we are running as an admin.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))

                    #the following registry key is necessary to avoid the error 5 access is denied error
                    $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
                    $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
                    $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype, $ComputerName)
                    $regKey = $LMRegKey.OpenSubKey($LMkey, $true)
                    If ($regKey.GetValue("AllowRemoteRPC") -ne 1) {
                        $regKey.SetValue("AllowRemoteRPC", 1)
                        Start-Sleep -Seconds 1
                    }
                    $regKey.Dispose()
                    $LMRegKey.Dispose()
                } Else {
                    $remoteMessage += ("{0}: Verified that we are not running as an admin.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                }

                $remoteMessage += ("{0}: Running qwinsta against {1}.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)

                $result = qwinsta /server:$ComputerName

                If ($result) {
                    $remoteMessage += ("{0}: Found sessions, parsing the result.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))

                    Foreach ($line in $result[1..$result.count]) {
                        #avoiding line 0, don't want the headers
                        $tmp = $line.split(" ") | Where-Object { $_.length -gt 0 }
                        If (($line[19] -ne " ")) {

                            #username starts at char 19
                            If ($line[48] -eq "A") {
                                #means the session is active ("A" for active)
                                $return += New-Object PSObject -Property @{
                                    "ComputerName" = $ComputerName
                                    "SessionName"  = $tmp[0]
                                    "UserName"     = $tmp[1]
                                    "ID"           = $tmp[2]
                                    "State"        = $tmp[3]
                                    "Type"         = $tmp[4]
                                }
                            } Else {
                                $return += New-Object PSObject -Property @{
                                    "ComputerName" = $ComputerName
                                    "SessionName"  = $null
                                    "UserName"     = $tmp[0]
                                    "ID"           = $tmp[1]
                                    "State"        = $tmp[2]
                                    "Type"         = $null
                                }
                            }
                        }
                    }

                    $result
                } Else {
                    $remoteMessage += ("{0}: Unknown error, cannot retrieve logged on users.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                }
            }
            End {
                If ($return) {
                    If ($Quiet) {
                        $true
                    } Else {
                        $return
                    }
                } Else {
                    If (!($Quiet)) {
                        $remoteMessage += "{0}: No active sessions.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")
                    }
                    $false
                }
            }
        }
        Function Close-ActiveSessions {
            <#
        .SYNOPSIS
            Closes the specified open sessions of a remote or local workstations
        .DESCRIPTION
            Close-ActiveSessions uses the command line tool rwinsta to close the specified open sessions on a computer whether they are RDP or logged on locally.
        .PARAMETER $ComputerName
            The name of the computer that you would like to close the active sessions on.
        .PARAMETER ID
            The ID number of the session to be closed.
        .EXAMPLE
            Close-ActiveSessions -ComputerName PC1 -ID 1

            Closes the session with ID of 1 on PC1
        .EXAMPLE
            Get-ActiveSessions DC01 | ?{$_.State -ne "Active"} | Close-ActiveSessions

            Closes all sessions that are not active on DC01
        .INPUTS
            [string]$ComputerName
            [int]ID
        .OUTPUTS
            Progress of the rwinsta command.
        .NOTES
            Author: Anthony Howell
        .LINK
            rwinsta
            http://stackoverflow.com/questions/22155943/qwinsta-error-5-access-is-denied
            https://theposhwolf.com
    #>
            Param(
                [Parameter(
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    Position = 1
                )]
                [string]$ComputerName,

                [Parameter(
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    Position = 2
                )]
                [int]$ID
            )
            Begin {
                $remoteMessage += ("{0}: Beginning {1}.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.$MyInvocation.MyCommand)
            }
            Process {
                If (-NOT(Test-Connection $ComputerName -Quiet -Count 1)) {
                    $remoteMessage += ("{0}: Unable to contact {1}. Please verify its network connectivity and try again.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)

                    "Error"
                }
                If ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
                    #check if user is admin, otherwise no registry work can be done
                    #the following registry key is necessary to avoid the error 5 access is denied error
                    $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
                    $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
                    $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype, $ComputerName)
                    $regKey = $LMRegKey.OpenSubKey($LMkey, $true)
                    If ($regKey.GetValue("AllowRemoteRPC") -ne 1) {
                        $regKey.SetValue("AllowRemoteRPC", 1)
                        Start-Sleep -Seconds 1
                    }
                    $regKey.Dispose()
                    $LMRegKey.Dispose()
                }

                $remoteMessage += ("{0}: Running rwinsta to log off the user with session ID {1}.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ID)

                $remoteMessage += rwinsta.exe /server:$ComputerName $ID /V
            }
            End { }
        }

        $remoteMessage = @"
{0}: Connected to {1}, getting active RDP sessions. Checking for {2}.`r`n
"@ -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName, $UserName

        Try {
            $sessions = Get-ActiveSessions -ComputerName $ComputerName

            If ($sessions.UserName) {
                $remoteMessage += ("{0}: Found {1} sessions. Checking if {2} is logged in.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $sessions.Count, $UserName)

                Foreach ($session in $sessions) {
                    If ($session.UserName -eq $UserName.Split('\')[-1]) {
                        $remoteMessage += ("{0}: Found {1} logged in. The session ID is {2}. Calling Close-ActiveSessions.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $UserName, $session.Id)

                        $closeResponse = Close-ActiveSessions -ComputerName $ComputerName -Id $session.Id

                        If ($closeResponse -eq "Error") {
                            $status = 2
                        } Else {
                            $status = 0
                        }

                        Return @($status, $remoteMessage)
                    }
                }
            } ElseIf ($sessions -eq "Error") {
                $status = 1
            }

            If (-NOT($status) -or -NOT($sessions.UserName)) {
                $remoteMessage += ("{0}: No sessions matching {1} found. Disconnecting from {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $UserName, $ComputerName)

                $status = 3
            }

            Return @($status, $remoteMessage)
        } Catch {
            $remoteMessage += ("{0}: Unexpected error in the Invoke-Command block. The error occurred at line {1}, the command was `"{2}`", and the specific error is: {3}" -f [datetime]::Now, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)

            Return @(4, $remoteMessage)
        }

    } -ArgumentList $computerName, $username -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error connecting to {1} with Invoke-Command. Error: {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append
}
#endregion Remote testing

If ($response -is [system.array]) {
    # Adding response to the DataSource log.
    Write-Host $response[1]; $response[1] | Out-File -FilePath $logFile -Append

    $message = ("{0}: If necessary, returning the registry to its previous state." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    If ($startStatus -eq 'Found:0') {
        $message = ("{0}: No registry changes to revert." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
    ElseIf ($startStatus -match 'Non-zero') {
        $message = ("{0}: Changing the value of AuthenticationLevelOverride back to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $startStatus.Split(':')[-1])
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            $null = Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value $($startStatus.Split(':')[-1])
        }
        Catch {
            $message = ("{0}: Unable to reset the AuthenticationLevelOverride registry value. The specific error is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
        }
    }
    ElseIf ($startStatus -eq 'Not present') {
        $message = ("{0}: Attempting to remove AuthenticationLevelOverride from the registry." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            $null = Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -Force
        }
        Catch {
            $message = ("{0}: Unable to remove the AuthenticationLevelOverride registry value. The specific error is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
        }
    }

    $message = ("{0}: The value of `$response is {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($response | Out-String))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    If ($response[0] -eq 0) {
        $message = ("{0}: Found login to {1} successful." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 0
    }
    Else {
        $message = ("{0}: Login to {1} was unsuccessful." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Else {
    $message = ("{0}: No/partial response. To prevent errors, {1} will exit. The value of `$response is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($response | Out-String))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}