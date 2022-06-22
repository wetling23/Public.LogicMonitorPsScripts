<#
    .DESCRIPTION
        Connect to Sharepoint Online, and query a site for quota data.
    .NOTES
        V2019.09.17.0
        V2022.06.22.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365/Get-SharepointOnlneSiteStorageUtilization
#>
[CmdletBinding()]
param()

#region Setup
# Initialize variables.
$siteUrl = '##wildValue##'
$siteName = '##wildAlias##'
$adminSiteURL = '##sharepointonlineadmin.url##'
$cred = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Site_Storage_Utilization-collection-$siteName.log"
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Auth
$message = ("{0}: Attempting to connect to {1} with {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $adminSiteURL, $cred.UserName)
$message | Out-File -FilePath $logFile -Append

$stopLoop = $false
Do {
    Try {
        Connect-SPOService -Url $adminSiteURL –Credential $cred -ErrorAction Stop

        $stopLoop = $True
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            Start-Sleep -Seconds 60
        } Else {
            $message = $message = ("{0}: Unexpected error connecting to SharePointOnline. The specific error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }
}
While ($stopLoop -eq $false)
#endregion Auth

#region Main
$message = ("{0}: Attempting to get the list of SharePoint sites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$stopLoop = $false
Do {
    Try {
        $site = Get-SPOSite -Identity $siteUrl -ErrorAction Stop

        $stopLoop = $True
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            Start-Sleep -Seconds 60
        } Else {
            $message = ("{0}: Unexpected error getting SharePoint site properties. The specific error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }
}
While ($stopLoop -eq $false)

If ($site.Status -eq 'Active') {
    $percentUsed = [math]::Round((($site.StorageUsageCurrent / $site.StorageQuota) * 100), 2)

    $message = ("{0}: Found:`r`nAllocatedStorage={1}`r`nUsedStorage={2}`r`nPercentUsed={3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $site.StorageQuota, $site.StorageUsageCurrent, $percentUsed)
    $message | Out-File -FilePath $logFile -Append

    Write-Host ("Allocated={0}" -f $site.StorageQuota)
    Write-Host ("Used={0}" -f $site.StorageUsageCurrent)
    Write-Host ("PercentUsed={0}" -f $percentUsed)

    Exit 0
}
Else {
    $message = ("{0}: {1} is not active." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $siteName)
    $message | Out-File -FilePath $logFile -Append

    Exit 0
}
#endregion Main