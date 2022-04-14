<#
    .DESCRIPTION
        Connect to Azure AD, and query for Application Gateway-certificate expiration.
    .NOTES
        V2022.04.13.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Azure/Get-AzureApplicationGatewayCert
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = '##SYSTEM.HOSTNAME##'
$tenantId = '##CUSTOM.AZURETENANT.ID##'
$applicationId = '##CUSTOM.AZUREAPPLICATION.ID##'
$applicationPassword = '##CUSTOM.AZUREAPPLICATION.PASS##'
$azureADCred = New-Object System.Management.Automation.PSCredential($applicationId, (ConvertTo-SecureString -String $applicationPassword -AsPlainText -Force))
$searchParams = @{
    Query = 'Resources | where type =~ "Microsoft.Network/applicationGateways" | join kind=leftouter (ResourceContainers | where type=="microsoft.resources/subscriptions" | project subscriptionName=name, subscriptionId) on subscriptionId | project id, subscriptionId, subscriptionName, resourceGroup, name, sslCertificates = properties.sslCertificates | order by id'
    First = 200
}

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Get-AzureApplicationGatewayCert-collection-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Install modules
Switch ("Az.Accounts", "Az.ResourceGraph") {
    { (Get-Module -Name $_ -ListAvailable) } {
        If ($_ -eq 'Az.Accounts') {
            Foreach ($module in (Get-Module -Name 'Az.Accounts' -ListAvailable)) {
                If ($module.Version -lt '1.8.1') {
                    $message = ("{0}: The {1} module is installed, but not the minimum version (1.8.1). Attempting to install a newer version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
                    $message | Out-File -FilePath $logFile

                    Install-Module -Name $_ -MinimumVersion 1.8.1 -Force -ErrorAction Stop
                }
            }
        }
        $message = ("{0}: The {1} module is installed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
        $message | Out-File -FilePath $logFile
    }
    { (-NOT(Get-Module -Name $_ -ListAvailable)) } {
        $message = ("{0}: The {1} module is not installed, attempting to install it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
        $message | Out-File -FilePath $logFile

        Try {
            Install-Module -Name $_ -Force -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error installing {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_, $_.Exception.Message)
            $message | Out-File -FilePath $logFile

            Exit 1
        }
    }
}
#endregion Install modules
#endregion Setup

#region Auth
# Make sure we don't save the password on the local file system.
$null = Disable-AzContextAutosave

$message = ("{0}: Attempting to connect to Azure with the application credential for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $applicationId)
$message | Out-File -FilePath $logFile -Append

Try {
    $azConn = Connect-AzAccount -ServicePrincipal -Credential $azureADCred -TenantId $tenantId
}
Catch {
    $message = ("{0}: Unexpected error connecting to Azure. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}

If ($azConn.Context.Account.Id -eq $applicationId) {
    $message = ("{0}: Connection successful." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append
}
Else {
    $message = ("{0}: Unknown failure to connect to Azure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Auth

#region Main
$message = ("{0}: Querying Azure Graph for Application Gateway certificates." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

Try {
    $results = [System.Collections.Generic.List[PSObject]]::New()
    Do {
        $results.Add($(Search-AzGraph @searchParams))
        if ($results.SkipToken) {
            $searchParams.SkipToken = $results.SkipToken
        }
    } While ($results.SkipToken)
}
Catch {
    $message = ("{0}: Unexpected error querying Azure Graph." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $null = Disconnect-AzAccount

    Exit 1
}

If ($results.id) {
    $message = ("{0}: There are {1} results, getting properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $results.id.Count)
    $message | Out-File -FilePath $logFile -Append

    Foreach ($record in $results.data) {
        $message = ("{0}: There are {1} cert records under {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $record.sslCertificates.Count, $record.name)
        $message | Out-File -FilePath $logFile -Append

        Foreach ($sslCertRecord in $record.sslCertificates) {
            $cert = $null

            If (-NOT $sslCertRecord.properties.publicCertData) {
                $message = ("{0}: Certificate {1} is linked to Key Vault secret: {2}. Certificate scanning is not supported in this scenario. You can leverage Azure Policy to do so." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $sslCertRecord.name, $sslCertRecord.properties.keyVaultSecretId)
                $message | Out-File -FilePath $logFile -Append
            } Else {
                $message = ("{0}: Returning certificate properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                $message | Out-File -FilePath $logFile -Append

                $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($sslCertRecord.properties.publicCertData.Substring(60, $sslCertRecord.properties.publicCertData.Length - 60)))

                [PSCustomObject][Ordered]@{
                    SubscriptionId    = $record.subscriptionId
                    SubscriptionName  = $record.subscriptionDisplayName
                    ResourceGroup     = $record.resourceGroup
                    Name              = $record.Name
                    CertificateName   = $sslCertRecord.name
                    NotAfter          = $cert.NotAfter
                    Thumbprint        = $cert.Thumbprint
                    ImpactedListeners = , @($sslCertRecord.properties.httpListeners | ForEach-Object { ($_.id -split '/')[-1] } )
                    ExpirationUnder30 = If (([datetime]$cert.NotAfter -lt (Get-Date).AddDays(30)) -or ([datetime]$cert.NotAfter -le (Get-Date))) { 'True' } Else { 'False' }
                    ExpirationUnder7  = If (([datetime]$cert.NotAfter -lt (Get-Date).AddDays(7)) -or ([datetime]$cert.NotAfter -le (Get-Date))) { 'True' } Else { 'False' }
                }
            }
        }
    }
} Else {
    $message = ("{0}: No certificate records were returned." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append
}

$message = ("{0}: Disconnecting from Azure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$null = Disconnect-AzAccount

Exit 0
#endregion Main