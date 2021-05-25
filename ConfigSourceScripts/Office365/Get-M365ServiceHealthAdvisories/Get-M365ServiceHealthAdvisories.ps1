<#
    .DESCRIPTION
        Connect to Microsoft 365 to the list of service health advisories.
    .NOTES
        V1.0.0.0 date: 24 May 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Get-M365ServiceHealthAdvisories/Office365
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
$clientID = "##custom.m365.clientId##"
$clientSecret = "##custom.m365.clientSecret##"
$tenantId = "##custom.m365.tenantId##"
$uri = "https://manage.office.com/api/v1.0/$tenantID/ServiceComms/Messages"

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Get-M365ServiceHealthAdvisories-collect-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile
#endregion Setup

#region Main
$message = ("{0}: Attempting to connect to MS Online service." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Try {
    $body = @{
        grant_type = "client_credentials"
        resource = "https://manage.office.com"
        client_id = $clientID
        client_secret = $clientSecret
    }
    $oauth = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($tenantID)/oauth2/token?api-version=1.0" -Body $body
    $token = @{'Authorization' = "$($oauth.token_type) $($oauth.access_token)" }
}
Catch {
    $message = ("{0}: Unexpected error connecting to MS Online service. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to get service health advisories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Try {
    $messages = (Invoke-RestMethod -Uri $uri -Headers $token -Method Get).value | Where-Object { $_.EndTime -eq $null }
}
Catch {
    $message = ("{0}: Unexpected error retrieving service health advisories. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If ($messages.Id) {
    $message = ("{0}: Found {1} active health advisories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $messages.Id.Count)
    $message | Out-File -FilePath $logFile -Append

    $activeEvents = Foreach ($message in $messages) {
        [PSCustomObject]@{
            Title             = $message.Title
            Id                = $message.Id
            ImpactDescription = $message.ImpactDescription
            Severity          = $message.Severity
            Status            = $message.Status
            Workload          = $message.Workload
        }
    }

    $message = ("{0}: Returning the service health advisories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $eventString = $activeEvents | Format-List

    $eventString; $eventString | Out-File -FilePath $logFile -Append
}
Else {
    $message = ("{0}: No active service health advisories." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append
}

$message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Exit 0
#endregion Main