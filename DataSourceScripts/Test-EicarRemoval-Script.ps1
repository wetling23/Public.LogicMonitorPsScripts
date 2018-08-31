$username = "##wmi.user##"
$password = "##wmi.pass##"
$domainCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)
$server = "##system.hostname##"

# Add the remote device to the list of TrustedHosts, if the collector is not on a domain.
If (-NOT(Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Set-Item WSMan:\Localhost\Client\TrustedHosts -Value $server -Force -Concatenate
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
            [ValidateScript( {Test-Path $_ -PathType 'Container'})]
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

Write-Host $status