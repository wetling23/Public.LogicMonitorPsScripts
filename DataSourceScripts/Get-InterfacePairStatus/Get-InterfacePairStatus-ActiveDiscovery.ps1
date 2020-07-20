<#
    .DESCRIPTION
        Convert the quasi hash table in a device's "custom.portPairs" property, into an instance passed to the collection script.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 10 July 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Get-InterfacePairStatus
    .PARAMETER LogPath
        Path to which the script's output will be logged.
#>
[CmdletBinding()]
param(
    [string]$LogFile
)

# Initialize variables.
# Need the device ID for the log file name, so this has to be above the rest of the initialization and does not log.
$computer = '##system.hostname##'

# Gotta define the log file after populating $computer, because we use that variable's value in the file name.
If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-GetInterfacePairStatus-ad-$computer.log"

$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

# More variable intialization.
$tempString = "##custom.portPairs##"
$pattern = '\[(?<Key>[^,\]]+),(?<Value>[^\]]+)\]'

$tempString.Split(":") | ForEach-Object {
    $hashTable = @{}
    Foreach ($match in [regex]::Matches($_, $pattern)) {
        $hashTable[$match.Groups['Key'].Value] = $match.Groups['Value'].Value
    }

    $message = ("{0}: Returning {1} and {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $hashTable.PairName, $hashTable.Ports)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Write-Host "$($hashTable.Ports)##$($hashTable.PairName)"
}

Exit 0