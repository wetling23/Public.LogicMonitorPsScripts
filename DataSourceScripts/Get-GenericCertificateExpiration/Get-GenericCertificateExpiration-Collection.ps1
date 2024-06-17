<#
    .DESCRIPTION
        Use LogicMonitor manual "genericcertexpirationdata" LM properties and return days until expiration.
    .NOTES
        Author: Mike Hashemi
        V2024.06.17.0
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-GenericCertificateExpiration
#>
#Requires -Module Posh-SSH
[CmdletBinding()]
param()

Try {
    #region Setup
    #region Initialize variables
    #region Creds
    $computerName = "##HOSTNAME##" # Target host for the script to query.
    If ('##ssh.user##' -and '##ssh.pass##') {
        $user = '##ssh.user##'
        $pw = @'
##ssh.pass##
'@
    } ElseIf ('##config.user##' -and '##config.pass##') {
        $user = '##config.user##'
        $pw = @'
##config.pass##
'@
    }

    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ($user, ($pw | ConvertTo-SecureString -AsPlainText -Force))
    Remove-Variable -Name pw -Force -ErrorAction SilentlyContinue
    #endregion Creds

    $computerName = '##hostname##'
    $exitCode = 0
    $port = "##ssh.port##"
    If ($port -as [int]) {
        # No change, use the value from LM.
    } Else {
        $port = 22
    }

    $deviceType = "##custom.genericcertexpirationdata.deviceType##"
    If (-NOT ($adCommand.Length -gt 1)) {
        $deviceType = 'fortigate'
    }

    Switch ($deviceType) {
        "fortigate" {
            $discoCommand = ''
        }
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
    $logFile = "$logDirPath\datasource-Get_Generic_Certificate_Expiration_collection-$computerName.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); $message | Out-File -FilePath $logFile
    #endregion Setup
} Catch {

}

#region Setup
#region Initialize variables
$autoExpirationList = '##auto.genericexpirationdata##'
$manualExpirationList = '##manual.genericexpirationdata##'
$computerName = '##hostname##'
$today = Get-Date
$i = 0

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource_Get_Generic_Item_Expiration_Date_Collection-$computerName.log"
#endregion Initialize variables
#endregion Setup

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
$message | Out-File -FilePath $logFile

#region Parse LM property strings
#region Generate array
If (($autoExpirationList -match 'Expiration\=') -and -NOT($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.genericexpirationdata populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $autoExpirationList -split ','
} ElseIf (-NOT($autoExpirationList -match 'Expiration\=') -and ($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found auto.genericexpirationdata populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $manualExpirationList -split ','
} ElseIf (-NOT($autoExpirationList -match 'Expiration\=') -and -NOT($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: No properly-formatted licenses detected. Verify that the property is formatted correctly (e.g. @{Name=Hardware; Expiration=Sun Dec 17 2023},@{Name=AV Engine; Expiration=Sun Dec 17 2023})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
} ElseIf (($autoExpirationList -match 'Expiration\=') -and ($manualExpirationList -match 'Expiration\=')) {
    $message = ("{0}: Found both auto and manual.genericexpirationdata populated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $discoveredExpirations = $autoExpirationList -split ','
    $discoveredExpirations += $manualExpirationList -split ','
}
#endregion Generate array
#region Parse LM property strings

#region Parse array
If ($discoveredExpirations) {
    $message = ("{0}: Converting string data to an array of objects." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    $expirationObjects = Foreach ($item in $discoveredExpirations) {
        [pscustomObject][Management.Automation.Language.Parser]::ParseInput(
            $item,
            [ref] $null,
            [ref] $null).
        EndBlock.Statements[0].PipelineElements[0].Expression.SafeGetValue()
    }
}
#endregion Parse array

#region Calculate days remaining
If ($expirationObjects) {
    $message = ("{0}: Calculating days until expiration." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Foreach ($item in $expirationObjects) {
        $daysUntilExpiration = $null
        $i++

        $message = ("{0}: Parsing `"{1}`". This is license {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($item.Name -replace '\s+'), $i, $expirationObjects.Name.Count)
        $message | Out-File -FilePath $logFile -Append

        $daysUntilExpiration = (New-TimeSpan -Start $today -End $item.Expiration).Days

        $message = ("{0}: {1} expires in {2} days." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($item.Name -replace '\s+'), $daysUntilExpiration)
        $message | Out-File -FilePath $logFile -Append

        Write-Host ("{0}.DaysUntilExpiration={1}" -f ($item.Name -replace '\s+'), $daysUntilExpiration)
    }

    Exit 0
} Else {
    $message = ("{0}: No licenses retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    $message | Out-File -FilePath $logFile -Append

    Exit 1
}
#endregion Calculate days remaining