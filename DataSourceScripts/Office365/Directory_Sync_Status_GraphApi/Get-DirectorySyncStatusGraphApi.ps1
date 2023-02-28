<#
    .DESCRIPTION
        Authenticate to Microsoft Graph API and retrieve last-sync time for directory and passwords.
    .NOTES
        Author: Mike Hashemi
        V2022.10.04.0
        V2023.02.28.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Office365/Directory_Sync_Status_GraphApi
#>
[CmdletBinding()]
param(
)

#region Setup
#region Initialize variables
$graphApiClientId = "##custom.graphApiClientId##"
$graphApiClientSecret = "##custom.graphApiClientSecret.key##"
$tenantDomainName = "##custom.graphApiTenantDomain##"
$graphUrl = "https://graph.microsoft.com/beta/organization"
$computerName = '##hostname##'
#endregion Initialize variables

#region Logging
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasourceGet-Directory_Sync_Status_Graph_Api_collect-$computerName.log"
#endregion Logging

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile
#endregion Setup

#region MS Graph auth
$message = ("{0}: Attempting to connect to Microsoft Graph API." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; ; $message | Out-File -FilePath $logFile -Append

$authParams = @{
    Body   = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        client_Id     = $GraphApiClientId
        Client_Secret = $GraphApiClientSecret
    }
    Uri    = "https://login.microsoftonline.com/$tenantDomainName/oauth2/v2.0/token"
    Method = "POST"
}

Try {
    $token = Invoke-RestMethod @authParams
} Catch {
    $message = ("{0}: Unexpected error getting an access token from Microsoft. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If (-NOT($token.access_token)) {
    $message = ("{0}: No token retrieved, exiting." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
} Else {
    $token | Add-Member -MemberType NoteProperty -Name TokenExpiration -Value (Get-Date).AddMinutes(59) -Force
}
#endregion MS Graph auth

#region Get org last sync datetime
If ($token.TokenExpiration -ge (Get-Date).AddMinutes(2)) {
    $message = ("{0}: Attempting to get org information." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Try {
        $orgData = Invoke-RestMethod -Headers @{ Authorization = "Bearer $($token.access_token)" } -Uri $graphUrl -Method Get -ErrorAction Stop
    } Catch {
        $message = ("{0}: Unexpected error getting org information. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    If (-NOT($orgData.value.onPremisesLastSyncDateTime -and $orgData.value.onPremisesLastPasswordSyncDateTime)) {
        $message = ("{0}: No last-sync date retrieved, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
} Else {
    $message = ("{0}: The Graph API token has expired." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Get org last sync datetime

#region Output
$nowUtc = [datetime]::UtcNow

$message = ("{0}: Parsign retrieved data:`r`n`tLast sync (UTC): {1}`r`n`tLast password sync (UTC): {2}`r`n`tRight now (UTC): {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $orgData.value.onPremisesLastSyncDateTime, $orgData.value.onPremisesLastPasswordSyncDateTime, $nowUtc)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Write-Host ("OnPremisesLastSyncDateTime={0}" -f $($nowUtc - [datetime]$orgData.value.onPremisesLastSyncDateTime).Minutes)
Write-Host ("OnPremisesLastPasswordSyncDateTime={0}" -f $($nowUtc - [datetime]$orgData.value.onPremisesLastPasswordSyncDateTime).Minutes)
#endregion Output

Exit 0