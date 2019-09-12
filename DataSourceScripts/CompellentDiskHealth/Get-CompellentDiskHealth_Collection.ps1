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
    .PARAMETER InstanceId
        Instance ID of the desired disk.
    .PARAMETER ModulePath
        Path to the .psd1 file containing the Dell Storage PowerShell SDK PowerShell module.
    .PARAMETER LogPath
        Path to which the script's output will be logged.
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force) -ArrayDisplayName array1

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111 and instance ID 111111.1
        The script will attempt to import the Dell PowerShell module from C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DellStoragePowerShellSDK_v3_5_1_9.
        If the script is run from a LogicMonitor collector, the logged output is stored in C:\Program Files (x86)\LogicMonitor\Agent\Logs\datasource-Compellent_Disk_Health-collection-array1.log.
        If the script is not run from a LogicMonitor collector, the logged output is stored in C:\Windows\System32\datasource-Compellent_Disk_Health-collection-array1.log.
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force) -ArrayDisplayName array1 -InstanceId 111111.1 -LogPath C:\temp\log.log

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111, for disk 111111.1. The logged output is stored in C:\temp\log.log
    .EXAMPLE
        PS C:\> Get-CompellentDiskHealth -SerialNumber 111111 -StorageManager strgServer.domain.tld -UserName 'admin' -Password ('password1' | ConvertTo-SecureString -AsPlainText -Force) -ArrayDisplayName array1 -InstanceId 111111.1 -ModulePath C:\temp\modules\mod.psd1 -LogPath C:\temp\log.log

        In this example, the command connects to strgServer.domain.tld using 'admin' and 'password1', then gets disk data for the array with serial number 111111, for disk 111111.1. The script will attempt to import the Dell PowerShell module from C:\temp\modules. The logged output is stored in C:\temp\log.log
#>
[CmdletBinding()]
param(
    [string]$SerialNumber,

    [string]$StorageManager,

    [string]$UserName,

    [securestring]$Password,

    [decimal]$InstanceId,

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
        $SerialNumber = '##auto.compellentssn##'
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
    If (-NOT($InstanceId)) {
        $InstanceId = "##WildValue##"
    }

    If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
        $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
    }
    Else {
        $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
    }
    $logFile = "$logDirPath\datasource-Compellent_Disk_Health-collection-$StorageManager.log"

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }

    $message = ("{0}: serial number: {1}." -f [datetime]::Now, $SerialNumber)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile } Else { $message | Out-File -FilePath $logFile }
    Try {
        Import-Module -Name "$($ModulePath.FullName)" -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unable to import the Dell Storage PowerShell SDK module. The specific error is: {1}." -f [datetime]::Now, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; $message | Out-File -FilePath $logFile -Append }
    }

    $message = ("{0}: Working with:`r`nSerial number: {1}`r`nStorage manager: {2}`r`nUser: {3}" -f [datetime]::Now, $SerialNumber, $StorageManager, $UserName)
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

    $message = ("{0}: Connection successful, attempting to retrieve data." -f [datetime]::Now)
    If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

    $disks = Get-DellScDisk -ScSerialNumber $SerialNumber -Connection $conn
    $diskStats = Get-DellScDiskStats -ScSerialNumber $SerialNumber -Connection $conn
    $diskConfig = Get-DellScDiskConfiguration -ScSerialNumber $SerialNumber -Connection $conn

    If ($disks.Count -gt 0) {
        $message = ("{0}: Retrieved disk properties." -f [datetime]::Now, $StorageManager)
        If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

        Foreach ($disk in $disks) {
            If ($disk.instanceId -eq $InstanceId) {
                $message = ("{0}: Reporting properties of disk {1}." -f [datetime]::Now, $InstanceId)
                If (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue') { Write-Verbose $message; $message | Out-File -FilePath $logFile -Append } Else { $message | Out-File -FilePath $logFile -Append }

                $properties = [PSCustomObject]@{
                    AllocatedSpace         = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).AllocatedSpace
                    AllocatedSpaceGB       = (($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).AllocatedSpace).ByteSize / 1GB
                    BadSpace               = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).BadSpace
                    BadSpaceGB             = (($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).BadSpace).ByteSize / 1GB
                    FreeSpace              = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).FreeSpace
                    FreeSpaceGB            = (($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).FreeSpace).ByteSize / 1GB
                    ManufacturerCapacity   = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ManufacturerCapacity
                    ManufacturerCapacityGB = (($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ManufacturerCapacity).ByteSize / 1GB
                    DiskEraseCapability    = ($disks | Where-Object { $_.InstanceId -eq $InstanceId }).DiskEraseCapability
                    PathAlertInformation   = ($diskConfig | Where-Object { $_.InstanceId -eq $InstanceId }).PathAlertInformation
                    Endurance              = ($disks | Where-Object { $_.InstanceId -eq $InstanceId }).Endurance
                    HealthDescription      = ($diskConfig | Where-Object { $_.InstanceId -eq $InstanceId }).HealthDescription
                    HealthDescriptionInt   = If (($diskConfig | Where-Object { $_.InstanceId -eq $InstanceId }).HealthDescription -eq 'Healthy') { 0 } Else { 1 }
                    PowerOnTimeHours       = ($disks | Where-Object { $_.InstanceId -eq $InstanceId }).PowerOnTimeHours
                    ReadBlockCount         = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ReadBlockCount
                    ReadErrorCount         = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ReadErrorCount
                    ReadRequestCount       = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ReadRequestCount
                    WriteBlockCount        = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).WriteBlockCount
                    WriteErrorCount        = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).WriteErrorCount
                    WriteRequestCount      = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).WriteRequestCount
                    ScName                 = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ScName
                    ScSerialNumber         = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ScSerialNumber
                    InstanceId             = $InstanceId
                    InstanceName           = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).InstanceName
                    ObjectType             = ($diskStats | Where-Object { $_.InstanceId -eq $InstanceId }).ObjectType
                }

                $properties
            }
        }

        Exit 0
    }
    Else {
        $message = ("{0}: No disk data retrieved." -f [datetime]::Now)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Exit 1
    }
}
Catch {
    $message = ("{0}: Unexepected error in {1}. The command was `"{2}`" and the specific error was: {3}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}