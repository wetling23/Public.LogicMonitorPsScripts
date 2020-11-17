<#
    .DESCRIPTION
        Connect to a remote server and return the content of C:\Windows\System32\adConfig.json
    .NOTES
        Author: Mike Hashemi
        V1.0.0.1 date: 29 October 2020
        V1.0.0.2 date: 17 November 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/ActiveDirectory/AdProperties
#>
[cmdletbinding()]
param()
Function Get-JsonFile {
    <#
        .DESCRIPTION
            When used in conjuction with New-AdPropertiesJson, this script returns the contents of the resulting .json file.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 21 March 2019
                - Initial release.
            V1.0.0.1 date: 19 October 2020
        .LINK
            https://github.com/wetling23/Public.LogicMonitorPsScripts/blob/master/ConfigSourceScripts/ActiveDirectory/AdProperties/Get-AdPropertiesJson.ps1
        .PARAMETER DcFqdn
            Fully qualified domain name for a target domain controller. If not specified, the script will take the hostname (if $OnDomainController == $true) or will prompt the user for a server name.
        .PARAMETER Credential
            Domain admin credential. If the script is run manually and not on a domain controller, the user is prompted to provide a username and password.
        .EXAMPLE
            PS C:\Get-JsonFile.ps1 -DcFqdn server.domain.local -Credential (Get-Credential) -Verbose

            In this example, the script is run manually and a credential is provided by the user. Output is sent to the host session and to the log file.
        .EXAMPLE
            PS C:\Get-JsonFile.ps1

            In this example, the script is run manually. The user will be prompted to provide a hostname (if the script is not run from a DC) and a credential is provided by the user. Output is sent only to the log file.
    #>
    [CmdletBinding()]
    param (
        [string]$DcFqdn,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$LogFile
    )

    $message = ("{0}: Checking TrustedHosts file." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    # Add the target device to TrustedHosts.
    If (($DcFqdn -notmatch (Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($DcFqdn -ne "127.0.0.1")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hostDcFqdnname)
        $message | Out-File -FilePath $logFile -Append

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $DcFqdn -Concatenate -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }

    $message = ("{0}: Checking for the adConfig file on {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DcFqdn)
    $message | Out-File -FilePath $logFile -Append

    Try {
        $return = Invoke-Command -ComputerName $DcFqdn -Credential $Credential -ScriptBlock {
            $remoteMessage = @()
            $content = $null

            $remoteMessage = ("{0}: Connected to DC.`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Try {
                $content = Get-Content -Path C:\Windows\System32\adConfig.json -ErrorAction Stop

                $remoteMessage += ("{0}: File content retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            }
            Catch {
                $remoteMessage += ("{0}: DC Error: {1}`r`n" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            }

            Return $remoteMessage, $content
        } -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting the contents of adConfig.json. The error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Return 1
    }

    If ($return -is [system.array]) {
        $backup = $return[1]
        $remoteMessage = $return[0]
    }
    Else {
        # Only one item was returned and we assume it is the "message", meaning that there was no backup retrieved.
        $remoteMessage | Out-File -FilePath $logFile -Append

        Return 1
    }

    If ($remoteMessage -match "DC Error:") {
        # Writing the error from the DC.
        $remoteMessage | Out-File -FilePath $logFile -Append

        Return 1
    }
    ElseIf ($backup) {
        # Writing the error from the DC first.
        $remoteMessage | Out-File -FilePath $logFile -Append

        $message = ("{0}: Returning:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($backup | Out-String))
        $message | Out-File -FilePath $logFile -Append

        $backup
    }
    Else {
        $message = ("{0}: Unexpected or no content retrieved:`r`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $return)
        $message | Out-File -FilePath $logFile -Append

        Return 1
    }
}

$server = "##SYSTEM.HOSTNAME##"
$cred = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))
If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the collector will write the log file.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-get_adproperties-collection-$server.log"

$message = ("{0}: Calling the function to retrieve the the Active Directory config file from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $server)
$message | Out-File -FilePath $logFile # This script only writes to the log file and not write-host, because the logging was getting mixed up with the JSON data, causing it to appear invalid.

$return = Get-JsonFile -DcFqdn $server -Credential $cred -logFile $logFile

If (($return) -and ($return -ne 1)) {
    $message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $return

    Exit 0
}
Else {
    $message = ("{0}: No file retrieved, script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}