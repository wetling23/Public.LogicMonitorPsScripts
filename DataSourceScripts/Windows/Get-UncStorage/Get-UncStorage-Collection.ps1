<#
    .DESCRIPTION
        Connect to a provided UNC path (with optional credential) and return space-utilization metrics.
    .NOTES
        V2024.03.08.0
    .LINK
        
#>
[CmdletBinding()]
param ()

Try {
    #region Setup
    #region In-line functions
    Function Get-NextAvailableDriveLetter {
        [CmdletBinding()]
        param ()
        $usedDriveLetters = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -match "^[A-Z]$" }).Name
        $nextAvailableDrive = 'C'
        While ($usedDriveLetters -contains $nextAvailableDrive) {
            $nextAvailableDrive = [char]([int][char]$nextAvailableDrive + 1)
        }

        Return $nextAvailableDrive
    }
    #endregion In-line functions

    $computer = '##system.hostname##'
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential ('##wmi.user##', ('##wmi.pass##' | ConvertTo-SecureString -AsPlainText -Force)) -ErrorAction SilentlyContinue
    $unc = "##wildvalue##"
    $debug = $false

    #region Logging
    If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    } Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-unc-collection-$computer.log"
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile } Else { Out-File -InputObject $message -FilePath $logFile }
    #endregion Setup

    #region Main
    $driveLetter = Get-NextAvailableDriveLetter

    $message = ("{0}: Attempting to map {1} to {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $unc, $driveLetter); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }
    Try {
        $result = New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $unc -ErrorAction Stop -Persist -Credential $credential
    } Catch {
        $message = ("{0}: Unexpected error connecting to {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $unc, $_.Exception.Message); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

        Exit 1
    }

    If ($result) {
        $null = Remove-PSDrive -Name $driveLetter -Force

        $dp = [PsCustomObject]@{
            UsedGB     = $result.used / 1GB
            UsedTB     = $result.used / 1TB
            FreeGB     = $result.free / 1GB
            FreeTB     = $result.free / 1TB
            CapacityGB = ($result.used + $result.free) / 1GB
            CapacityTB = ($result.used + $result.free) / 1TB
        }

        $message = ("{0}: Returning:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($dp | Out-String).Trim()); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

        Write-Host -Object $dp

        Exit 0
    } Else {
        ("{0}: Unable to map the drive." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

        Exit 1
    }
    #endregion Main
} Catch {
    $message = ("{0}: Unexpected error in {1}. The command was `"{2}`" and the specific error is: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message); If ($debug) { Write-Host -Object $message; Out-File -InputObject $message -FilePath $logFile -Append } Else { Out-File -InputObject $message -FilePath $logFile -Append }

    Exit 1
}