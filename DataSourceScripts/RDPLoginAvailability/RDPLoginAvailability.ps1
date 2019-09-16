<#
    .DESCRIPTION
        Attempt to RDP to a system, then check the system for the list of logged in users. If the script's user is found, exit 0 otherwise exit 1.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 13 September 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/RDPLoginAvailability
#>
Function Connect-RDP {
    param (
        [Parameter(Mandatory = $true)]
        $ComputerName,

        [System.Management.Automation.Credential()]$Credential
    )

    # take each computername and process it individually
    $ComputerName | ForEach-Object {
        # If the user has submitted a credential, store it safely using cmdkey.exe for the given connection.
        If ($PSBoundParameters.ContainsKey('Credential')) {
            $User = $Credential.UserName
            $Password = $Credential.GetNetworkCredential().Password

            # save information using cmdkey.exe
            cmdkey.exe /generic:$_ /user:$User /pass:$Password
        }

        mstsc.exe /v $_ /f
    }
}

# Initialize variables.
$computerName = '##system.hostname##'
$username = '##rdp.user##'
#$password = 
$cred = New-Object System.Management.Automation.PSCredential ($username, $('##rdp.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-RDP_Login_Availability-collection-$computerName.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Checking if the AuthenticationLevelOverride registry value is present." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$rdpSecStatus = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client\').AuthenticationLevelOverride

If ($rdpSecStatus -and ($rdpSecStatus -eq 0)) {
    $message = ("{0}: Found AuthenticationLevelOverride present and with value '0'. No changes to make." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $startStatus = 'Found:0'
}
ElseIf ($rdpSecStatus -and ($rdpSecStatus -ne 0)) {
    $message = ("{0}: AuthenticationLevelOverride was not found with a value of {1}. Changing the registry value and recording that change, so we can return it later." -f [datetime]::Now, $rdpSecStatus)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $startStatus = ('Non-zero:{0}' -f $rdpSecStatus)

    $null = Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value 0
}
ElseIf (-NOT($rdpSecStatus)) {
    $message = ("{0}: AuthenticationLevelOverride not found. Adding the registry value and recording that change, so we can return it later." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $startStatus = 'Not present'

    $null = New-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value 0
}

$message = ("{0}: Attempting to RDP to {1}." -f [datetime]::Now, $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Connect-RDP -ComputerName $computerName -Credential $cred

$message = ("{0}: Waiting 30 seconds, for the login to complete." -f [datetime]::Now, $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Start-Sleep -Seconds 30

$message = ("{0}: Connecting to {1}, to retieve logged-in users." -f [datetime]::Now, $computerName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

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
            [string]$Name
            ,
            [switch]$Quiet
        )
        Begin {
            $return = @()
        }
        Process {
            If (!(Test-Connection $Name -Quiet -Count 1)) {
                Write-Error -Message "Unable to contact $Name. Please verify its network connectivity and try again." -Category ObjectNotFound -TargetObject $Name
                Return
            }
            If ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
                #check if user is admin, otherwise no registry work can be done
                #the following registry key is necessary to avoid the error 5 access is denied error
                $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
                $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
                $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype, $Name)
                $regKey = $LMRegKey.OpenSubKey($LMkey, $true)
                If ($regKey.GetValue("AllowRemoteRPC") -ne 1) {
                    $regKey.SetValue("AllowRemoteRPC", 1)
                    Start-Sleep -Seconds 1
                }
                $regKey.Dispose()
                $LMRegKey.Dispose()
            }
            $result = qwinsta /server:$Name
            If ($result) {
                ForEach ($line in $result[1..$result.count]) {
                    #avoiding the line 0, don't want the headers
                    $tmp = $line.split(" ") | ? { $_.length -gt 0 }
                    If (($line[19] -ne " ")) {
                        #username starts at char 19
                        If ($line[48] -eq "A") {
                            #means the session is active ("A" for active)
                            $return += New-Object PSObject -Property @{
                                "ComputerName" = $Name
                                "SessionName"  = $tmp[0]
                                "UserName"     = $tmp[1]
                                "ID"           = $tmp[2]
                                "State"        = $tmp[3]
                                "Type"         = $tmp[4]
                            }
                        }
                        Else {
                            $return += New-Object PSObject -Property @{
                                "ComputerName" = $Name
                                "SessionName"  = $null
                                "UserName"     = $tmp[0]
                                "ID"           = $tmp[1]
                                "State"        = $tmp[2]
                                "Type"         = $null
                            }
                        }
                    }
                }
            }
            Else {
                Write-Error "Unknown error, cannot retrieve logged on users"
            }
        }
        End {
            If ($return) {
                If ($Quiet) {
                    Return $true
                }
                Else {
                    Return $return
                }
            }
            Else {
                If (!($Quiet)) {
                    Write-Host "No active sessions."
                }
                Return $false
            }
        }
    }
    Function Close-ActiveSessions {
        <#
            .SYNOPSIS
                Closes the specified open sessions of a remote or local workstations
            .DESCRIPTION
                Close-ActiveSessions uses the command line tool rwinsta to close the specified open sessions on a computer whether they are RDP or logged on locally.
            .PARAMETER $Name
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
                [string]$Name
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
        Begin { }
        Process {
            If (!(Test-Connection $ComputerName -Quiet -Count 1)) {
                Write-Error -Message "Unable to contact $ComputerName. Please verify its network connectivity and try again." -Category ObjectNotFound -TargetObject $ComputerName
                Return
            }
            If ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
                #check if user is admin, otherwise no registry work can be done
                #the following registry key is necessary to avoid the error 5 access is denied error
                $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
                $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
                $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype, $Name)
                $regKey = $LMRegKey.OpenSubKey($LMkey, $true)
                If ($regKey.GetValue("AllowRemoteRPC") -ne 1) {
                    $regKey.SetValue("AllowRemoteRPC", 1)
                    Start-Sleep -Seconds 1
                }
                $regKey.Dispose()
                $LMRegKey.Dispose()
            }
            rwinsta.exe /server:$ComputerName $ID /V
        }
        End { }
    }

    $message = ("{0}: Getting active RDP sessions on {1}." -f [datetime]::Now, $ComputerName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $sessions = Get-ActiveSessions -Name $ComputerName

    $message = ("{0}: Checking if {1} is logged in." -f [datetime]::Now, $UserName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    If ($sessions.UserName -match $UserName) {
        $message = ("{0}: Found {1} logged in. The session ID is {2}." -f [datetime]::Now, $UserName, ($sessions | Where-Object { $_.UserName -match $UserName }).Id)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Close-ActiveSessions -ComputerName $ComputerName -Id ($sessions | Where-Object { $_.UserName -match $UserName }).Id
    }
} -ArgumentList $computerName, $username

$message = ("{0}: If necessary, returning the registry to its previous state." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

If ($startStatus -eq 'Found:0') {
    $message = ("{0}: No registry changes to revert." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
}
ElseIf ($startStatus -match 'Non-zero') {
    $message = ("{0}: Changing the value of AuthenticationLevelOverride back to {1}." -f [datetime]::Now, $startStatus.Split(':')[-1])
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Try {
        $null = Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -PropertyType DWORD -Value $($startStatus.Split(':')[-1])
    }
    Catch {
        $message = ("{0}: Unable to reset the AuthenticationLevelOverride registry value. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
    }
}
ElseIf ($startStatus -eq 'Not present') {
    $message = ("{0}: AuthenticationLevelOverride from the registry." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Try {
        $null = Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name AuthenticationLevelOverride -Force
    }
    Catch {
        $message = ("{0}: Unable to remove the AuthenticationLevelOverride registry value. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
    }
}

If ($response -match 'Resetting session ID') {
    $message = ("{0}: Found login to {1} successful." -f [datetime]::Now, $computerName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 0
}
Else {
    $message = ("{0}: Found login to {1} unsuccessful." -f [datetime]::Now, $computerName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}