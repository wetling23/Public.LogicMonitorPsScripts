#ActiveDiscovery script
$firewallStatus = Get-NetFirewallProfile

Switch ($firewallStatus) {
    default {
        Write-Host "$($PSItem.Name)##$($PSItem.Name)"
    }
}



#DataSource script
$firewallStatus = Get-NetFirewallProfile

Switch ($firewallStatus) {
    {$_.Enabled -eq "True"} {
        Write-Host "$($PSItem.Name).=1"
        Write-Host ("Firewall for {0} is on" -f $PSItem.Name)
    }
    {$_.Enabled -eq "False"} {
        Try {
            Set-NetFirewallProfile -Name $PSItem.Name -Enabled True
        }
        Catch {
            Write-Host ("Unable to start the firewall for the {0} profile. The specific error is: {1}" -f $PSItem.Name, $_.Exception.Message)
        }

        $firewallStatus = Get-NetFirewallProfile

        Switch ($firewallStatus) {
            {$_.Enabled -eq $true} {
                Write-Host "$($PSItem.Name).=1"
                Write-Host ("Firewall for {0} is on" -f $PSItem.Name)
            }
            {$_.Enabled -eq $false} {
                Write-Host "$($PSItem.Name).=0"
                Write-Host ("Firewall for {0} is on" -f $PSItem.Name)
            }
        }
    }
}