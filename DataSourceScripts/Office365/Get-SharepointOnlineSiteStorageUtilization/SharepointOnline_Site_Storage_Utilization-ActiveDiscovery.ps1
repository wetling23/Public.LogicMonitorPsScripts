<#
    .DESCRIPTION
        Connect to Sharepoint Online, and query for a list of sites.
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
$adminSiteURL = '##sharepointonlineadmin.url##'
$cred = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))

$adminSiteURL = 'https://hs2solutions-admin.sharepoint.com'
$cred = New-Object System.Management.Automation.PSCredential ('synadmin@bounteous.com', ('Xe6eATx$Nx02#pM0' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Site_Storage_Utilization-ad-$(($adminSiteURL.Split('/')[-1]).Split('-')[0]).log"
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Install module
$message = ("{0}: Checking if the Microsoft.Online.SharePoint.PowerShell module is installed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

If (-NOT (Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
    $message = ("{0}: The Microsoft.Online.SharePoint.PowerShell module is not installed. Attempting to install it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Try {
        Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force
    }
    Catch {
        $message = ("{0}: Unexpected error installing the Microsoft.Online.SharePoint.PowerShell module. The specific error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Else {
    $message = ("{0}: The Microsoft.Online.SharePoint.PowerShell module is installed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append
}
#endregion Install module

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
        $siteCollections = Get-SPOSite -Limit All -ErrorAction Stop

        $stopLoop = $True
    } Catch {
        If ($_.Exception.Message -match '429') {
            $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            Start-Sleep -Seconds 60
        } Else {
            $message = ("{0}: Unexpected error getting SharePoint sites. The specific error is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            $message | Out-File -FilePath $logFile -Append

            Exit 1
        }
    }
}
While ($stopLoop -eq $false)

$message = ("{0}: Found {1} sites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $siteCollections.count)
$message | Out-File -FilePath $logFile -Append

Foreach ($site in $siteCollections) {
    $message = ("{0}: Returning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $site.title)
    $message | Out-File -FilePath $logFile -Append

    Write-Host "$($site.url)##$($site.title)"
}
#endregion Main

Exit 0