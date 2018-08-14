If (Test-Path -Path C:\it\IPMICFG\Windows\64bit\IPMICFG-Win.exe -ErrorAction SilentlyContinue) {
    $config = . 'C:\it\IPMICFG\Windows\64bit\IPMICFG-Win.exe' -m
}
ElseIf (Test-Path -Path C:\it\firstLogon\IPMICFG\Windows\64bit\IPMICFG-Win.exe -ErrorAction SilentlyContinue) {
    $config = . 'C:\it\firstLogon\IPMICFG\Windows\64bit\IPMICFG-Win.exe' -m
}
Else {
    Write-Host ("IPMIAddress=None")
}

$ip = $config[0].TrimStart("IP=")

Write-Host ("IPMIAddress={0}" -f $ip)