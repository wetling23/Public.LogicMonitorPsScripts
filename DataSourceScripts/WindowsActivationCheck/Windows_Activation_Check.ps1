<#
    .DESCRIPTION
        Used to check Windows Activation Status
    .NOTES
        Author: Chris Burns
        Contributor: Mike Hashemi
        V1.0.0.0 date: August 18, 2020
            - Testing
        V1.0.0.1 date: August 18, 2020
            - Hashemi rewrote, now it's actually functional
    .LINK

#>


$computer = '##system.hostname##'
[pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##wmi.user##', ('##wmi.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-WindowsLicenseStatus-collection-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$message = ("{0}: Checking TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

# If necessary, update TrustedHosts.
If (-NOT(($computer -eq $env:ComputerName) -or ($computer -eq "127.0.0.1"))) {
    If (((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -notmatch $computer) -and ((Get-WSManInstance -ResourceURI winrm/config/client).TrustedHosts -ne "*")) {
        $message = ("{0}: Adding {1} to TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $computer -Concatenate -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error updating TrustedHosts: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }
    Else {
        $message = ("{0}: {1} is already in TrustedHosts." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append
    }
}

$message = ("{0}: Building command parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$params = @{
    Filter      = "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'"
    Property    = "LicenseStatus"
    Class       = "SoftwareLicensingProduct"
}

# If monitoring the local host, 
If ($computer -ne "127.0.0.1") {
    $params.Add('ComputerName', $computer)
    $params.Add('Credential', $credential)
}

$message = ("{0}: Params:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$message = ("{0}: Attemping to get data from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $lic = Get-WmiObject @params -ErrorAction Stop | Select-Object -ExpandProperty LicenseStatus
}
Catch {
    $message = ("{0}: Unexpected error getting get data from {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If ($lic -contains 1) {
    $message = ("{0}: Found `"1`" in the output, the license is okay." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("LicenseStatus=0")
}
Else {
    $message = ("{0}: Did not find `"1`" in the output, the license is not okay." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computer, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("LicenseStatus=1")
}

Exit 0