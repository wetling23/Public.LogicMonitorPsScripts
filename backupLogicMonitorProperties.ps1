<#
.SYNOPSIS
    Backup script for LogicMonitor object properties.
.DESCRIPTION
    Outputs the properties of LogicMonitor devices, collectors, services, and device groups to xml files.   
.NOTES
    Author: Mike Hashemi
    V1.0.0.0 date: 28 January 2017
        - Initial release
    V1.0.0.1 date: 1 February 2017
        - Updated logging.
.LINK
    
.PARAMETER WriteLog
    Switch parameter. When included (and a log path is defined), the script will send output to a log file and to the screen.
.PARAMETER LogPath
    Path where the function should store its log. When omitted, output will be sent to the shell.
#>
Param (
    [switch]$WriteLog,

    [string]$LogPath
)
#Requires -Modules LogicMonitor

Function Confirm-OutputPathAvailability {
<#
.DESCRIPTION
    Verifies that the log path is writeable by the script, and creates the directory if necessary. 
    The function will accept either a directory path ending in a directory or ending in a file name with extensions .txt or .log. 
    If a non-supported file extension is provided, the default file name (PowerShellModuleLog_<today's date>.txt) will be returned (in the desired directory path).
.NOTES 
    Author: Mike Hashemi
    V1.0.0.0 date: 31 January 2017
        - Initial release.
    V1.0.0.1 date: 31 January 2017
        - Added additional logging.
.LINK
    
.PARAMETER LogPath
    Default value is $env:USERPROFILE\PowerShellModuleLog_<today's date>.txt. 
.EXAMPLE
    PS C:\> Confirm-OutputPathAvailability

    In this example, the function will return a log file path of C:\Users\PowerShellModuleLog_<today's date>.txt.
.EXAMPLE
    PS C:\> Confirm-OutputPathAvailability -LogPath c:\it\log.txt

    In this example, the function will return a log file path of c:\it\log.txt. If the directory C:\it does not exist, the function will try to create it. If it fails to create the directory, the function will return "Error".
.EXAMPLE
    PS C:\> Confirm-OutputPathAvailability -LogPath c:\it\

    In this example, the function will return a log file path of c:\it\PowerShellModuleLog_<today's date>.txt. If the directory C:\it does not exist, the function will try to create it. If it fails to create the directory, the function will return "Error".
#>
[CmdletBinding()]
Param (
    [string]$LogPath = $env:USERPROFILE
)

    $message = Write-Output ("{0}: Beginning {1}" -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If ($WriteLog -and ($logPath -ne $null)) {Write-Host $message; $message | Out-File -FilePath $logPath -Append} Else {Write-Host $message}

    # Initialize variables.
    $regex =  "\.(txt|log)$"
    
    # Trim everything after the last backslash (\), isolating the path portion of the string.
    $TrimmedLogPath = $LogPath.Substring(0, $LogPath.lastIndexOf('\'))

    If (Test-Path $TrimmedLogPath -ErrorAction SilentlyContinue) {
        If ($LogPath -match $regex) {
            Return $LogPath
        }
        Else {
            $TrimmedLogPath += "\PowerShellModuleLog_$(Get-Date -Format yyyy-MM-dd).txt"

            Return $TrimmedLogPath
        }
    }
    Else {
        Try {
            New-Item -ItemType Directory -Path $TrimmedLogPath -ErrorAction Stop | Out-Null
        }
        Catch [System.UnauthorizedAccessException] {
            Write-Error ("The directory {0} doesn't exist and you don't have permission to create it. Please re-run the script with a different output path, or as a user with permission to create {0}." -f $TrimmedLogPath)
            
            Return "Error"
        }
        Catch {
            Write-Error ("An unexpected error occurred while trying to create {0}. The specific error message is: {1}" -f $TrimmedLogPath, $_.Exception.Message)
            
            Return "Error"
        }

        If ($LogPath -match $regex) {
            Return $LogPath
        }
        Else {
            $TrimmedLogPath += "\PowerShellModuleLog_$(Get-Date -Format yyyy-MM-dd).txt"

            Return $TrimmedLogPath
        }
    }
}

If ($LogPath) {
    $logPath = Confirm-OutputPathAvailability -LogPath $LogPath
        
    Write-Host ("Logging output to {0}" -f $LogPath)
}

$message = Write-Output ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
If ($WriteLog -and ($logPath -ne $null)) {Write-Host $message; $message | Out-File -FilePath $logPath -Append} Else {Write-Host $message}

# Initialize variables.
$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$currentScriptName = $MyInvocation.MyCommand.Name
$currentExecutingPath = $fullPathIncFileName.Replace($currentScriptName, "") 
$accountName = ##enter LM account name##

# Retrieve the user's API key, importing the saved credential from cred.xml.
$token = Get-LogicMonitorApiKey -DomainCredential (Import-Clixml -Path C:\it\LogicMonitorPropertyBackup\cred.xml)

# Get properties for all devices.
Get-LogicMonitorDevices -AccessId $token.AccessId -AccessKey $token.AccessKey -AccountName $accountName -WriteLog -LogPath $LogPath | Set-Content -Path C:\it\LogicMonitorPropertyBackup\deviceProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).json #| Export-Clixml -Path C:\it\LogicMonitorPropertyBackup\deviceProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).xml

# Get properties for all collectors.
Get-LogicMonitorCollectors -AccessId $token.AccessId -AccessKey $token.AccessKey -AccountName $accountName -WriteLog -LogPath $LogPath | Set-Content -Path C:\it\LogicMonitorPropertyBackup\collectorProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).json #| Export-Clixml -Path C:\it\LogicMonitorPropertyBackup\collectorProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).xml

# Get properties for all services.
Get-LogicMonitorServices -AccessId $token.AccessId -AccessKey $token.AccessKey -AccountName $accountName -WriteLog -LogPath $LogPath | Set-Content -Path C:\it\LogicMonitorPropertyBackup\serviceProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).json #| Export-Clixml -Path C:\it\LogicMonitorPropertyBackup\serviceProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).xml

# Get properties for all groups
Get-LogicMonitorDeviceGroups -AccessId $token.AccessId -AccessKey $token.AccessKey -AccountName $accountName -WriteLog -LogPath $LogPath | Set-Content -Path C:\it\LogicMonitorPropertyBackup\groupProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).json #| Export-Clixml -Path C:\it\LogicMonitorPropertyBackup\groupProperties_$(Get-Date -Format yyyy-MM-dd_HHmm).xml

$message = Write-Output ("{0}: Finished {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
If ($WriteLog -and ($logPath -ne $null)) {Write-Host $message; $message | Out-File -FilePath $logPath -Append} Else {Write-Host $message}

#########This syntax needs testing.
# Cleanup old log files.
#& C:\it\LogicMonitorPropertyBackup\deleteOldFilesAndFolders-Parameterized.ps1 -Path $currentExecutingPath -DaysToKeep 120 -IncludeFilter:$True -FileFilter '*Properties_*.xml'