<#
    .DESCRIPTION
        Accepts a user name and returns the password age.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 22 October 2019
            - Initial release.
        V1.0.0.1 date: 5 May 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-UserAccountPasswordAge
    .PARAMETER Username
        Username, for the user to query.
    .EXAMPLE
        PS C:> Get-UserAccountPasswordAge-Collection.ps1 -Username jdoe

        In this example, the script returns the password age for John Doe (jdoe).
#>
[CmdletBinding()]
param (
    [string]$Username,

    [string]$TargetComputer,

    [System.Management.Automation.PSCredential]$Credential
)

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get_UserAccountPasswordAge-collection.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

#region Setup
# Initialize variables.
$password = @'
##wmi.pass##
'@
If (-NOT($Username)) {
    $message = ("{0}: No username provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $Username = "##wildalias##"
}
If (-NOT($TargetComputer)) {
    $message = ("{0}: No target computer provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $TargetComputer = '##system.hostname##'
}
If (('##system.collector##' -eq "true") -and (-NOT $Credential)) {
    $message = ("{0}: Running on a collector device, no credential required." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
}
Else {
    $message = ("{0}: No credential provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $Credential = New-Object System.Management.Automation.PSCredential ('##wmi.user##', (ConvertTo-SecureString -String $password -AsPlainText -Force))
}
#endregion Setup

If ('##system.domain##' -eq 'workgroup') {
    $message = ("{0}: It appears that {1} is a local user." -f [datetime]::Now, $Username)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Try {
        $localAccount = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" -Filter "LocalAccount='$True'" -ErrorAction Stop | Where-Object { $_.name -eq $Username }
        $user = ([adsi]"WinNT://$($env:COMPUTERNAME)/$($localAccount.Name),user")
        $userInfo = [PSCustomObject]@{
            DisplayName       = $($user.FullName)
            DistinguishedName = $($user.Name)
            PwdAge            = [math]::Round($user.PasswordAge.Value / 86400)
            PasswordLastSet   = $(Get-Date).AddSeconds( - $($user.PasswordAge.Value))
        }

        $userInfo
        Write-Host ("PasswordAge={0}" -f $userInfo.PwdAge)

        Exit 0
    }
    Catch {
        $message = ("{0}: Unexpected error getting properties of local user ({1}). The specific error is: {2}." -f [datetime]::Now, $Username, $_.Exception.Message)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Else {
    $message = ("{0}: It appears that {1} is a domain user. Attempting to connect to {2}." -f [datetime]::Now, $Username, $TargetComputer)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $userInfo = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
        param(
            $Username,
            $Server
        )

        Try {
            Import-Module -Name ActiveDirectory -ErrorAction Stop
        }
        Catch {
            ("{0}: Error importing ActiveDiretory PowerShell module. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)

            Return
        }

        Try {
            Get-ADUser -Identity $Username -Properties DisplayName, PwdLastSet, PasswordLastSet -Server $Server -ErrorAction Stop | Select-Object DisplayName, DistinguishedName, PasswordLastSet, @{Name = "PwdLastSet"; Expression = { [datetime]::FromFileTime($_.PwdLastSet) } }, @{Name = "PwdAge"; Expression = { if ($_.PwdLastSet -ne 0) { (new-TimeSpan([datetime]::FromFileTimeUTC($_.PwdLastSet)) $(Get-Date)).days }else { 0 } } } | Where-Object { $_.PasswordLastSet }
        }
        Catch {
            ("{0}: Error getting user info for {1}. The specific error is: {2}" -f [datetime]::Now, $Username, $_.Exception.Message)

            Return
        }
    } -ArgumentList $Username, $TargetComputer

    If ($userInfo -as [system.array]) {
        $userInfo = $userInfo | Sort-Object -Descending -Property PwdAge | Select-Object -First 1
    }

    If ($userInfo -match 'Error\s+') {
        $message = ("{0}: Unexpected error getting properties of domain user ({1}). The specific error is: {2}." -f [datetime]::Now, $Username, $userInfo)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
    Else {
        $userInfo
        Write-Host ("PasswordAge={0}" -f $userInfo.PwdAge)

        Exit 0
    }
}