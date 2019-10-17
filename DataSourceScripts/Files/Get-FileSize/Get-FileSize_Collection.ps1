<#
    .DESCRIPTION
        
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 18 October 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Files/Get-FileSize
    .PARAMETER FilePath
        Path to a file, on the target computer, to query.
    .PARAMETER TargetComputer
        IP address of the target computer.
    .PARAMETER Credential
        Credential with access to the path on the target computer.
    .EXAMPLE
        PS C:> Get-FileSize_Collection.ps1 -FilePath C:\Temp\test.txt -TargetComputer 10.1.1.10 -Credential Get-Credential

        In this example, the script returns the size of C:\Temp\test.txt.
#>
[CmdletBinding()]
param (
    [string]$FilePath,

    [string]$TargetComputer,

    [System.Management.Automation.PSCredential]$Credential
)

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get_File_Size-collection.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

# Initialize variables.
If (-NOT($FilePath)) {
    $message = ("{0}: No file path provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $FilePath = "##wildvalue##"
}
If (-NOT($TargetComputer)) {
    $message = ("{0}: No target computer provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $TargetComputer = '##system.hostname##'
}
If (-NOT($Credential)) {
    $message = ("{0}: No credential provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $Credential = New-Object System.Management.Automation.PSCredential ('##wmi.user##', (ConvertTo-SecureString -String '##wmi.pass##' -AsPlainText -Force))
}

$message = ("{0}: Targeting {1} on {2}." -f [datetime]::Now, $FilePath, $TargetComputer)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

$fileInfo = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
    param(
        $path
    )

    Try {
        Get-ChildItem -Path $path -ErrorAction Stop -File
    }
    Catch {
        ("{0}: Error getting file information from {1}. The specific error is: {2}" -f [datetime]::Now, $path, $_.Exception.Message)
    }

} -ArgumentList $FilePath

If ($fileInfo.Length -lt 1) {
    $message = ("{0}: No file data returned from {1}. The device returned: {2}" -f [datetime]::Now, $TargetComputer, $fileInfo)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}
Else {
    Write-Host ("FileSize(GB)={0}" -f ($fileInfo.Length / 1GB))
    Write-Host ("FileSize(MB)={0}" -f ($fileInfo.Length / 1MB))
    Write-Host ("FileSize(KB)={0}" -f ($fileInfo.Length / 1KB))

    Exit 0
}