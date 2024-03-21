<#
    .DESCRIPTION
        Test connection to a UNC path and return the path if the connection is successful.
    .NOTES
        V2024.03.08.0
    .LINK
        
#>
[CmdletBinding()]
param ()

Try {
    #region Setup
    $computer = '##system.hostname##'
    $uncPaths = "##unc.paths##"
    $debug = $false

    If ($uncPaths -match ',') {
        $uncList = $uncPaths -split ','
    } Else {
        $uncList = @($uncPaths)
    }

    #region Logging
    If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-unc-ad-$computer.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile } Else { Out-File -InputObject $message -FilePath $logFile }
    #endregion Setup

    #region Main
    Foreach ($unc in $uncList) {
        $message = ("{0}: Testing connection to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $unc); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

        If (Test-NetConnection -ComputerName ($unc -split "\\")[2] -Port 445) {
            $message = ("{0}: Connection successful." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $unc); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

            Write-Host "$unc##$unc"
        } Else { $message = ("{0}: Connection failed." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $unc); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append } }
    }
    #endregion Main
} Catch {
    $message = ("{0}: Unexpected error in {1}. The command was `"{2}`" and the specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }
}