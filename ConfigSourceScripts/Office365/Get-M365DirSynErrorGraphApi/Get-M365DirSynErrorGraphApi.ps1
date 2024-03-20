<#
    .DESCRIPTION
        Connect to Microsoft 365 (Azure AD) to retrieve Active Directory sync errors.
    .NOTES
        V2024.03.20.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Office365
#>
[CmdletBinding()]
param ()

#region Setup
#region In-line functions
Function Get-GraphApiToken {
    <#
        .DESCRIPTION
            Generate API token for Microsoft Graph API.
        .NOTES
            Author: Mike Hashemi
            V2023.10.05.0
            V2024.01.29.0
        .LINK
            
        .PARAMETER TenatDomain
            Url of the Azure AD tenant (e.g. company.onmicrosoft.com).
        .PARAMETER GraphApiClientId
            Graph API client ID.
        .PARAMETER GraphApiClientSecret
            Graph API client secret.
        .PARAMETER LogPath
            Hashtable representing the parameters required for logging. If not provided, the function will not log any messages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$TenantDomain,

        [Parameter(Mandatory)]
        [String]$GraphApiClientId,

        [Parameter(Mandatory)]
        [String]$GraphApiClientSecret,

        [String]$LogPath
    )

    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($LogPath) {
            $loggingParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        } Else {
            $loggingParams = @{
                Verbose = $true
            }
        }
    } Else {
        If ($LogPath) {
            $loggingParams = @{
                LogPath = $LogPath
            }
        } Else {
            $loggingParams = @{}
        }
    }

    #region MS Graph auth
    $message = ("{0}: Attempting to connect to Microsoft Graph API ({1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $GraphApiClientId); $message | Out-File -FilePath $LogPath -Append

    $authParams = @{
        Body   = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://graph.microsoft.com/.default"
            Client_Id     = $GraphApiClientId
            Client_Secret = $GraphApiClientSecret
        }
        Uri    = "https://login.microsoftonline.com/$TenantDomain/oauth2/v2.0/token"
        Method = "POST"
    }

    Try {
        $token = Invoke-RestMethod @authParams
    } Catch {
        $message = ("{0}: Unexpected error getting an access token from Microsoft. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message); $message | Out-File -FilePath $LogPath -Append

        Exit 1
    }

    If (-NOT($token.access_token)) {
        $message = ("{0}: No token retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $LogPath -Append

        Exit 1
    } Else {
        $token | Add-Member -MemberType NoteProperty -Name TokenExpiration -Value (Get-Date).AddMinutes(59) -Force

        Return $token
    }
    #endregion MS Graph auth
} #2024.01.29.0
#endregion In-line functions

#region Initialize variables
$computer = "##SYSTEM.HOSTNAME##"
$graphApiAuthParams = @{
    TenantDomain         = "##custom.m365.tenantUrl##"
    GraphApiClientId     = "##custom.m365.appClientId##"
    GraphApiClientSecret = "##custom.m365.appClient.key##"
}
#endregion Initialize variables

#region Logging
If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$LogPath = "$logDirPath\configsource-Get-M365DirSyncErrorGraphApi-collect-$computer.log"
#endregion Logging

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $LogPath
#endregion Setup

#region Microsoft auth
$token = Get-GraphApiToken @graphApiAuthParams -LogPath $LogPath

If ($token -eq 1) {
    $message = ("{0}: Failed to connect to Azure AD." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $LogPath -Append

    Exit 1
}
#endregion Microsoft auth

#region Main
$provisioningErrors = [System.Collections.Generic.List[PSObject]]::new()
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$url = "https://graph.microsoft.com/v1.0/users?`$select=onPremisesProvisioningErrors,displayName&`$filter=onPremisesProvisioningErrors/any(r:r/category eq 'PropertyConflict')"

Do {
    $message = ("{0}: Query URL: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url); $message | Out-File -FilePath $LogPath -Append

    $response = Invoke-RestMethod -Headers $headers -Uri $url -Method GET

    Foreach ($value in $response.value) {
        $provisioningErrors.Add($value)
    }

    $url = $response.'@odata.nextLink'

    $message = ("{0}: Retrieved {1} provisioning errors." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $provisioningErrors); $message | Out-File -FilePath $LogPath -Append
}
While ($null -ne $url)
#endregion Main

#region Output
If ($provisioningErrors) {
    $message = ("{0}: Returning data: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($provisioningErrors | Out-String).Trim()); $message | Out-File -FilePath $LogPath -Append

    ($provisioningErrors | Out-String).Trim()
} Else {
    $message = ("{0}: No provisioning errors detected." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $LogPath -Append
}
#endregion Output

$message = ("{0}: Script complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); $message | Out-File -FilePath $LogPath -Append

Exit 0