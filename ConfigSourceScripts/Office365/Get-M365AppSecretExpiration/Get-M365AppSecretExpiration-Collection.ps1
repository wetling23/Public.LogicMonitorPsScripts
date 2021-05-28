<#
    .DESCRIPTION
        Connect to Microsoft 365 (Azure AD) to retrieve application secrets.
    .NOTES
        V1.0.0.0 date: 28 May 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Office365
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
$clientId = "##custom.m365.appClientId##"
$clientSecret = "##custom.m365.appClient.key##"
$tenatDomainName = "##custom.m365.tenantUrl##"
$allApps = [System.Collections.Generic.List[PSObject]]::new()
$secrets = [System.Collections.Generic.List[PSObject]]::new()
$i = 0
$url = 'https://graph.microsoft.com/v1.0/applications'

If (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Get-M365AppSecretExpiration-collection-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile
#endregion Setup

#region Auth
$message = ("{0}: Attempting to connect to Microsoft Graph API." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    client_Id     = $clientId
    Client_Secret = $clientSecret
}

Try {
    $token = (Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenatDomainName/oauth2/v2.0/token" -Method POST -Body $body).access_token
}
Catch {
    $message = ("{0}: Unexpected error getting an access token from Microsoft. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If (-NOT($token)) {
    $message = ("{0}: No token retrieved, exiting." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Auth

#region get application list
$message = ("{0}: Attempting to get a list of applications." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Do {
    $response = Invoke-RestMethod -Headers @{ Authorization = "Bearer $($token)" } -Uri $url -Method Get

    Foreach ($value in $response.value) {
        $allApps.Add($value)
    }

    $url = $response.'@odata.nextLink'
}
While ($response.'@odata.nextLink')
#endregion get application list

#region Main
Foreach ($app in $allApps) {
    $i++

    $message = ("{0}: Getting data from secret {1}. This is {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $app.displayName, $i, $allApps.id.Count)
    $message | Out-File -FilePath $logFile -Append

    If ($app.passwordCredentials.Count -gt 1) {
        $message = ("{0}: The app, {1}, has multiple secrets." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $app.displayName)
        $message | Out-File -FilePath $logFile -Append
    } Else {
        $message = ("{0}: The app, {1}, has a single secret." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $app.displayName)
        $message | Out-File -FilePath $logFile -Append
    }

    Foreach ($secret in $app.passwordCredentials) {
        If ($secret.endDateTime) {
            $message = ("{0}: Calculating secret end date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $daysLeft = (New-TimeSpan -Start (Get-Date).ToUniversalTime() -End $secret.endDateTime).Days

            If ($daysLeft -le 60) {
                $alert = 'True'
            }
            Else {
                $alert = 'False'
            }
        }
        Else {
            $message = ("{0}: The secret has no end date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            $message | Out-File -FilePath $logFile -Append

            $daysLeft = 'n/a'
            $alert = 'False'
        }

        $secrets.Add([PSCustomObject]@{
                AppName             = $app.displayName
                AppId               = $app.id
                RemainingSecretDays = $daysLeft
                SecretDisplayName   = $secret.passwordCredentials.displayName
                HomePageUrl         = $app.web.homePageUrl
                ExpiresInLessThan60 = $alert
            })
    }
}

If ($secrets) {
    $message = ("{0}: Returning secrets: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($secrets | Out-String))
    $message | Out-File -FilePath $logFile -Append

    $secrets
}

Exit 0
#endregion Main