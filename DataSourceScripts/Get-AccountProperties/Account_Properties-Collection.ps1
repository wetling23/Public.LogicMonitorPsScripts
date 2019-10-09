$userName = "##wildvalue##"

If ((Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain) {
    If (-NOT (Get-Module -Name ActiveDirectory -ListAvailable)) {
        ##logging
        Exit 1
    }

    $domainControllers = [System.Collections.Generic.List[PSObject]]@(Get-ADDomainController -Filter * | Where-Object { (Test-Connection -ComputerName $_.IPv4Address -Count 1 -ErrorAction SilentlyContinue) })

    $results = Foreach ($dc in $domainControllers) {
        Try {
            Get-ADUser -Identity $userName -Properties DisplayName, PwdLastSet, PasswordLastSet -Server $dc.IPv4Address -ErrorAction Stop | Select-Object DisplayName, DistinguishedName, PasswordLastSet, @{Name = "PwdLastSet"; Expression = { [datetime]::FromFileTime($_.PwdLastSet) } }, @{Name = "PwdAge"; Expression = { if ($_.PwdLastSet -ne 0) { (new-TimeSpan([datetime]::FromFileTimeUTC($_.PwdLastSet)) $(Get-Date)).days }else { 0 } } } | Where-Object { $_.PasswordLastSet }
        }
        Catch {
            #logging here
        }
    }

    If ($results -as [system.array]) {
        $results = $results | Sort-Object -Descending -Property PwdAge | Select-Object -First 1
    }
}
Else {
    $localAccount = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" -Filter "LocalAccount='$True'" -ErrorAction Stop | Where-Object { $_.name -eq $userName }
    $user = ([adsi]"WinNT://$($env:COMPUTERNAME)/$($localAccount.Name),user")
    $results = [PSCustomObject]@{
        DisplayName       = $($user.FullName)
        DistinguishedName = $($user.Name)
        PwdAge            = [math]::Round($user.PasswordAge.Value / 86400)
        PasswordLastSet   = $(Get-Date).AddSeconds(-$($user.PasswordAge.Value))
    }
}

#$results
Write-Host ("PasswordAge={0}" -f $results.PwdAge)