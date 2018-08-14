# Get the service object.
$service = Get-Service -Name CagService -ErrorAction SilentlyContinue

If (($service) -and ($service.Status -ne 'Running')) {
    # If the service is present, but not runnnig...
    # Start the service.
    Try {
        Start-Service -Name CagService -ErrorAction Stop
    }
    Catch {
        # The service is not running.
        Write-Host "status=1"
        Write-Host ("Unexpected error starting the CAG service. The specific error is: {0}" -f $_.Exception.Message)

        Exit 0
    }

    # Get the service object again.
    $service = Get-Service -Name CagService -ErrorAction SilentlyContinue

    If ($service.Status -eq 'Running') {
        # The service is running.
        Write-Host "status=0"
        Write-Host ("Service running after restart.")

        Exit 0
    }
    Else {
        # The service is not running.
        Write-Host "status=1"
        Write-Host ("Service not running after restart.")

        Exit 0
    }
}
ElseIf (-NOT($service)) {
    # The service is not present.
    Write-Host "status=1"
    Write-Host ("Service not present.")

    Exit 0
}
ElseIf ($service.Status -eq 'Running') {
    # The service is running.
    Write-Host "status=0"
    Write-Host ("Service running.")

    Exit 0
}