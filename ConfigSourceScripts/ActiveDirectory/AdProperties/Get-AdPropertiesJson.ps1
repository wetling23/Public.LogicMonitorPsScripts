<#
    .DESCRIPTION
        Connect to a remote server and return the content of C:\Windows\System32\adConfig.json
    .NOTES
        Author: Mike Hashemi
        V1.0.0.1 date: 29 October 2020
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
    Write-Host $message; $message | Out-File -Path $logFile -Append

    # Add the target device to TrustedHosts.
    If (($DcFqdn -notmatch (Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($DcFqdn -ne "127.0.0.1")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hostDcFqdnname)
        Write-Host $message; $message | Out-File -Path $logFile -Append

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $DcFqdn -Concatenate -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Host $message; $message | Out-File -Path $logFile -Append

            Exit 1
        }
    }

    $message = ("{0}: Checking for the adConfig file on {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DcFqdn)
    Write-Host $message; $message | Out-File -Path $logFile -Append

    Try {
        $backup = Invoke-Command -ComputerName $DcFqdn -Credential $Credential -ScriptBlock {
            Try {Get-Content -Path C:\Windows\System32\adConfig.json -ErrorAction Stop} Catch {("DC Error: {0}" -f $_.Exception.Message)}
        } -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting the contents of adConfig.json. The error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Host $message; $message | Out-File -Path $logFile -Append

        Exit 1
    }

    If (($backup) -and ($backup -notmatch "DC Error:")) {
        $message = ("{0}: Retrieved Active Directory config content." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -Path $logFile -Append

        $message = ("{0}: Returning:`r`n." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $backup)
        Write-Host $message; $message | Out-File -Path $logFile -Append

        $backup
    }
    ElseIf (($backup) -and ($backup -match "DC Error:")) {
        $message = ("{0}: {1} reported an error retrieving Active Directory config content: {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DcFqdn, $backup)
        Write-Error $message; $message | Out-File -Path $logFile -Append
    }
    ElseIf ($backup) {
        $message = ("{0}: Unexpected content retrieved:`r`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $backup)
        Write-Error $message; $message | Out-File -Path $logFile -Append
    }
    ElseIf (-NOT($backup)) {
        $message = ("{0}: No content retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DcFqdn)
        Write-Error $message; $message | Out-File -Path $logFile -Append
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
Write-Host $message; $message | Out-File -Path $logFile

$return = Get-JsonFile -DcFqdn $server -Credential $cred -logFile $logFile

If ($return) {
    $message = ("{0}: File retrieved, script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -Path $logFile -Append

    $return

    Exit 0
}
Else {
    $message = ("{0}: No file retrieved, script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Error $message; $message | Out-File -Path $logFile -Append

    Exit 1
}