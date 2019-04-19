<#
    .DESCRIPTION
        This script generates an eicar (virus detection test) file on the monitored device. If the antivirus software is operating properly, we expect the file to be removed. If it is present, the DS assumes that AV is not functioning.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 19 April 2019
            - Initial release.
#>
[CmdletBinding]

# Initialize variables.
$server = "##SYSTEM.HOSTNAME##"
$domainCred = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))
If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the collector will write the log file.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Test_Eicar_Removal-collection-$server.log"

$message = ("{0}: Checking TrustedHosts file." -f [datetime]::now)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

# Add the target device to TrustedHosts.
If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $DcFqdn) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*") -and ($DcFqdn -ne "127.0.0.1")) {
    $message = ("{0}: Adding {1} to TrustedHosts." -f [datetime]::now, $hostDcFqdnname)
    If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Try {
        Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $DcFqdn -Concatenate -Force -ErrorAction Stop
    }
    Catch {
        $message = ("Unexpected error updating TrustedHosts: {0}" -f $_.Exception.Message)
        If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Exit 1
    }
}

$session = New-PSSession -Name eicarMonitor -ComputerName $server -Credential $domainCred

$status = Invoke-Command -Session $session -ScriptBlock {
    Function New-Eicar {
        <#
            .SYNOPSIS
                New-Eicar

                Author: Chris Campbell (@obscuresec)
                License: BSD 3-Clause
            .DESCRIPTION
                A function that generates the EICAR string to test ondemand scanning of antivirus products.
            .PARAMETER $Path
                Specifies the path to write the eicar file to.
            .EXAMPLE
                PS C:\> New-Eicar -Path c:\test
            .NOTES
                During testing, several AV products caused the script to hang, but it always completed after a few minutes.
            .LINK
                http://obscuresec.com/2013/01/New-Eicar.html
                https://github.com/obscuresec/random/blob/master/New-Eicar
        #>
        [CmdletBinding()] Param(
            [ValidateScript( { Test-Path $_ -PathType 'Container' })]
            [string]$Path = "$env:temp\"
        )

        [string] $FilePath = (Join-Path $Path eicar.com)

        #Base64 of Eicar string
        [string] $EncodedEicar = 'WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo='

        If (-NOT(Test-Path -Path $FilePath)) {
            Try {
                [byte[]] $EicarBytes = [System.Convert]::FromBase64String($EncodedEicar)
                [string] $Eicar = [System.Text.Encoding]::UTF8.GetString($EicarBytes)
                Set-Content -Value $Eicar -Encoding ascii -Path $FilePath -Force
                Write-Output "File not found. Created file."
                Write-Output 0
            }
            Catch {
                Write-Output "Eicar.com file couldn't be created. Either permissions or AV prevented file creation."
                Write-Output 1
            }
        }
        Else {
            Write-Output "Eicar.com already exists!"
            Write-Output 2
        }
    }
    New-Eicar
}

Get-PSSession -Name eicarMonitor | Remove-PSSession

$message = ("{0}: Invoke-Command returned: {1}." -f [datetime]::now, $status)
If ($PSBoundParameters['Verbose']) { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Write-Host $status