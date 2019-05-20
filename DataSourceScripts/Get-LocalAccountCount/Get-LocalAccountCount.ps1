Function Get-LocalAccountCount {
    <#
        .DESCRIPTION
            Query WMI for local users and return a count. Exclude desired accounts using a WQL filter.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 20 May 2019
                - Initial release
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-LocalAccountCount
        .PARAMETER ComputerName
            Hostname or IP address of the target Windows device.
        .PARAMETER Credential
            PowerShell credential object used to connect, when querying remote Widnows devices.
        .PARAMETER Filter
            Windows Management Instrumentation Query Language filter, to be used against the Win32_UserAccount class. If not provided, "*" is assumed.
        .PARAMETER LogFile
            Path and file name, to which the command will send output logs.
        .EXAMPLE
            PS C:\> Get-LocalAccountCount -ComputerName 127.0.0.1 -Filter "LocalAccount = "true" AND NOT disabled = "true" AND NOT Name = "guest"" -LogFile C:\temp\log.log

            In this example, the command queries the local host for local accounts that are enabled and are not named "guest". The logged output is stored in C:\temp\log.log
        .EXAMPLE
            PS C:\> Get-LocalAccountCount -ComputerName server1 -Credential (Get-Credential) -LogFile C:\temp\.log.log

            In this example, the command queries server1, using the provided credential, for all accounts. The logged output is stored in C:\temp\log.log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [PSCredential]$Credential,

        [string]$Filter,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    If ($null -eq $filter) {
        $filter = '*'
    }

    If (($ComputerName -eq $env:ComputerName) -or ($ComputerName -eq "127.0.0.1")) {
        $message = ("{0}: Operating locally." -f [datetime]::Now)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Try {
            $users = [System.Collections.Generic.List[String]]@(
                Get-CimInstance -ClassName Win32_UserAccount -Filter $Filter
            )
        }
        Catch {
            Else {
                $message = ("{0}: Unexpected error retrieving users from the local machine. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
                Write-Error $message; $message | Out-File -FilePath $logFile -Append

                $users = "Error"
            }
        }
    }
    Else {
        $message = ("{0}: Operating remotely." -f [datetime]::Now)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        $users = [System.Collections.Generic.List[String]]@(
            Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                param (
                    $Filter
                )

                Try {
                    Get-CimInstance -ClassName Win32_UserAccount -Filter $Filter -ErrorAction Stop
                }
                Catch {
                    Else {
                        $message = ("{0}: Unexpected error retrieving users from the local machine. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
                        Write-Error $message; $message | Out-File -FilePath $logFile -Append

                        $users = ("Error: {0}" -f $_.Exception.Message)

                        $users
                    }
                }
            } -ArgumentList $Filter -ErrorAction Stop
        )
    }

    If (($null -eq $users) -or ($users.count -eq 0)) {
        Return 0
    }
    Else {
        $users
    }
}

# Initialize variables.
$computerName = "##HOSTNAME##" # Target host for the script to query.

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Local_Account_Count-collection-$computerName.log"

$ignoredAccounts = [System.Collections.Generic.List[String]]@(((("##custom.IgnoredLocalAccts##").Split(',')).Replace("`"", ""))).Replace("'", "") # List of local accounts to ignore, when counting local accounts.
$filter = "LocalAccount = `"true`" AND NOT disabled = `"true`" AND " # Beginning of the WQL filter. Counts only local, enabled accounts.
$regex = "AND $" # Regex to help trim off trailing "AND" from $filter.

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

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Constructing WQL filter." -f [datetime]::Now)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Foreach ($account in $ignoredAccounts) {
    $filter += "NOT Name = `"$account`" AND "
}
$filter = (($filter -split $regex)[0]).Replace("= `" ", "= `"") # Remove the trailing space character, if there is one after each equal/quote pair (= ").

$message = ("{0}: Using filter: {1}." -f [datetime]::Now, $filter)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

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

$message = ("{0}: Calling Get-LocalAccountCount." -f [datetime]::Now, $filter)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$users = Get-LocalAccountCount -ComputerName $computerName -Credential $cred -Filter $filter -LogFile $logFile

Switch ($users) {
    { $_ -eq "Error" } {
        $message = ("{0}: Returning error. See the log file at: {1}." -f [datetime]::Now, $logFile)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
    { $_ -ne 0 } {
        $message = ("{0}: Returning {1} users ({2})." -f [datetime]::Now, $_.Count, ($_ -join ', '))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("LocalAcctCount={0}" -f $_.Count)

        Exit 0
    }
    { ($_ -eq 0) } {
        $message = ("{0}: No unexpected users found." -f [datetime]::Now)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("LocalAcctCount=0")

        Exit 0
    }
}