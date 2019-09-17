# Initialize variables.
$siteUrl = '##wildValue##'
$siteName = '##wildAlias##'
$adminSiteURL = '##sharepointonlineadmin.url##'
$cred = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Storage_Utilization-collection-$siteName.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Attempting to connect to {1} with {2}." -f [datetime]::Now, $adminSiteURL, $cred.UserName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    Connect-SPOService -Url $adminSiteURL –Credential $cred -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error connecting to SharePointOnline. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}

$message = ("{0}: Attempting to get the list of SharePoint sites." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    $siteCollections = Get-SPOSite -Limit All -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error connecting getting SharePoint sites. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}

$site = $siteCollections.Where( { $_.Title -eq $siteName })

If ($site.Status -eq 'Active') {
    $data = [PSCustomObject]@{
        Allocated   = $site.StorageQuota
        Used        = $site.StorageUsageCurrent
        PercentUsed = [math]::Round((($site.StorageUsageCurrent / $site.StorageQuota) * 100), 2)
    }

    $message = ("{0}: Found:`r`nAllocatedStorage={1}`r`nUsedStorage={2}`r`nPercentUsed={3}." -f [datetime]::Now, $data.Allocated, $data.Used, $data.PercentUsed)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host ("Allocated={0}" -f $data.Allocated)
    Write-Host ("Used={0}" -f $data.Used)
    Write-Host ("PercentUsed={0}" -f $data.PercentUsed)

    Exit 0
}
Else {
    $message = ("{0}: {1} is not active." -f [datetime]::Now, $siteName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 0
}