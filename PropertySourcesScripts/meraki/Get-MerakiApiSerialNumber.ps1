<#
    .DESCRIPTION
        Connects to the Meraki API, to retrieve device serial numbers.

        Requires the meraki.api.orgname (representing the organization name defined in the Meraki portal) and meraki.api.key (API key with rights to access the defined organization) properties.
    .NOTES
        V1.0.0.0 date: 1 May 2020
            - Initial release.
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/meraki
#>
[CmdletBinding()]
param ()
#Requires -Version 5.0

$name = '##system.hostname##'
If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\propertySource-Meraki_API_Serial_Number-collection-$name.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Verbose $message; $message | Out-File -FilePath $logFile

# Initialize variables.
$orgName = "##meraki.api.orgname##"
$apiKey = "##meraki.api.key##"
$hostname = "##system.displayname##"

$headers = @{
    "X-Cisco-Meraki-API-Key" = $apiKey
    "Content-Type" = "application/json"
}

$message = ("{0}: Attempting to get the Meraki organization ID for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

Try {
    $orgId = ((Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v0/organizations" -Headers $headers -ErrorAction Stop).Where({$_.name -eq "$OrgName"})).id
}
Catch {
    $message = ("{0}: Unexpected error getting org ID. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

    Exit
}

If ($orgId) {
    $message = ("{0}: Found org ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $orgId)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    $message = ("{0}: Attempting to get the Meraki network list for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrgName)
    Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

    Try {
        $nwIds = (Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v0/organizations/$orgId/networks" -Headers $headers -ErrorAction Stop).id
    }
    Catch {
        $message = ("{0}: Unexpected error getting network list. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

        Exit
    }

    If ($nwIds) {
        $message = ("{0}: Found {1} networks." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $nwIds.Count)
        Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

        $deviceList = $nwIds | ForEach-Object {
            $message = ("{0}: Attempting to get the Meraki devices on network: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_)
            Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

            Try {
                $temp = Invoke-RestMethod -Method "GET" -Uri "https://dashboard.meraki.com/api/v0/networks/$_/devices" -Headers $headers -ErrorAction Stop
            }
            Catch {
                $message = ("{0}: Unexpected error getting devices. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                Write-Verbose $message; $message | Out-File -FilePath $logFile -Append

                Write-Host ("auto.serialnumber=Retrieve Error. See log: $logFile")

                Exit
            }

            $temp | select name,serial
        }

        Write-Host ("auto.serialnumber={0}" -f ($deviceList | Where-Object {$_.name -eq $hostname}).serial)

        Exit
    }
}