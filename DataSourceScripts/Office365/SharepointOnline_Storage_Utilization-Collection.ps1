<#
    .DESCRIPTION
        Monitor SharepointOnline storage utilization.
    .NOTES
        -Author: Mike Hashemi
        V1.0.0.0 date: 10 October 2019
            - Initial release.

        Requires the Microsoft.Online.SharePoint.PowerShell PowerShell module.

        When run as a LogicMonitor DataSource, assign the sharepointonlineadmin.url, sharepointonlineadmin.user, and sharepointonlineadmin.pass properties to the target device.
        This script can also be run manually, providing the AdminSiteUrl and Office365AdminCredential parameters.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365
    .PARAMETER AdminSiteUrl
        Represents the URL of the desired Office 365 admin site.
    .PARAMETER Office365AdminCredential
        Represents the username and password of a user with access to the Office 365 admin site.
#>
#Requires -Module Microsoft.Online.SharePoint.PowerShell
[CmdletBinding()]
param (
    [ValidateScript( {
            If (-NOT ($($_ -as [System.URI]).AbsoluteURI -ne $null -and $($_ -as [System.URI]).Scheme -match 'http') ) {
                Throw "Invalid URL."
            }
            Return $true
        })]
    [string]$AdminSiteUrl,

    [System.Management.Automation.PSCredential]$Office365AdminCredential
)

# Initialize variables.
If (-NOT ($AdminSiteURL)) {
    $AdminSiteURL = '##sharepointonlineadmin.url##'
}

If (-NOT ($Office365AdminCredential)) {
    $Office365AdminCredential = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))
}

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Storage_Utilization-collection-$(($AdminSiteURL.Split('/')[-1]).Split('-')[0]).log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Attempting to connect to {1} with {2}." -f [datetime]::Now, $AdminSiteURL, $Office365AdminCredential.UserName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    Connect-SPOService -Url $AdminSiteURL –Credential $Office365AdminCredential -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error connecting to SharePointOnline. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Getting tenant data." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    $tenant = Get-SPOTenant -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error getting SharePointOnline tenant information. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Getting SharePointOnline site information." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    $siteCollections = Get-SPOSite -Limit All -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error getting SharePointOnline site information. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$allocated = [math]::Round(($tenant.StorageQuota / 1024 / 1024), 2)
$used = [math]::Round((($siteCollections.StorageUsageCurrent | Measure-Object -Sum).Sum / 1024 / 1024), 2)

$data = [PSCustomObject]@{
    Allocated   = $allocated
    Used        = $used
    PercentUsed = [math]::Round((($used / $allocated) * 100), 2)
}

Write-Host ("Allocated(GB)={0}" -f ($data.Allocated * 1024))
Write-Host ("Used(GB)={0}" -f ($data.Used * 1024))
Write-Host ("PercentUsed={0}" -f $data.PercentUsed)

Exit 0