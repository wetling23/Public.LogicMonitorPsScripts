<#
    .DESCRIPTION
        Connect to Azure AD, and query Web Applicaiton Firewall log, returning details of blocked connections.
    .NOTES
        V1.0.0.0 date: 2 December 2021
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Azure/Get-AzureWafBlockedConnection
#>
[CmdletBinding()]
param ()

#region Setup
# Initialize variables
$computer = '##SYSTEM.HOSTNAME##'
$queryLookBackMinutes = 60
$workspaceId = '##CUSTOM.AZUREWAFWORKSPACE.ID##'
$tenantId = '##CUSTOM.AZUREWAFTENANT.ID##'
$applicationId = '##CUSTOM.AZUREWAFAPPLICATION.ID##'
$applicationPassword = '##CUSTOM.AZUREWAFAPPLICATION.PASS##'
$azureADCred = New-Object System.Management.Automation.PSCredential($applicationId, (ConvertTo-SecureString -String $applicationPassword -AsPlainText -Force))

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource-Get-AzureWafBlockedConnection-collection-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Install modules
Switch ("Az.Accounts", "Az.OperationalInsights") {
    { (Get-Module -Name $_ -ListAvailable) } {
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
$message = ("{0}: Querying Azure Operational Insights for blocked connections." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$query = 'AzureDiagnostics | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog" | where action_s == "Blocked"'

Try {
    $results = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $query -Timespan (New-TimeSpan -Minutes $queryLookBackMinutes)
}
Catch {
    $message = ("{0}: Unexpected error querying Azure Operational Insights." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $null = Disconnect-AzAccount

    Exit 1
}

$message = ("{0}: Disconnecting from Azure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
$message | Out-File -FilePath $logFile -Append

$null = Disconnect-AzAccount

If ($results.Results.'action_s'.Count -gt 0) {
    $message = ("{0}: Returning data to LogicMonitor:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($results.Results | Out-String))
    $message | Out-File -FilePath $logFile -Append

    $results.Results | ConvertTo-Json -Depth 5
}
Else {
    $message = ("{0}: Zero blocked-connection entries were returned by Azure." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append
}

Exit 0
#endregion Main