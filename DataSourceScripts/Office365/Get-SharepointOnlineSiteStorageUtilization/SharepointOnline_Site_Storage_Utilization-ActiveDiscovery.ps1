# Initialize variables.
$adminSiteURL = '##sharepointonlineadmin.url##'
$cred = New-Object System.Management.Automation.PSCredential ('##sharepointonlineadmin.user##', ('##sharepointonlineadmin.pass##' | ConvertTo-SecureString -AsPlainText -Force))

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SharepointOnline_Site_Storage_Utilization-ad-$(($adminSiteURL.Split('/')[-1]).Split('-')[0]).log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

$message = ("{0}: Checking if the Microsoft.Online.SharePoint.PowerShell module is installed." -f [datetime]::Now)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

If (-NOT (Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
    $message = ("{0}: The Microsoft.Online.SharePoint.PowerShell module is not installed. Attempting to install it." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Try {
        Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force
    }
    Catch {
        $message = ("{0}: Unexpected error installing the Microsoft.Online.SharePoint.PowerShell module. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Exit 1
    }
}
Else {
    $message = ("{0}: The Microsoft.Online.SharePoint.PowerShell module is installed." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
}

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

$message = ("{0}: Found {1} sites." -f [datetime]::Now, $siteCollections.count)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

Foreach ($site in $siteCollections) {
    $message = ("{0}: Returning {1}." -f [datetime]::Now, $site.title)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host "$($site.url)##$($site.title)"
}

Exit 0