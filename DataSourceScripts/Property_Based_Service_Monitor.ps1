
# Begin ActiveDiscovery
[string]$definedServices = "##custom.MonitoredServices##"
[System.Collections.ArrayList]$services = $definedServices.Split(',')

If ($services -contains 'Windows_Basic_Services') {
    $services.Remove('Windows_Basic_Services')
    $services += "Eventlog","lanmanserver","lanmanworkstation","LmHosts","PlugPlay","RpcSs","SamSs","SENS","winmgmt"
}

# Find services
ForEach ($service in $services) {
    $installedService = Get-Service -Name $service -ErrorAction SilentlyContinue

    If ($installedService) {
        Write-Host "$($installedService.Name)##$($installedService.Name)"
    }
    
    $installedService = $null
}
# End ActiveDiscovery


# Begin main script
$serviceName = "##WILDVALUE##"
$status = $null

$status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

If ($status.Status -eq 'Running') {
    Write-Host 1
}
Else {
    Write-Host 0
}
# End main script