<#
    .DESCRIPTION
        Retrieve a list of files from a user-specified path.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 17 October 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Files/Get-FileSize
    .PARAMETER Path
        Path on the target computer, to query for files.
    .PARAMETER TargetComputer
        IP address of the target computer.
    .PARAMETER Credential
        Credential with access to the path on the target computer.
    .PARAMETER Recurse
        Boolean parameter that controls whether or not the script will attempt to query.
    .EXAMPLE
        PS C:> Get-FileSize_ActiveDiscovery.ps1 -Path C:\Temp,H:\ -Recurse False -TargetComputer 10.1.1.10 -Credential Get-Credential

        In this example, the script returns the contents of C:\Temp and H:\, without searching down the tree.
    .EXAMPLE
        PS C:> Get-FileSize_ActiveDiscovery.ps1 -Path H:\ -Recurse True -TargetComputer 10.1.1.10

        In this example, the script returns the contents of H:\, recursively.
#>
[CmdletBinding()]
param (
    [string[]]$Path,

    [string]$TargetComputer,

    [System.Management.Automation.PSCredential]$Credential,

    [boolean]$Recurse
)

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-Get_File_Size-ad.log"

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

# Initialize variables.
$files = [System.Collections.Generic.List[PSObject]]::new()
If (-NOT($Path)) {
    $message = ("{0}: No path provided, attempting to retrieve from LogicMonitor." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $Path = "##custom.fileSizePath##"
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
If (($Recurse -eq $true) -or ("##custom.FileSizeRecurse##" -eq "true")) {
    $commandParams = @{
        Recurse = $true
    }
}

If ($Path -match ',') {
    $Path = $Path.Split(',')
}

$Path | ForEach-Object {
    $message = ("{0}: Targeting {1} on {2}." -f [datetime]::Now, $_, $TargetComputer)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $result = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
        param(
            $path,
            $commandParams
        )

        Try {
            Get-ChildItem -Path $path @commandParams -ErrorAction Stop -File
        }
        Catch [System.Management.Automation.ParameterBindingException] {
            ("{0}: It appears that the path ({1}) is invalid because PowerShell is complaining about the -File parameter." -f [datetime]::Now, $path)
        }
        Catch {
            ("{0}: Error getting file information from {1}. The specific error is: {2}" -f [datetime]::Now, $path, $_.Exception.Message)
        }
    } -ArgumentList $_, $commandParams

    $result | ForEach-Object { $files.Add($_) }
}

If (-NOT ($files.Name)) {
    $message = ("{0}: No file data returned from {1}. The device returned: {2}" -f [datetime]::Now, $TargetComputer, $files)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    Exit 1
}
Else {
    $message = ("{0}: Found {1} files in {2}." -f [datetime]::Now, $files.Count, $path)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $files | ForEach-Object {
        $message = ("{0}: Returning {1}." -f [datetime]::Now, $_.Name)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Write-Host "$($_.FullName)##$($_.Name)"
    }

    Exit 0
}