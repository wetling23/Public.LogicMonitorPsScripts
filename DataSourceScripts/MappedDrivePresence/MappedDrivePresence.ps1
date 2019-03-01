#region active discovery script
<#
    .DESCRIPTION
        Returns list of used drive letters on the target device.
#>

$computer = "##SYSTEM.HOSTNAME##"
$credential = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))

Try {
    $drives = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer -Credential $credential | Select-Object -ExpandProperty DeviceID
}
Catch {
    Write-Host ("Unexpected error getting drive list. Error is: {0}" -f $_.Exception.Message)

    Exit 1
}

Foreach ($drive in $drives) {
    Write-Host "$drive##$drive"
}

Exit 0
#endregion active discovery script

#region datasource script
<#
    .DESCRIPTION
        Accepts a driver letter and returns a status based on whether or not the letter is present on the target device.
#>

$desiredDrive = "##WILDVALUE##"
$computer = "##SYSTEM.HOSTNAME##"
$credential = New-Object System.Management.Automation.PSCredential ("##WMI.USER##", ('##WMI.PASS##' | ConvertTo-SecureString -AsPlainText -Force))

Try {
    $drives = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer -Credential $credential | Select-Object -ExpandProperty DeviceID
}
Catch {
    Write-Host ("Unexpected error getting drive list. Error is: {0}" -f $_.Exception.Message)

    Exit 1
}

Foreach ($drive in $drives) {
    If ($drive -match $desiredDrive) {
        Write-Host 'DrivePresent=1'

        Exit 0
    }
    Else {
        Write-Host 'DrivePresent=0'
    }
}

Exit 0
#endregion datasource script