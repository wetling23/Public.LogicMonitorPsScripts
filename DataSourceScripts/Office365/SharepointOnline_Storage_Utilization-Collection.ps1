# Initialize variables.
$adminSiteURL = '##sharepointonlineadmin.url##'
$cred = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Storage_Utilization-collection-$(($adminSiteURL.Split('/')[-1]).Split('-')[0]).log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Attempting to connect to {1} with {2}." -f [datetime]::Now, $adminSiteURL, $cred.UserName)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Try {
    Connect-SPOService -Url $adminSiteURL –Credential $cred -ErrorAction Stop
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
    Allocated = $allocated
    Used      = $used
    PercentUsed = [math]::Round((($used / $allocated) * 100), 2)
}

Write-Host ("Allocated={0}" -f $data.Allocated)
Write-Host ("Used={0}" -f $data.Used)
Write-Host ("PercentUsed={0}" -f $data.PercentUsed)

Exit 0