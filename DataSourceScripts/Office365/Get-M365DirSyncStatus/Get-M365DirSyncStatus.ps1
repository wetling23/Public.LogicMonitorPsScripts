<#
    .DESCRIPTION
        Connect to Micrsoft 365 (Azure AD) to retrieve Active Directory sync status (last sync times). If the required PowerShell module (MSOnline) is not installed, the script will attempt to install it.
    .NOTES
        V1.0.0.0 date: 11 May 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
[pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##custom.m365.user##', ('##custom.m365.pass##' | ConvertTo-SecureString -AsPlainText -Force))
$tenantId = "##custom.m365.tenantId##"

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get-M365DirSyncStatus-collect-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

If (-NOT(Get-Module -Name MSOnline -ListAvailable)) {
    $message = ("{0}: The MSOnline PowerShell module is not installed, attempting to install it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Try {
        Install-Module -Name MSOnline -Force -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error installing the MSOnline PowerShell module. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Else {
    $message = ("{0}: The required module is installed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append
}
#endregion Setup

#region Main
$message = ("{0}: Attempting to connect to MS Online service." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    Connect-MsolService -Credential $credential -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error connecting to MS Online service. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to get company information." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $syncStatus = Get-MsolCompanyInformation -TenantId $tenantId -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error retrieving company information. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If ($syncStatus.DisplayName) {
    $lastDirSync = (New-TimeSpan -Start $syncStatus.LastDirsyncTime -End (Get-Date).ToUniversalTime()).TotalHours
    $lastPwSync = (New-TimeSpan -Start $syncStatus.LastPasswordSyncTime -End (Get-Date).ToUniversalTime()).TotalHours

    Write-Host ("LastDirectorySync={0}" -f [Math]::Abs($lastDirSync))
    Write-Host ("LastPasswordSync={0}" -f [Math]::Abs($lastPwSync))

    $message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 0
}
Else {
    $message = ("{0}: No company information retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Main