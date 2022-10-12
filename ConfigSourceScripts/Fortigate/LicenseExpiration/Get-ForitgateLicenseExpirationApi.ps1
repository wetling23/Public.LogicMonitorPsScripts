<#
not production
    .DESCRIPTION
        Query Fortigate devices for License expiration and identify those expiring in 30-or-fewer/7-or-fewer days.
    .NOTES
        Author: Mike Hashemi
        V2022.2.7.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts/Fortigate/LicenseExpiration
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

    $licenses = [System.Collections.Generic.List[PSObject]]::New()
    $dateOid = '.1.3.6.1.4.1.12356.101.4.6.3.1.2.1.2'
    $startOid = '.1.3.6.1.4.1.12356.101.4.6.3.1.2.1.1'
    $endOid = '.1.3.6.1.4.1.12356.101.4.6.3.1.2.1.3'

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -Append -FilePath $logFile

    $message = ("{0}: Operating in the {1} parameter set." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    Write-Host $message; $message | Out-File -Append -FilePath $logFile

    # Walk the OID to find out get the instances.
    Switch ($PsCmdlet.ParameterSetName) {
        "Community" {
            $snmpwalkResult = snmpwalk.exe -r:$computerName -p:161 -v:$snmpVersion -c:$community -os:$startOid -op:$endOid
        }
        "v3" {
            $snmpwalkResult = snmpwalk.exe -r:$computerName -p:161 -v:$snmpVersion -sn:$snmpSecurity -ap:$snmpAuth -aw:$snmpAuthToken -pp:$snmpPriv -pw:$snmpPrivToken -os:$startOid -op:$endOid
        }
    }

    If ($snmpwalkResult -match 'type=octetstring') {
        $message = ("{0}: Retreived license information, attempting to parse." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -Append -FilePath $logFile

        $snmpwalkResult = $snmpwalkResult | Where-Object { $_ -match 'type=octetstring' }

        Foreach ($licenseLine in $snmpwalkResult[0..(($snmpwalkResult.Count / 2) - 1)]) {
            $i = 1

            $licenses.Add([PSCustomObject]@{
                    License    = $licenseLine.Split('=')[-1]
                    Expiration = ($snmpwalkResult | Where-Object { $_ -match "$dateOid.$i" }).Split('=')[-1]
                })
            $i++
        }
    }

    $message = ("{0}: Identified {1} licenses." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $licenses.Expiration.Count)
    Write-Host $message; $message | Out-File -Append -FilePath $logFile

    Return $licenses
}

# Initialize variables.
$computerName = '##system.hostname##'
$community = "##snmp.community##"
$snmpAuth = "##snmp.auth##"
$snmpAuthToken = "##snmp.authToken##"
$snmpPriv = "##snmp.priv##"
$snmpPrivToken = "##snmp.privToken##"
$snmpVersion = "##snmp.version##"
$snmpSecurity = "##snmp.security##"

$username = "##ssh.user##"
$password = "##ssh.pass##"
$computerName = '172.24.21.1'

Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
$AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
$header = @{
    'Content-Type' = 'application-json'
}

$session = Invoke-WebRequest -Method POST -UseBasicParsing -Uri "https://$computerName`:8443/logincheck?username=$username&secretkey=$password" -Headers $header -skipheadervalidation

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\configsource_Fortigate_License_Expiration-$computerName.log"








Switch ($snmpversion) {
    'v1' { $snmpVersion = 1 }
    'v2c' { $snmpVersion = '2c' }
    'v3' { $snmpVersion = 3 }
}

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

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$discoveredLicenses = Get-FortigateLicenseExpiration @commandParams

If ($discoveredLicenses) {
    $regex = '(\d{2}):(\d{2}):(\d{2})\s'
    $today = Get-Date
    $i = 0

    $message = ("{0}: Calculating days until expiration." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Foreach ($license in $discoveredLicenses) {
        $i++

        $message = ("{0}: Parsing `"{1}`". This is license {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $license.License, $i, $discoveredLicenses.License.Count)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $license | Add-Member -MemberType NoteProperty -Name DaysUntilExpiration -Value (New-TimeSpan -Start $today -End ($license.Expiration -replace $regex, '')).Days -Force

        If ($license.DaysUntilExpiration -le 30) {
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value True -Force
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value False -Force
        } ElseIf ($license.DaysUntilExpiration -le 7) {
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value True -Force
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value False -Force
        } Else {
            $license | Add-Member -MemberType NoteProperty -Name 30DayAlert -Value False -Force
            $license | Add-Member -MemberType NoteProperty -Name 7DayAlert -Value False -Force
        }
    }

    ($discoveredLicenses | Out-String)

    Exit 0
} Else {
    $message = ("{0}: No licenses retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}