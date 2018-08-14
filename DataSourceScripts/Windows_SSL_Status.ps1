#Begin ActiveDiscovery
$hostname="##HOSTNAME##"

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$hostname\My","LocalMachine")
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly")

Foreach ($cert in $store.Certificates) {
    If ($cert.FriendlyName) {
        Write-Host "$($cert.Thumbprint)##$($cert.FriendlyName)"
    }
    Else {
        Write-Host "$($cert.Thumbprint)##$($cert.Thumbprint)"
    }
}
Exit 0
#End ActiveDiscovery


#Begin main script
$hostname="##HOSTNAME##"

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$hostname\My","LocalMachine")
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly")

Foreach ($cert in $store.Certificates) {
    Write-Host "$($cert.Thumbprint).$($cert.DaysUntilExpiration)=$(($cert.NotAfter).subtract([DateTime]::Now).days)"
}
Exit 0
#End main script