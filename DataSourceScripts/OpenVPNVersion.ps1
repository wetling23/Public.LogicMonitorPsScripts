$minimumVersionRequired = "2.4.6"
$app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -match "OpenVPN"}

If ($app.DisplayVersion -match $minimumVersionRequired) {
    Write-Host ("minVersionReached=1")

    Write-Host ("version={0}" -f $app.DisplayVersion)

    Exit 0
}
Else {
    Write-Host ("minVersionReached=0")

    Write-Host ("version={0}" -f $app.DisplayVersion)

    Exit 0
}

Exit 1