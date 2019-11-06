##update collector config
<#
    .DESCRIPTION
        
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 7 November 2019
            - Initial release.
    .LINK

    .PARAMETER ConfigFile
        Represents the path and file name of the config file to edit.
    .PARAMETER RegexToReplace
        Represents a regex expression for the text to replace.
    .PARAMETER NewString
        Represents the string that will replace the value of $RegexToReplace.
    .PARAMETER Encoding
        Represents the desired file encoding type. The default value is "ASCII".
    .PARAMETER LogFile
        Represents the desired path and file name of the desired log file. The default value is the directory, from which the script is run.
    .EXAMPLE
        PS C:> Update-LogicMonitorCollectorConf-Script.ps1 -ConfigFile "C:\Program Files (x86)\LogicMonitor\Agent\conf\sbproxy.conf" -RegexToReplace "pdh.collect.preferredMethod=csharp" -NewString "pdh.collect.preferredMethod=native"

        In this example, the script will replace "pdh.collect.preferredMethod=csharp" with "pdh.collect.preferredMethod=native", in the sbproxy.conf file and will save the file using ASCII encoding. Logging is written to the directory, from which the script was run.
    .EXAMPLE
        PS C:> Update-LogicMonitorCollectorConf-Script.ps1 -ConfigFile "C:\Program Files (x86)\LogicMonitor\Agent\conf\sbproxy.conf" -RegexToReplace "pdh.collect.preferredMethod=csharp" -NewString "pdh.collect.preferredMethod=native" -Encoding UTF8 -LogFile C:\temp\log.txt

        In this example, the script will replace "pdh.collect.preferredMethod=csharp" with "pdh.collect.preferredMethod=native", in the sbproxy.conf file and will save the file using UTF8 encoding. Logging is written to C:\temp\log.txt
#>
Param (
    [Parameter(Mandatory)]
    [ValidateScript( {
            If (-NOT ($_ | Test-Path) ) {
                Throw "File or folder does not exist."
            }
            If (-NOT ($_ | Test-Path -PathType Leaf) ) {
                Throw "The Path argument must be a file. Folder paths are not allowed."
            }
            Return $true
        })]
    [System.IO.FileInfo]$ConfigFile,

    [Parameter(Mandatory)]
    [string]$RegexToReplace,

    [Parameter(Mandatory)]
    [string]$NewString,

    [ValidateSet('ASCII', 'BigEndianUnicode', 'OEM', 'Unicode', 'UTF7', 'UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32')]
    [string]$Encoding = 'ASCII',

    [string]$LogFile
)

# Initialize variables
If (-NOT ($LogFile)) {
    $LogFile = "$PSScriptRoot\log.txt"
}

$message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile }

If ($PSScriptRoot -match 'C:\ProgramData\CentraStage\Packages') {
    If (-NOT ($env:ConfigFile -and $env:RegexToReplace -and $env:NewString)) {
        $message = ("{0}: Attempting to get the content of {1}." -f [datetime]::Now, $ConfigFile)
        Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }
    }
    Else {
        ##log Running Datto RMM component, assigning variable values from the component.
        $ConfigFile = $env:ConfigFile
        $RegexToReplace = $env:RegexToReplace
        $NewString = $env:NewString
    }
}

$message = ("{0}: Attempting to get the content of {1}." -f [datetime]::Now, $ConfigFile)
Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

Try {
    $fileContent = Get-Content -Path $ConfigFile -ErrorAction Stop
}
Catch {
    $message = ("{0}: Unexpected error getting the content of {1}. The specific error is: {2}" -f [datetime]::Now, $ConfigFile, $_.Exception.Message)
    Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

    Exit 1
}

If ($fileContent -match $RegexToReplace) {
    $message = ("{0}: Attempting to replace the content of {1}." -f [datetime]::Now, $ConfigFile)
    Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

    Try {
        $fileContent | Foreach-Object { $_ -replace $RegexToReplace, $NewString } | Out-File -FilePath $ConfigFile -Encoding $Encoding -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error replacing the content of {1}. The specific error is: {2}" -f [datetime]::Now, $ConfigFile, $_.Exception.Message)
        Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

        Exit 1
    }

    $message = ("{0}: Attempting to restart the LogicMonitor agent service." -f [datetime]::Now)
    Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

    Try {
        Restart-Service -Name logicmonitor-agent -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error restarting the LogicMonitor agent service. The specific error is: {1}" -f [datetime]::Now, $_.Exception.Message)
        Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }

        Exit 1
    }
}
Else {
    $message = ("{0}: Unable to find {1} in {2}. No further action to take." -f [datetime]::Now, $RegexToReplace, $ConfigFile)
    Write-Host $message; If ($LogFile) { $message | Out-File -FilePath $LogFile -Append }
}

Exit 0