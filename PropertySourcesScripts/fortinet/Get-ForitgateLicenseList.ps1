<#
    .DESCRIPTION
        Query Fortigate devices for installed licenses and return a list of names with their expiration dates.
    .NOTES
        Author: Mike Hashemi
        V2022.2.7.0
        V2022.2.21.0
        V2022.02.22.0
        V2023.01.09.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourceScripts/fortigate
#>
[CmdletBinding()]
param()

#region Setup
Function Get-FortigateLicenseExpiration {
    [CmdletBinding(DefaultParameterSetName = 'Community')]
    param(
        [Parameter(Mandatory)]
        $ComputerName,

        [Parameter(Mandatory)]
        [ValidateSet('1', '2c', '3')]
        $SnmpVersion,

        [Parameter(Mandatory, ParameterSetName = 'Community')]
        $Community,

        [Parameter(Mandatory, ParameterSetName = 'v3')]
        $SnmpSecurity,

        [Parameter(Mandatory, ParameterSetName = 'v3')]
        $SnmpAuth,

        [Parameter(Mandatory, ParameterSetName = 'v3')]
        $SnmpAuthToken,

        [Parameter(Mandatory, ParameterSetName = 'v3')]
        $SnmpPriv,

        [Parameter(Mandatory, ParameterSetName = 'v3')]
        $SnmpPrivToken,

        $LogFile
    )

    $startOid = '.1.3.6.1.4.1.12356.101.4.6.3.1.2.1.1'
    $endOid = '.1.3.6.1.4.1.12356.101.4.6.3.1.2.1.3'
    $regex = 'OID\=.*Type\=OctetString\,\sValue\='

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    $message | Out-File -Append -FilePath $logFile

    $message = ("{0}: Operating in the {1} parameter set." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    $message | Out-File -Append -FilePath $logFile

    $message = ("{0}: Attempting SNMP walk." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    $message | Out-File -Append -FilePath $logFile

    # Walk the OID to find out get the instances.
    Try {
        Switch ($PsCmdlet.ParameterSetName) {
            "Community" {
                $snmpwalkResult = snmpwalk.exe -r:$computerName -p:161 -v:$snmpVersion -c:$community -os:$startOid -op:$endOid
            }
            "v3" {
                $snmpwalkResult = snmpwalk.exe -r:$computerName -p:161 -v:$snmpVersion -sn:$snmpSecurity -ap:$snmpAuth -aw:$snmpAuthToken -pp:$snmpPriv -pw:$snmpPrivToken -os:$startOid -op:$endOid
            }
        }
    }
    Catch {
        $message = ("{0}: Unexpected error running snmpwalk. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        $message | Out-File -Append -FilePath $logFile

        Return 1
    }

    If (($snmpwalkResult -match 'type=octetstring') -and ($snmpwalkResult -match '(?:mon|tue|wed|thu|fri|sat|sun)')) {
        $message = ("{0}: Retreived license information, attempting to parse." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -Append -FilePath $logFile

        $rawLicenses = ($snmpwalkResult -match $regex) -replace $regex

        $parsedLicenses = For ($i = 0; $i -lt ($rawLicenses.Count / 2); $i++) {
            If ($rawLicenses.Count -eq 2) {
                [PSCustomObject]@{
                    Name       = "`"$($rawLicenses[0])`""
                    Expiration = "`"(($($rawLicenses[1]) -replace '([01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]') -replace '  ', ' ')`""
                }
            } Else {
                [PSCustomObject]@{
                    Name = "`"$($rawLicenses[$i])`""
                    Expiration = "`"$($rawLicenses[($i + ($rawLicenses.Count / 2))] -replace '([01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]' -replace '  ', ' ')`""
                }
            }
        }

        $message = ("{0}: Parsed SNMP response into {1} licenses." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $parsedLicenses.Name.Count)
        $message | Out-File -Append -FilePath $logFile
    }
    Else {
        $message = ("{0}: Zero licenses were retreived." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
        $message | Out-File -Append -FilePath $logFile

        Return 0
    }

    Return $parsedLicenses
}

#region Initialize variables
$computerName = '##system.hostname##'
$community = '##snmp.community##'
$snmpAuth = '##snmp.auth##'
$snmpAuthToken = '##snmp.authToken##'
$snmpPriv = '##snmp.priv##'
$snmpPrivToken = '##snmp.privToken##'
$snmpVersion = '##snmp.version##'
$snmpSecurity = '##snmp.security##'
$firmwareVersionProp = '##auto.fortinet.fortigate.firmware.version##'

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\propertysource_Fortigate_License_List-$computerName.log"

Switch ($snmpversion) {
    'v1' { $snmpVersion = 1 }
    'v2c' { $snmpVersion = '2c' }
    'v3' { $snmpVersion = 3 }
}
#endregion Initialize variables

If ($snmpPriv -eq 'AES') { $snmpPriv = 'AES128' }

Switch ($snmpAuthToken) {
    { ($snmpAuthToken.Length -gt 0) } {
        $commandParams = @{
            ComputerName  = $computerName
            SnmpVersion   = $snmpVersion
            SnmpSecurity  = $snmpSecurity
            SnmpAuth      = $snmpAuth
            SnmpAuthToken = $snmpAuthToken
            SnmpPriv      = $snmpPriv
            SnmpPrivToken = $snmpPrivToken
            LogFile       = $logFile
        }

        Continue
    }
    default {
        $commandParams = @{
            ComputerName = $computerName
            SnmpVersion  = $snmpVersion
            Community    = $community
            LogFile      = $logFile
        }
    }
}
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Main
If ($firmwareVersionProp -match '\d.\d.\d') {
    $message = ("{0}: Parsing firmware version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $firmwareVersion = $matches[0]

    If ($firmwareVersion -lt '6.4.2') {
        $message = ("{0}: The device does not support license retrieval via SNMP. The minimum firmware version is 6.4.2 ({1} has version {2})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $computerName, $firmwareVersion)
        $message | Out-File -FilePath $logFile -Append

        Exit 0
    } Else {
        $message = ("{0}: The device has the required minimum firmware version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        $message | Out-File -FilePath $logFile -Append
    }
}

$discoveredLicenses = Get-FortigateLicenseExpiration @commandParams

If ($discoveredLicenses -eq 1) {
    $message = ("{0}: Error detected while identifying licenses." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
} ElseIf ($discoveredLicenses -eq 0) {
    $message = ("{0}: No licenses retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 0
} ElseIf ($discoveredLicenses.Name) {
    $string = [String]::Join(',', $discoveredLicenses)
    $message = ("{0}: Returning list of installed licenses:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $string)
    $message | Out-File -FilePath $logFile -Append

    Write-Host ("genericexpirationdata={0}" -f $string)

    Exit 0
} Else {
    $message = ("{0}: Exiting in an unexpected state." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Main