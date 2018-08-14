$noSshExe = $false
$regex = "(?:OpenSSH_\D*(\d\.\d))"

# Get the current SSH installation directory.
If (Test-Path -Path "C:\Program Files\OpenSSH-Win64\ssh.exe" -ErrorAction SilentlyContinue) {
    $sshPath = "C:\Program Files\OpenSSH-Win64"
}
ElseIf (Test-Path -Path "C:\Program Files\OpenSSH\ssh.exe" -ErrorAction SilentlyContinue) {
    $sshPath = "C:\Program Files\OpenSSH"
}
Else {
    $message = ("{0}: Unable to locate ssh.exe." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    Write-Host $message; Out-File -FilePath .\log.txt -InputObject $message -Append

    $noSshExe = $True
}

If ($noSshExe -eq $True) {
    Write-Host "minimumVersionMet=0"
    Write-Host ("version=0")

    Exit 0
}
Else {
    $version = cmd /c "$sshPath\ssh.exe" -V 2`>`&1

    Switch ($version) {
        {($_ -match $regex) -and ($_ -match "7.7")} {
            Write-Host "minimumVersionMet=1"
            Write-Host ("version={0}" -f ($version -split $regex)[1])
        }
        default {
            Write-Host "minimumVersionMet=0"
            Write-Host ("version={0}" -f ($version -split $regex)[1])
        }
    }

    Exit 0
}

Exit 1