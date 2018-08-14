[array]$urls = @('https://zinfandel.centrastage.net')
$connectionFailureCount = 0

Foreach ($url in $urls) {
    Write-Host "Testing connection to $url"
    Try {
        $status = Invoke-WebRequest -UseBasicParsing -Uri $url -ErrorAction Stop
    }
    Catch {
        Write-Host ("PowerShell failed to test the URL. The specific error is: {0}" -f $_.Exception.Message)
        $connectionFailureCount++
    }

    If ($status -and $status.StatusCode -ne 200) {
        Write-Host $status.StatusDescription
        $connectionFailureCount++
    }
    Else {
        Write-Host "Connection successful."
    }
}

If ($connectionFailureCount -gt 0) {
    Exit 2
}
Else {
    Exit 0
}