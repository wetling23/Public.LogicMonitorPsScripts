<#
    .DESCRIPTION
        PowerShell script which uses the Dell Storage PowerShell SDK PowerShell module to retrieve disk properties from Storage Manager, for a user-specified array.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 10 September 2019
            - Initial release
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/CompellentDiskHealth
    .PARAMETER SerialNumber
        Serial number of the desired Compllent array.
    .PARAMETER StorageManager
        Fully qualified domain name or IP address of the Storage Manager for the desired array.
    .PARAMETER UserName
        Username of user with API access to the desired Storage Manager.
    .PARAMETER Password
        Password of the user with API access to the desired Storage Manager (in securestring format).
    .PARAMETER ModulePath
        Path to the .psd1 file containing the Dell Storage PowerShell SDK PowerShell module.
    .PARAMETER LogPath
        Path to which the script's output will be logged.
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force)

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111.
        The script will attempt to import the Dell PowerShell module from C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DellStoragePowerShellSDK_v3_5_1_9.
        If the script is run from a LogicMonitor collector, the logged output is stored in C:\Program Files (x86)\LogicMonitor\Agent\Logs\datasource-Compellent_Disk_Health-collection-array1.log.
        If the script is not run from a LogicMonitor collector, the logged output is stored in C:\Windows\System32\datasource-Compellent_Disk_Health-collection-array1.log.
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force) -LogPath C:\temp\log.log

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111. The logged output is stored in C:\temp\log.log
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force) -ModulePath C:\temp\modules -LogPath C:\temp\log.log

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111. The script will attempt to import the Dell PowerShell module from C:\temp\modules. The logged output is stored in C:\temp\log.log
#>
[CmdletBinding()]
param(
    [string[]]$SerialNumber,

    [string]$StorageManager,

    [string]$UserName,

    [securestring]$Password,

    [ValidateScript( {
            If (-Not ($_ | Test-Path) ) {
                Throw "File or folder does not exist"
            }
            If (-Not ($_ | Test-Path -PathType Leaf) ) {
                Throw "The Path argument must be a file. Directory paths are not allowed."
            }
            Return $true
        })]
    [System.IO.FileInfo]$ModulePath = 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DellStoragePowerShellSDK_v3_5_1_9\DellStorage.ApiCommandSet.psd1',

    [string]$LogFile
)

Try {
    #region Initialize variables
        If (-NOT($SerialNumber)) {
        $SerialNumber = '##custom.compellentSsn##'
    }
    If (-NOT($StorageManager)) {
        $StorageManager = '##system.hostname##'
    }
    If (-NOT($Username)) {
        $Username = '##compellent.user##'
    }
    If (-NOT($Password)) {
        $Password = ('##compellent.pass##' | ConvertTo-SecureString -AsPlainText -Force)
    }

    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    }
    Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-Compellent_Disk_Health-ad-$StorageManager.log"

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    $progressCounter = 0

    If ($SerialNumber -match ',') {
        $SerialNumber = $SerialNumber -split ','
    }

    $message = ("{0}: Attempting to import the PowerShell module from {1}." -f [datetime]::Now, $ModulePath)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    Try {
        Import-Module -Name "$($ModulePath.FullName)" -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unable to import the Dell Storage PowerShell SDK module. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
    }

    $message = ("{0}: Working with:`r`nSerial number: {1}`r`nStorage manager: {2}`r`nUser: {3}" -f [datetime]::Now, ($SerialNumber -join ', '), $StorageManager, $UserName)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }
    #endregion initialize variables

    Try {
        $message = ("{0}: Attempting to connect to {1}." -f [datetime]::Now, $StorageManager)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        $conn = Connect-DellApiConnection -HostName $StorageManager -User $UserName -Password $Password -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Error connecting to the storage manager. The error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }

    Foreach ($sn in $SerialNumber) {
        $message = ("{0}: Connection successful, attempting to retrieve data from the array with serial number {1}." -f [datetime]::Now, $sn)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        $disks = Get-DellScDisk -ScSerialNumber $sn -Connection $conn

        If ($disks.Count -gt 0) {
            $message = ("{0}: Retrieved disk properties." -f [datetime]::Now, $StorageManager)
            If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

            Foreach ($disk in $disks) {
                $message = ("{0}: Returning {1} and {2}." -f [datetime]::Now, $disk.ScName, $disk.instanceId)
                If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

                Write-Host "$($disk.instanceId)##$($disk.UniqueName)/$($disk.ScName)##$sn####auto.compellentssn=$sn"
            }
        }
    }

    Exit 0
}
Catch {
    $message = ("{0}: Unexepected error in {1}. The command was `"{2}`" and the specific error was: {3}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}